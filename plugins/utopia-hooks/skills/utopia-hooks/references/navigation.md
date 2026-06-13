---
title: Navigation Conventions
impact: HIGH
tags: navigation, routes, typed-args, redirect, auth-guard, sheets, dialogs, navigator-key, events, deep-links
---

# Skill: Navigation Conventions

utopia_hooks itself is navigation-agnostic - nothing in the package pushes a route. These
are the conventions production apps use around it, shown with plain Flutter `Navigator`
APIs; they apply unchanged with go_router, auto_route, or any Navigator 2.0 setup.

**The core rule** (owned by [screen-state-view.md](./screen-state-view.md)): navigation
flows Screen -> State -> View as typed callbacks. The Screen closes over `BuildContext` in
`build()` and passes `void Function()` / `Future<T?> Function()` parameters into the state
hook; the hook stores them as State fields; the View calls them. State hooks never see
`BuildContext`, a router, or a `NavigatorKey`. Everything below builds on that rule - it
never relaxes it.

## Quick Pattern

**Incorrect (state hook navigates itself, route as a magic string):**
```dart
// state/item_details_screen_state.dart
ItemDetailsScreenState useItemDetailsScreenState({required ItemId itemId}) {
  final navigatorKey = useProvided<NavigatorKey>();   // NEVER in a screen state hook

  void onEditPressed() =>
      navigatorKey.currentState?.pushNamed('/edit-item', arguments: itemId); // string drift, untestable
  // ...
}
```

**Correct (Screen owns its route identity, hook receives callbacks):**
```dart
// item_details_screen.dart
class ItemDetailsScreen extends HookWidget {
  const ItemDetailsScreen._();

  static const route = 'item-details';

  static Route<void> buildRoute(RouteSettings settings) =>
      MaterialPageRoute(settings: settings, builder: (_) => const ItemDetailsScreen._());

  static Future<void> navigate(BuildContext context, {required ItemDetailsArgs args}) =>
      Navigator.of(context).pushNamed(route, arguments: args);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as ItemDetailsArgs;
    final state = useItemDetailsScreenState(
      itemId: args.itemId,
      navigateToEdit: () => EditItemScreen.navigate(context, args: EditItemArgs(itemId: args.itemId)),
    );
    return ItemDetailsScreenView(state: state);
  }
}

class ItemDetailsArgs {
  final ItemId itemId;
  const ItemDetailsArgs({required this.itemId});
}
```

## When to Use

- Declaring a new route and wiring it into the app's routing table
- Passing typed arguments to a screen, or returning a typed result from one
- Navigating in reaction to global state (post-login redirect, sign-out, forced update)
- Hosting a full Screen/State/View in a bottom sheet or dialog
- A sheet/dialog callback that needs the screen state itself (circular wiring)
- Deciding where `NavigatorKey` may legitimately be read

## Route declaration - the Screen owns its route

Each Screen declares its own route identity as statics - the Quick Pattern above shows all
four pieces. The non-obvious parts: `route` is the ONLY place the string exists (callers go
through `navigate`); `buildRoute` passes `settings` through so the route keeps its name and
arguments, and the private constructor guarantees the screen is only reachable via routing
(overlay-style routes use a non-opaque `PageRouteBuilder` in the same factory); the `Args`
cast at the top of `build()` throws on a mistyped payload - that fail-fast is intended.

A central routing table maps names to factories and feeds `onGenerateRoute`:

```dart
// app_routing.dart
abstract final class AppRouting {
  static final routes = <String, Route<Object?> Function(RouteSettings)>{
    SplashScreen.route: SplashScreen.buildRoute,
    LandingScreen.route: LandingScreen.buildRoute,
    MainScreen.route: MainScreen.buildRoute,
    ItemDetailsScreen.route: ItemDetailsScreen.buildRoute,
    EditItemScreen.route: EditItemScreen.buildRoute,
  };

  static Route<Object?>? onGenerateRoute(RouteSettings settings) =>
      routes[settings.name]?.call(settings);
}

// app.dart
MaterialApp(
  navigatorKey: _navigatorKey,
  initialRoute: SplashScreen.route,
  onGenerateRoute: AppRouting.onGenerateRoute,
)
```

Adding a screen is two edits: the statics on the Screen, one row in `AppRouting.routes`.

### Typed results from pushed routes

Type the route factory when a screen pops a result, so the route is a `Route<Color>`
instead of `Route<dynamic>` - a typed `pushNamed<T>` call casts the generated route
internally and fails on `dynamic`:

```dart
// statics as usual, but typed:
static Route<Color> buildRoute(RouteSettings settings) =>
    MaterialPageRoute<Color>(settings: settings, builder: (_) => const PickColorScreen._());

static Future<Color?> navigate(BuildContext context) async =>
    await Navigator.of(context).pushNamed(route) as Color?;
// inside: close: (color) => Navigator.of(context).pop(color)
```

### Other routers

go_router, auto_route, or any Navigator 2.0 setup plug into the same discipline: the
Screen still owns a typed `navigate`/route declaration, and state hooks still receive
navigation as callbacks - only the body of the callback changes
(`context.push(...)` instead of `pushNamed`). Router-backed shells (tabs living in the
route stack, so each tab is deep-linkable) are the router-flavored variant of the
multi-page shell - see [multi-page-shell.md](./multi-page-shell.md); the inner pages stay
full Screen/State/View triples either way.

## Reactive navigation effects

Classify every navigation by its trigger before wiring it:

- **Direct consequence of a user action only this screen performs** (save then pop):
  navigate in the action itself - `afterSubmit: (_) => navigateBack()` on a submit state.
- **Reaction to state that can change from elsewhere** (login status, registration
  completion, an entitlement flag): a `useEffect` in the state hook, keyed on the global
  flag, calling a Screen-built `navigateToX` callback.

```dart
LoginScreenState useLoginScreenState({
  required void Function() navigateToMain,
}) {
  final auth = useProvided<AuthState>();
  final service = useInjected<AuthService>();
  final submitState = useSubmitState();
  final emailState = useFieldState();
  final passwordState = useFieldState();

  // Navigate when the login lands in global state - regardless of which flow set it
  // (this form, a social-login callback, a deep-link token, session restore).
  useEffect(() {
    if (auth.isLoggedIn) navigateToMain();
    return null;
  }, [auth.isLoggedIn]);

  void onLoginPressed() => submitState.runSimple<void, Never>(
        submit: () async => service.login(emailState.value, passwordState.value),
        // No navigation here - the effect above owns it.
      );
  // ...
}
```

The fragile alternative - `await service.login(...); navigateToMain();` inside the submit
closure - fires only for that one code path; every other flow that flips the flag
silently fails to navigate.

## Status-driven redirect - the app-level auth guard

The splash decision tree in [app-bootstrap.md](./app-bootstrap.md) routes exactly once,
when boot completes. When the app can also regress mid-session (sign-out, token revoked,
forced update toggled remotely), generalize it into one reusable shell-level hook that
continuously maps global state to a target route and navigates whenever the target
changes:

```dart
void useStatusRedirectState({
  required void Function(String route) navigateAndReset,
}) {
  final initialization = useProvided<InitializationState>();
  final config = useProvided<RemoteConfigState>();
  final auth = useProvided<AuthState>();

  // null = still booting, no opinion yet
  final String? target = !initialization.isInitialized
      ? null
      : config.isUpdateRequired
          ? UpdateRequiredScreen.route
          : !auth.isLoggedIn
              ? LandingScreen.route
              : MainScreen.route;

  // Fire once per distinct target, not on every rebuild while the route
  // transition (which itself rebuilds) is in flight.
  useValueChanged<String?, void>(target, (_, __) {
    if (target != null) navigateAndReset(target);
  });
}
```

- `useValueChanged` is the load-bearing part: its callback runs only when `target` differs
  from the previous build, so each distinct target navigates exactly once. The null skip
  keeps the still-booting state from navigating. This generalizes the boot-only one-shot to
  mid-session redirects (boot lands on `main`, sign-out later flips the target to `landing`,
  and it fires again). Do not try to await the navigation future instead: `pushNamed`-style
  calls complete when the pushed route is *popped*, not when the transition ends.
- The reset-style push (`pushNamedAndRemoveUntil(route, (_) => false)`) clears the stack,
  so a signed-out user cannot back-navigate into authenticated screens.
- This hook **replaces** the splash decision tree - run one or the other, never both, or
  they double-navigate. With the redirect in place the splash screen keeps only the
  native-splash removal.

It is hosted at the app shell, the one place allowed to touch the provided `NavigatorKey`
(see below), because no screen's `BuildContext` outlives the resets it performs:

```dart
MaterialApp(
  navigatorKey: _navigatorKey,
  builder: (context, child) => HookBuilder(
    builder: (context) {
      final navigatorKey = useProvided<NavigatorKey>();
      useStatusRedirectState(
        navigateAndReset: (route) => navigatorKey.currentState?.pushNamedAndRemoveUntil(route, (_) => false),
      );
      return child!;
    },
  ),
  // ... routing table wiring as above
)
```

## One-shot event fields - breaking circular wiring

Normally the Screen builds UI primitives (`showXSheet`, `navigateToX`) and the hook
composes them, passing its own data as arguments when it invokes them. Occasionally that
wiring is circular: the sheet needs callbacks that close over the hook's internals, so the
Screen would have to reference `state` inside the parameters that create it -
`showManageMembersSheet: () => ManageMembersSheet.show(context, onRemoveMember: state.onRemoveMember)`
does not compile, `state` does not exist yet.

First try restructuring: make the primitive take parameters
(`showManageMembersSheet: (roomId, onRemoveMember) => ...`) and let the hook supply its own
data at call time. When several values and callbacks are involved, or the trigger comes
from inside the hook (an effect, a stream handler) rather than a View tap, that signature
degrades - the escape hatch is a **one-shot event field** on the State:

```dart
class ManageMembersEvent {
  final RoomId roomId;
  final Future<void> Function(MemberId) onRemoveMember; // closes over hook logic
  const ManageMembersEvent({required this.roomId, required this.onRemoveMember});
}

class RoomScreenState {
  final ManageMembersEvent? manageMembersEvent; // one-shot - Screen consumes and clears
  final void Function() clearManageMembersEvent;
  final void Function() onManageMembersTapped;  // View calls this
  // ...
}

RoomScreenState useRoomScreenState({required RoomId roomId}) {
  final eventState = useState<ManageMembersEvent?>(null);
  // ...
  return RoomScreenState(
    manageMembersEvent: eventState.value,
    clearManageMembersEvent: () => eventState.value = null,
    onManageMembersTapped: () =>
        eventState.value = ManageMembersEvent(roomId: roomId, onRemoveMember: removeMember),
  );
}
```

The Screen watches the field, **clears it immediately**, then performs the UI work. This
is the one sanctioned case where a Screen calls a second hook - a `useEffect` whose only
job is consuming one-shot events:

```dart
@override
Widget build(BuildContext context) {
  final state = useRoomScreenState(roomId: roomId);

  useEffect(() {
    final event = state.manageMembersEvent;
    if (event == null) return null;
    state.clearManageMembersEvent(); // clear FIRST so rebuilds cannot re-show the sheet
    ManageMembersSheet.show(context, roomId: event.roomId, onRemoveMember: event.onRemoveMember);
    return null;
  }, [state.manageMembersEvent]);

  return RoomScreenView(state: state);
}
```

Keep events rare and purpose-named (`manageMembersEvent`, not a generic `navigationEvent`
enum bus). If a screen accumulates several, it is usually a sign the primitives could have
been parameterized after all.

## Screen as sheet or dialog - typed results

The dialog conventions (private constructor, static `show()`, typed pop payloads) are
defined in [screen-state-view.md](./screen-state-view.md). The screen-grade version hosts
a full Screen/State/View triple in an adaptive container - bottom sheet on compact
layouts, dialog on wide ones - and the widget plays the Screen role: it builds
`Navigator.pop`-based callbacks for the state hook.

```dart
class OnboardingTourScreen extends HookWidget {
  const OnboardingTourScreen._();

  // adaptive: same screen via showDialog<bool> on wide layouts (branch on MediaQuery width)
  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const OnboardingTourScreen._(),
      );

  @override
  Widget build(BuildContext context) {
    final state = useOnboardingTourScreenState(
      finish: () => Navigator.of(context).pop(true),  // completed
      skip: () => Navigator.of(context).pop(false),   // explicit skip
    );
    return OnboardingTourScreenView(state: state);
  }
}

// Caller:
final completed = await OnboardingTourScreen.show(context);
// true = completed, false = skipped, null = dismissed (tap outside / system back)
```

The three-valued payload is the convention worth keeping: `true` success, `false` explicit
decline, `null` dismissal - callers that do not care simply check `== true`. The state hook
never knows it lives in a sheet; it receives `finish`/`skip` callbacks like any navigation.

## NavigatorKey - the rare sanctioned global access

`NavigatorKey` (an app-level `typedef NavigatorKey = GlobalKey<NavigatorState>`) is
registered in `_providers` and passed to `MaterialApp.navigatorKey` - see
[app-bootstrap.md](./app-bootstrap.md). Exactly one layer may read it: **the app shell** -
hooks living above the route stack, with no screen `BuildContext` of their own. In
practice that is two consumers:

- the status-driven redirect above
- the global error dialog pushed by the root error subscriber (see
  [error-handling.md](./error-handling.md))

Screen state hooks never read it (`useProvided<NavigatorKey>` in a screen hook is the
top entry in screen-state-view.md's forbidden list). The asymmetry is deliberate: a screen
always has a better tool - its own `BuildContext`, closed over by the Screen into typed,
test-fakeable callbacks - while the shell sits above the `Navigator` with no context of
its own, so there the key is the only handle that exists. A screen that seems to "need"
the key wants either a Screen-built callback or the shell redirect.

## Common Pitfalls

- **`BuildContext` smuggled via a `setContext` setter / context field on the State** - the
  hook-takes-context anti-pattern in a trench coat, plus a stale-context bug after rebinds;
  build typed callbacks in the Screen instead
- **View calling `Navigator` directly** - the View calls `state.onClosePressed`; the
  Screen-built callback pops
- **State hook taking `BuildContext`** - one parameter instead of three callbacks is the
  wrong trade; the callbacks ARE the hook's contract (see screen-state-view.md)
- **Navigation buried in submit `run()` when the trigger is global state** - fires for that
  one code path only; key a `useEffect` on the global flag instead
- **Magic route strings at call sites** - the string lives once, in `Screen.route`; callers
  use `Screen.navigate(...)`
- **Splash decision tree AND status redirect both active** - they race and
  double-navigate; the redirect hook subsumes the splash one-shot
- **Untyped result routes** - declare `MaterialPageRoute<T>` when the screen pops a result,
  or a later typed `pushNamed<T>` fails its cast on the `Route<dynamic>`

## Ecosystem note

`utopia_arch` (optional, not required by this skill) ships a ready-made implementation of
exactly this shape - route factories with typed results, args reading, reset-style pushes.
The conventions above are the contract; arch is one implementation of it.

## Related Skills

- [screen-state-view.md](./screen-state-view.md) - the callback rule this file builds on; dialog result conventions
- [app-bootstrap.md](./app-bootstrap.md) - `_providers`, `NavigatorKey` registration, splash decision tree
- [multi-page-shell.md](./multi-page-shell.md) - tab/bottom-nav shells, router-backed shell variant
- [error-handling.md](./error-handling.md) - the global error dialog, the other sanctioned NavigatorKey consumer
- [async-patterns.md](./async-patterns.md) - useSubmitState semantics behind `afterSubmit` navigation
