---
title: App Bootstrap & Initialization
impact: HIGH
tags: bootstrap, initialization, startup, splash, HasInitialized, useCombinedInitializationState, providers, SDK-init, ordering
---

# Skill: App Bootstrap & Initialization

How an app gets from `main()` to its first real screen. Bootstrap work (SDK init, session
restore, remote config) is modeled as ordinary `HasInitialized` global states - reactive,
retryable, and observable - instead of awaited sequentially in `main()` behind manual flags.

## Quick Pattern

**Incorrect (sequential bootstrap in main() with manual flags):**
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();                       // first frame blocked
  final config = await ConfigService().fetch();         // one failure = app never starts
  final session = await AuthService().restoreSession(); // no retry, no reactivity
  runApp(MyApp(config: config, session: session));      // frozen snapshot of boot data
}
```

**Correct (bootstrap as global states, splash gated on an aggregate):**
```dart
// main.dart stays minimal. runWithGlobalErrorHandling is the ~20-line app-root catcher
// from error-handling.md - ensureInitialized and runApp must run INSIDE its zone.
Future<void> main() async {
  runWithGlobalErrorHandling(appReporter, (uiErrors) async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppServices.initialize(); // builds the Injector - see di-services.md
    runApp(MyApp(uiErrors: uiErrors));
  });
}

// Each bootstrap step is a HasInitialized global state
FirebaseState useFirebaseState() {
  final initState = useAutoComputedState<void>(() => Firebase.initializeApp());
  return FirebaseState(isInitialized: initState.isInitialized); // extends HasInitialized
}

// One aggregate (InitializationState) composes readiness and gates the splash - see below
```

## When to Use

- Setting up a new app root (`_providers` map, splash screen, first navigation)
- Adding a global state that depends on another global state (auth -> profile -> feed)
- Anything that must complete before the first real screen: SDK init, session restore, remote config
- Debugging "Firestore throws at startup" / "plugin used before initialization" races
- A bootstrap step that can fail and needs a retry affordance

## The ordered `_providers` map

All global states are registered in one map at the app root (see [global-state.md](./global-state.md)).
Providers are built **in map order** on the first build, so the map doubles as the dependency
graph of your bootstrap: each entry may `useProvided` only entries registered **above** it.

```dart
// app.dart
typedef NavigatorKey = GlobalKey<NavigatorState>;

final _navigatorKey = NavigatorKey();

final _providers = <Type, Object? Function()>{
  // --- Architectural ---
  Injector: () => AppServices.injector, // built in main() - see di-services.md
  NavigatorKey: () => _navigatorKey,    // consumed only at the app shell - see navigation.md

  // --- Data states - each may useProvided entries registered above it ---
  FirebaseState: useFirebaseState,
  RemoteConfigState: useRemoteConfigState, // gated on FirebaseState
  AuthState: useAuthState,                 // gated on FirebaseState
  ProfileState: useProfileState,           // gated on AuthState

  // --- Functional states - orchestration hooks nothing reads (sync, analytics) ---
  SyncState: useSyncState,

  // --- Aggregate readiness - leave at the end, it reads everything above ---
  InitializationState: useInitializationState,
};

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return HookProviderContainerWidget(
      _providers,
      child: MaterialApp(navigatorKey: _navigatorKey, home: const SplashScreen()),
    );
  }
}
```

The grouping comments and aggregate-last placement above ARE the convention - with 20+ globals
the map stays readable as the app's boot diagram. `NavigatorKey` is app-shell-only (boot
redirect, global error dialog - see [navigation.md](./navigation.md)); screen state hooks never
read it (see [screen-state-view.md](./screen-state-view.md)).

## HasInitialized chains - gating one global on another

Downstream bootstrap states gate their compute on upstream readiness with `shouldCompute`:

```dart
class ProfileState extends HasInitialized {
  final Profile? profile;
  const ProfileState({required super.isInitialized, required this.profile});
}

ProfileState useProfileState() {
  final auth = useProvided<AuthState>();
  final service = useInjected<ProfileService>();

  final profileState = useAutoComputedState(
    () => service.load(auth.userId!),
    shouldCompute: auth.isInitialized && auth.isLoggedIn,
    keys: [auth.userId], // re-load when the user changes
  );

  return ProfileState(
    // Not-applicable-tolerant: logged out means there is no profile step to wait for.
    isInitialized: auth.isInitialized && (!auth.isLoggedIn || profileState.isInitialized),
    profile: profileState.valueOrNull,
  );
}
```

Three things make this chain correct:

- **`shouldCompute` is itself a key** inside `useAutoComputedState`, so the flip from `false`
  to `true` re-triggers the compute by itself. Add `keys:` only for other compute inputs.
- **`shouldCompute: false` clears the state immediately** - logout wipes the profile
  automatically, no manual cleanup effect needed.
- **Every `ComputedState` implements `HasInitialized`** (`isInitialized` == value is ready),
  so `profileState.isInitialized` composes directly into the formula.

### The not-applicable-tolerant formula

```
isInitialized = upstreamReady && (!applicable || stepDone)
```

A state that waits unconditionally on a step that will never run (profile load while logged
out, purchases while offline, sync for anonymous users) deadlocks the whole boot: the
aggregate never flips and the splash never routes. Always express "this step does not apply"
as initialized.

### Stream-backed chains

For stream-backed globals the same gate is a nullable stream factory - `null` means no
subscription yet - and "first emission arrived" is the readiness signal:

```dart
final snap = useMemoizedStream(
  () => auth.isLoggedIn ? service.watchRooms(auth.userId!) : null,
  keys: [auth.userId],
);
final isInitialized = auth.isInitialized &&
    (!auth.isLoggedIn || snap.connectionState == ConnectionState.active);
```

See [async-patterns.md](./async-patterns.md) for the full isInitialized-from-snapshot pattern.

## Aggregating readiness - one InitializationState

A dedicated global whose only job is composing readiness. Convention: a typedef plus a
`const Set<Type>` listing every composed state, in its own file:

```dart
// initialization_state.dart
typedef InitializationState = CombinedInitializationState;

// Every type listed here must implement HasInitialized
// and be registered ABOVE InitializationState in _providers.
const Set<Type> _initializationStates = {
  FirebaseState,
  RemoteConfigState,
  AuthState,
  ProfileState,
};

InitializationState useInitializationState() =>
    useCombinedInitializationState(_initializationStates);
```

`useCombinedInitializationState(Set<Type> types)` looks each type up in the provider
container, casts it to `HasInitialized`, and ANDs the flags. Adding a bootstrap state to the
app is then two edits: one `_providers` entry, one line in this set.

When readiness needs domain gates beyond the flags, compose manually with the
`HasInitialized.all` / `any` / `keys` helpers, e.g.
`HasInitialized.all([auth, profile]) && auth.sessionRestored`.

## Splash gating - the boot decision tree

The splash screen renders nothing (the native splash, e.g. `flutter_native_splash`, still
covers the app), waits for the aggregate flag, then routes exactly once. It is the lightweight
tier from [screen-state-view.md](./screen-state-view.md) ("The Lightweight Tier"): a single
`HookWidget` that reads the globals and runs the decision tree inline in `build` - no
State/View split, no separate hook, and (since the tree IS its only logic) no navigate-callback
parameters. Route names come from the screens' own `static route` constants
(see [navigation.md](./navigation.md)) - never inline string literals.

```dart
class SplashScreen extends HookWidget {
  static const route = '/splash';

  @override
  Widget build(BuildContext context) {
    final initialization = useProvided<InitializationState>();
    final config = useProvided<RemoteConfigState>();
    final auth = useProvided<AuthState>();
    final profile = useProvided<ProfileState>();

    useEffect(() {
      if (!initialization.isInitialized) return null;

      // Decision tree - first match wins. Navigate inline; the Screen owns context.
      final navigator = context.navigator;
      if (config.isUpdateRequired) {
        navigator.pushReplacementNamed(UpdateRequiredScreen.route);
      } else if (!auth.isLoggedIn) {
        navigator.pushReplacementNamed(LandingScreen.route);
      } else if (profile.profile?.isRegistrationComplete != true) {
        navigator.pushReplacementNamed(RegistrationScreen.route);
      } else {
        navigator.pushReplacementNamed(MainScreen.route);
      }
      FlutterNativeSplash.remove();
      return null;
    }, [initialization.isInitialized]);

    return const SizedBox.shrink();
  }
}
```

The effect is keyed on the single aggregate flag: it runs once on mount (flag still `false`,
returns early) and once when the flag flips. Navigation lives in the Screen's own effect, where
`BuildContext` belongs. If your app can regress mid-session (sign-out, forced re-auth), the
splash one-shot is not enough - see the status-driven redirect in [navigation.md](./navigation.md).

## SDK init races

All providers build on the container's first build, and `useAutoComputedState` fires its
compute on mount - possibly **before** `Firebase.initializeApp()`-style setup has completed.
Touching the SDK in that window throws. The convention: every SDK-touching compute or stream
is gated on the SDK's own state.

```dart
ItemsState useItemsState() {
  final firebase = useProvided<FirebaseState>();
  final service = useInjected<ItemService>();

  final itemsState = useAutoComputedState(
    () => service.fetchAll(),              // touches Firestore
    shouldCompute: firebase.isInitialized, // re-triggers itself when the SDK comes up
  );

  return ItemsState(isInitialized: itemsState.isInitialized, items: itemsState.valueOrNull);
}
```

For streams, return `null` from the factory until the prerequisite is ready, exactly as in
"Stream-backed chains" above - and there `keys:` is required, because `useMemoizedStream`
only re-evaluates the factory when the keys you pass change.

## One-shot setup as a value-less computed state

Any "run this once at startup" step (SDK configure, asset precache, migration) is a
`useAutoComputedState<void>` - not a manual `bool` flag with try/catch/finally:

```dart
class BillingSetupState extends HasInitialized {
  const BillingSetupState({required super.isInitialized});
}

BillingSetupState useBillingSetupState() {
  final service = useInjected<BillingService>();
  final setupState = useAutoComputedState<void>(() => service.configure());
  return BillingSetupState(isInitialized: setupState.isInitialized);
}
```

Readiness IS the computed value: `isInitialized` is derived from it, failure leaves it
`false` (the aggregate keeps gating), and `setupState.refresh()` is a free retry.

## Retryable bootstrap

A failed bootstrap state keeps `isInitialized == false` forever, so the splash hangs. Two
affordances:

```dart
class RemoteConfigState extends HasInitialized {
  final Config? config;
  final Object? error; // non-null when bootstrap failed
  final Future<void> Function() retry; // on the state, travelling with the flag the splash reads

  const RemoteConfigState(
      {required super.isInitialized, required this.config, required this.error, required this.retry});
}

RemoteConfigState useRemoteConfigState() {
  final service = useInjected<ConfigService>();
  final configState = useAutoComputedState(() => service.fetch(), isRetryable: true);

  return RemoteConfigState(
    isInitialized: configState.isInitialized,
    config: configState.valueOrNull,
    error: configState.value.maybeWhen(failed: (e) => e, orElse: () => null),
    retry: configState.refresh,
  );
}
```

- **Locally:** expose `error` and `retry` on the state; the splash (the one place allowed to
  render in that window) shows a retry button when a bootstrap state reports a failure.
- **Globally:** with `isRetryable: true` the error object carries its own retry -
  `Retryable.tryGet(error)?.retry()` re-runs the original compute. The app-level retry
  dialog wired to this lives in [error-handling.md](./error-handling.md).

## Common Pitfalls

- **Provider registered before its dependency** - `useProvided<X>()` with `X` lower in the map
  throws `ProvidedValueNotFoundException` at startup and the entry stays broken ("Provider not
  built yet" on every read). Reorder the map
- **Aggregate not last** - `useCombinedInitializationState` resolves every listed type from
  the container; types registered below it (or missing) fail at startup
- **Waiting on a step that never runs** - profile while logged out, purchases while offline;
  the aggregate never flips and the splash hangs. Use `upstreamReady && (!applicable || stepDone)`
- **Bootstrap in main() with manual flags** - blank first frame, one failure aborts the launch,
  no retry. `main()` does `ensureInitialized` + Injector + `runApp`, nothing else
- **Splash gating on individual flags instead of the aggregate** - new bootstrap states get
  forgotten; gate on `InitializationState` and maintain one `Set<Type>`
- **Surprised by `shouldCompute: false` clearing state** - the wipe is the feature (logout
  clears the profile), but do not rely on stale `valueOrNull` after the gate closes

## Related Skills

- [global-state.md](./global-state.md) - per-state HasInitialized docs, `_providers` registration basics
- [error-handling.md](./error-handling.md) - Retryable mechanics and the app-level retry dialog
- [navigation.md](./navigation.md) - status-driven redirects after the splash one-shot
- [async-patterns.md](./async-patterns.md) - useAutoComputedState semantics, isInitialized for stream-backed globals
- [di-services.md](./di-services.md) - building the Injector before runApp, useInjected
