---
title: Error Handling
impact: HIGH
tags: errors, let-it-crash, Retryable, retry, error-dialog, crash-reporting, crash-context, runZonedGuarded, runSimple, mapError
---

# Skill: Error Handling

The rest of this skill says "let errors crash by default". This file shows where those crashes
land: an app-root catcher (a zone handler plus `FlutterError.onError`) that reports every
uncaught error and surfaces it as a retryable dialog, the `Retryable` mechanism behind the
Retry button (from `utopia_utils`, re-exported by `utopia_hooks`), and the split between
expected errors (handled locally, e.g. as field messages) and unexpected ones (left to crash).

## Quick Pattern

**Incorrect (swallowing the error because "something has to catch it"):**
```dart
Future<void> save() => submitState.run(() async {
  try {
    await itemService.save(draft);
  } catch (e) {
    print(e); // swallowed - no report, no dialog, no retry
  }
});
```

**Correct (no catch - the app-root pipeline reports it and shows a retry dialog):**
```dart
// In the state hook: let it crash.
Future<void> save() => submitState.run(() => itemService.save(draft));

// In main, once: every uncaught error is reported and surfaced to the UI.
void main() {
  runWithGlobalErrorHandling(appReporter, (uiErrors) {
    WidgetsFlutterBinding.ensureInitialized(); // must be called INSIDE the zone
    runApp(MyApp(uiErrors: uiErrors));
  });
}
// runWithGlobalErrorHandling is ~20 lines of your own code - defined below.
```

## Where errors land

| Error | Where it lands |
|-------|----------------|
| Uncaught error in `submitState.run` | Rethrown out of `run`; the (typically unawaited) future reaches the zone handler -> crash report + error dialog. `run` attaches a `Retryable` by default. |
| Failed compute (`useComputedState` / `useAutoComputedState`) | Captured as `ComputedStateValue.failed` for the View to render. Auto-triggered refreshes are fire-and-forget, so the failure also propagates through the zone to the pipeline. |
| Expected error (known backend code) | Handled locally via `runSimple` `mapError`/`afterKnownError` - e.g. assigned to `FieldState.errorMessage`. Never reaches the pipeline. |
| Flutter framework error | `FlutterError.onError` -> crash report; non-silent ones also surface to the error dialog. |

## The app-root catcher - build it once

Plain Dart/Flutter, no extra packages. Two catchers cover everything the let-it-crash rule
throws at you, and a broadcast stream carries each error (with its `Retryable` handle, if any)
to the UI layer:

```dart
typedef AppError = ({Object error, void Function()? retry});

void runWithGlobalErrorHandling(
  AppReporter reporter,
  void Function(Stream<AppError> uiErrors) block,
) {
  final controller = StreamController<AppError>.broadcast();

  void handle(Object error, StackTrace? stack) {
    reporter.report(error, stack);
    controller.add((error: error, retry: Retryable.tryGet(error)?.retry));
  }

  // Framework errors (build/layout/paint). Silent ones are reported but not surfaced.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (!details.silent) handle(details.exception, details.stack);
  };

  // Uncaught async errors - the let-it-crash path (unawaited submit futures etc.).
  runZonedGuarded(() => block(controller.stream), handle);
}
```

**Warning:** `WidgetsFlutterBinding.ensureInitialized()` (and `runApp`) must be called inside
the zone - i.e. inside `block` - otherwise framework callbacks are bound to the outer zone and
some errors bypass the handler.

### Wiring at the app root

```dart
typedef NavigatorKey = GlobalKey<NavigatorState>;

class MyApp extends HookWidget {
  static void run() {
    runWithGlobalErrorHandling(appReporter, (uiErrors) {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(MyApp(uiErrors: uiErrors));
    });
  }

  final Stream<AppError> uiErrors;

  const MyApp({super.key, required this.uiErrors});

  @override
  Widget build(BuildContext context) {
    final navigatorKey = useMemoized(GlobalKey<NavigatorState>.new);

    return HookProviderContainerWidget(
      _buildProviders(navigatorKey),
      child: HookBuilder(
        builder: (context) {
          useStreamSubscription<AppError>(
            uiErrors,
            (error) async => _handleUiError(context, error, navigatorKey.currentState!),
            // drop = ignore new errors while one is being shown - no stacked dialogs
            strategy: StreamSubscriptionStrategy.drop,
          );
          return MaterialApp(navigatorKey: navigatorKey /* routes, theme, ... */);
        },
      ),
    );
  }

  Map<Type, Object? Function()> _buildProviders(NavigatorKey navigatorKey) => {
        NavigatorKey: () => navigatorKey,
        // global states - see global-state.md and app-bootstrap.md
      };

  Future<void> _handleUiError(BuildContext context, AppError error, NavigatorState navigator) async {
    if (error.error is AssertionError) return; // debug-time noise - already reported
    final route = DialogRoute<void>(context: context, builder: (_) => AppErrorDialog(error: error));
    await navigator.push(route);
  }
}
```

Three details that matter:

- **Subscribe below the provider container.** The `HookBuilder` sits under
  `HookProviderContainerWidget`, so the handler can read provided state if needed.
- **`StreamSubscriptionStrategy.drop`.** The handler awaits dialog dismissal; with the default
  `parallel` strategy a burst of errors would stack dialogs. `drop` collapses the burst into one.
- **The root `NavigatorKey`.** Pushing the dialog through `navigatorKey.currentState!` is the
  sanctioned global navigator access at the app shell - screens never do this
  (see [navigation.md](./navigation.md)).

### The error dialog with Retry

```dart
class AppErrorDialog extends StatelessWidget {
  final AppError error;

  const AppErrorDialog({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Error"),
      content: Text(kDebugMode ? error.error.toString() : "Something has gone wrong."),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
        if (error.retry case final retry?)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              retry();
            },
            child: const Text("Retry"),
          ),
      ],
    );
  }
}
```

## Retryable - what powers the Retry button

From `package:utopia_utils/utopia_utils.dart` (re-exported by `utopia_hooks` and `utopia_arch`):

```dart
class Retryable {
  factory Retryable.make(Object object, void Function() retry); // attach retry to an error
  static Retryable? tryGet(Object object);                      // null if not retryable
  void retry();
}
```

`Retryable.make` attaches the retry closure to the error object itself (via an `Expando`), so the
original exception keeps propagating unchanged and any catcher - including the app-root catcher -
can recover the retry with `Retryable.tryGet(error)`. The `AppError.retry` field built above is
exactly that.

**Who attaches it (defaults):**

| API | `isRetryable` default | What `retry()` does |
|-----|----------------------|----------------------|
| `submitState.run(block)` | `true` | re-runs `run(block)` (inProgress counts again) |
| `submitState.runSimple(...)` | `true` (passed through to `run`) | same |
| `useComputedState` | `false` (opt-in) | calls `refresh()` again |
| `useAutoComputedState` | `false` (opt-in) | calls `refresh()` again |

Manual retry affordance for a failed computed state (e.g. an inline error placeholder instead of
the global dialog):

```dart
final retry = state.items.value.maybeWhen(
  failed: (e) => Retryable.tryGet(e)?.retry,
  orElse: () => null,
);
// View: error placeholder with onRetry: retry (button hidden when null)
```

**Caveat (from the source docs):** the retry closure re-runs the *original* computation. For
`useAutoComputedState`, `shouldCompute` may have changed by the time the user taps Retry, which
can have unintended consequences - the retry is not re-gated.

## Expected vs unexpected - the split

Expected errors (a backend code you have UX for) are handled locally via `runSimple`'s
`mapError` -> `afterKnownError` and never reach the pipeline. Everything else - network down,
contract change, null deref - rethrows automatically: zone -> reporter -> global dialog with
Retry. Do not add a catch-all "just in case" - that is the pipeline's job. The worked
`runSimple` example and full form-UX detail (validation, `afterError`, snackbars) live in
[async-patterns.md](./async-patterns.md).

## Reporting from state hooks

The `AppReporter` passed to `runWithGlobalErrorHandling` is also your manual breadcrumb
channel. It is a tiny facade you own, over whichever crash-reporting SDK the app uses:

```dart
// app_reporter.dart
final appReporter = AppReporter();

class AppReporter {
  void report(Object error, StackTrace? stack) {
    log('uncaught', error: error, stackTrace: stack);
    crashReporting.recordError(error, stack); // Crashlytics / Sentry / your SDK
  }

  void info(String message) => crashReporting.addBreadcrumb(message);
  void warning(String message, {Object? e}) => crashReporting.addBreadcrumb('$message $e');
}
```

Use `info` / `warning` for handled-but-noteworthy situations - the cases where you
deliberately do NOT crash:

```dart
// In a global state hook: degraded path, not a failure worth a dialog
useEffect(() {
  if (tokenSnap.hasError) appReporter.warning("Failed to get push token", e: tokenSnap.error);
}, [tokenSnap.hasError]);
```

### Declarative crash context

Tiny `useEffect` wrappers turn telemetry into one-liners that global state hooks declare
alongside the state itself:

```dart
// e.g. Sentry scope, Crashlytics custom keys - whatever your SDK exposes
void useCrashContext(String key, Object? value) {
  useEffect(() {
    crashReporting.setContext(key, value); // your SDK call
  }, [value]);
}

// In useAuthState():
useCrashContext("userId", user?.uid);

// Breadcrumb on every transition of a key flag:
useEffect(() => appReporter.info("Auth changed: loggedIn=${user != null}"), [user != null]);
```

Crash reports then always carry the current user/session context with zero imperative wiring.

## Common Pitfalls

- **Blanket `catch` + `print` in global init effects** - swallows bootstrap failures; the app
  hangs on splash with nothing in the crash reporter. Let it crash, or report + rethrow.
  See [app-bootstrap.md](./app-bootstrap.md) for retryable bootstrap states.
- **Stacked error dialogs** - `useStreamSubscription`'s default strategy is `parallel`; an error
  burst pushes one dialog per error. Use `StreamSubscriptionStrategy.drop` for the error stream.
- **Catching in the View** - Views are pass-through. Error UX decisions belong in the state hook
  (expected errors) or the app-root pipeline (unexpected ones).
- **Manual `bool hasError` flags next to a submit state** - the pipeline and
  `ComputedStateValue.failed` already carry the error; a parallel flag drifts out of sync.
- **Marking everything retryable** - `retry()` re-runs the original closure without re-checking
  preconditions (`shouldCompute` may have flipped). Opt in deliberately on computed states.

## Ecosystem note

`utopia_arch` (optional, not required by this skill) ships a ready-made version of this
pipeline - same shape: a reporter, a zone + framework catcher around `main()`, and a broadcast
stream of UI-surfaced errors carrying `Retryable` handles. The hand-rolled catcher above is a
drop-in equivalent for apps that do not depend on it.

## Related Skills

- [async-patterns.md](./async-patterns.md) - `runSimple` deep dive, let-it-crash strategy, form error UX
- [app-bootstrap.md](./app-bootstrap.md) - retryable bootstrap states, splash gating on initialization
- [navigation.md](./navigation.md) - why only the app shell touches the root `NavigatorKey`
- [hooks-reference.md](./hooks-reference.md) - exact signatures for `useSubmitState`, `useComputedState`, `useStreamSubscription`
- [global-state.md](./global-state.md) - the `_providers` map the pipeline wiring sits above
