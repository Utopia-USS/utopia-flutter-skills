---
name: utopia-hooks
description: >
  Flutter state management with utopia_hooks. Applies when writing Flutter screens,
  adding shared app state, handling async operations, injecting services, or migrating
  away from StatefulWidget. Covers the Screen/State/View pattern, hook catalog, global
  state registration, useSubmitState, useAutoComputedState, and dependency injection.
license: MIT
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_hooks, state-management, hooks
---

# utopia_hooks — Flutter State Management

## Overview

Holistic state management for Flutter using hooks. Every screen follows the
**Screen → State → View** tripartite pattern. Shared app state lives in
**StateClass + hook + `_providers`**. All logic belongs in hooks — never in widgets.

## Skill Format

Each reference file follows a hybrid format for fast lookup and deep understanding:

- **Quick Pattern**: ❌ Incorrect / ✅ Correct Dart code for immediate pattern matching
- **Deep Dive**: Full context — When to Use, Prerequisites, Step-by-Step, Common Pitfalls
- **Impact ratings**: CRITICAL (always apply), HIGH (significant correctness/quality gain), MEDIUM (worthwhile improvement)

## When to Apply

Reference these guidelines when:

- Building a new Flutter screen or adding a feature to an existing one
- Adding shared app-wide state (auth, settings, data caches, …)
- Handling async operations, form submissions, or loading states
- Injecting a service into a screen or registering a new dependency
- Reviewing Flutter code — looking for logic in View, widgets in State, or raw `setState` patterns
- Migrating from `StatefulWidget`, BLoC, Riverpod, or Provider

## Priority-Ordered Guidelines

| Priority | Category                                | Impact   | Reference |
|----------|-----------------------------------------|----------|-----------|
| 1        | Screen architecture (Screen/State/View) | CRITICAL | [screen-state-view.md][screen-state-view] |
| 2        | Hook catalog & correct usage          | CRITICAL | [hooks-reference.md][hooks-reference] |
| 3        | Async patterns (download / upload)    | HIGH     | [async-patterns.md][async-patterns] |
| 4        | Flutter code conventions              | HIGH     | [flutter-conventions.md][flutter-conventions] |
| 5        | Global shared state                   | HIGH     | [global-state.md][global-state] |
| 6        | Dependency injection & services       | MEDIUM   | [di-services.md][di-services] |
| 7        | Composable & widget-level hooks       | MEDIUM   | [composable-hooks.md][composable-hooks] |
| 8        | Testing hooks in isolation            | MEDIUM   | [testing.md][testing] |

## Quick Reference

### Screen Architecture (CRITICAL)

Every screen = **3 files**. No exceptions.

```
feature_screen.dart                ← HookWidget, zero logic
state/feature_screen_state.dart    ← State class + hook
view/feature_screen_view.dart      ← StatelessWidget, UI only
```

**Screen** — pure wiring: builds nav callbacks from `BuildContext`, calls `useXScreenState`, renders View:
```dart
class TaskScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTaskScreenState(
      navigateToDetail: (id) => Navigator.of(context).pushNamed('/task', arguments: id),
    );
    return TaskScreenView(state: state);
  }
}
```

**State** — immutable data class + hook with all logic:
```dart
class TaskScreenState {
  final IList<Task> tasks;
  final bool isLoading;
  final void Function(TaskId) onTaskTapped;
  const TaskScreenState({required this.tasks, required this.isLoading, required this.onTaskTapped});
}

TaskScreenState useTaskScreenState({required void Function(TaskId) navigateToDetail}) {
  final tasksState = useProvided<TasksState>();
  return TaskScreenState(
    tasks: tasksState.tasks ?? const IList.empty(),
    isLoading: !tasksState.isInitialized,
    onTaskTapped: navigateToDetail,
  );
}
```

**View** — pure UI, no hooks, no logic:
```dart
class TaskScreenView extends StatelessWidget {
  final TaskScreenState state;
  const TaskScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const CrazyLoader();
    return ListView(children: state.tasks.map(_buildTask).toList());
  }
}
```

### Global State Registration (CRITICAL)

```dart
// 1. State class
class SettingsState extends HasInitialized {
  final ThemeMode themeMode;
  const SettingsState({required super.isInitialized, required this.themeMode});
}

// 2. Hook
SettingsState useSettingsState() {
  final snap = useMemoizedStream(settingsStream);
  return SettingsState(
    isInitialized: snap.connectionState == ConnectionState.active,
    themeMode: snap.data?.themeMode ?? ThemeMode.system,
  );
}

// 3. Register in app root — once
const _providers = {
  SettingsState: useSettingsState,
  // ...
};
```

### Async: Download vs Upload (HIGH)

```dart
// DOWNLOAD (read) → useAutoComputedState
final product = useAutoComputedState(
  () async => productService.load(productId),
  keys: [productId],
  shouldCompute: authState.isInitialized,
);
// product.isInitialized / product.valueOrNull

// UPLOAD (write) → useSubmitState — let errors crash by default
final submitState = useSubmitState();
void save() => submitState.runSimple<void, Never>(
  submit: () async => service.save(data),
  afterSubmit: (_) => navigateBack(),
);
// submitState.inProgress — blocks duplicate requests
// submitState.toButtonState(enabled: isValid, onTap: save)
```

## References

Full documentation with code examples in [references/][references]:

| File | Impact | Description |
|------|--------|-------------|
| [screen-state-view.md][screen-state-view] | CRITICAL | 3-file screen pattern: Screen, State class + hook, View |
| [hooks-reference.md][hooks-reference] | CRITICAL | Full hook catalog: useState, useMemoized, useEffect, useProvided, useInjected, useIf, useMap, useComputedState |
| [global-state.md][global-state] | CRITICAL | App-wide state: StateClass, HasInitialized, MutableValue, _providers registration |
| [async-patterns.md][async-patterns] | HIGH | useSubmitState, useAutoComputedState, useMemoizedStream, loading guards |
| [composable-hooks.md][composable-hooks] | HIGH | Widget-level hooks, composed hook state, and screen hook decomposition for large hooks |
| [testing.md][testing] | HIGH | Unit testing hooks with SimpleHookContext and SimpleHookProviderContainer — no widget tree needed |
| [flutter-conventions.md][flutter-conventions] | HIGH | IList/IMap/ISet, `it` lambdas, strict analyzer, widget extraction, spacing, generated code, TextEditingController |
| [di-services.md][di-services] | MEDIUM | DI bridge hook, useInjected pattern, service types (Firebase/Api/Data) |

## Searching References

```bash
# Find patterns by hook name
grep -rl "useSubmitState" references/
grep -rl "useMemoizedStream" references/
grep -rl "HasInitialized" references/
grep -rl "MutableValue" references/
grep -rl "useInjected" references/
grep -rl "useProvided" references/
```

## Problem → Skill Mapping

| Problem | Start With |
|---------|------------|
| Adding a new screen | [screen-state-view.md][screen-state-view] |
| Logic is leaking into the View | [screen-state-view.md][screen-state-view] |
| Widget imports in a State class | [screen-state-view.md][screen-state-view] |
| App-wide state (auth, config, data) | [global-state.md][global-state] |
| Screen not reacting to state changes | [global-state.md][global-state] → [hooks-reference.md][hooks-reference] |
| Form submission with loading/error | [async-patterns.md][async-patterns] |
| Async data with loading spinner | [async-patterns.md][async-patterns] |
| Stream that should drive UI | [hooks-reference.md][hooks-reference] (useMemoizedStream) |
| Derived value from other state | [hooks-reference.md][hooks-reference] (useMemoized) |
| Widget with expand/collapse, animation, lazy load | [composable-hooks.md][composable-hooks] (widget-level hook) |
| Reusable widget used N times on one screen | [composable-hooks.md][composable-hooks] (composed hook state) |
| Screen state polluted with per-tile logic | [composable-hooks.md][composable-hooks] (widget-level hook) |
| Paging, specialized text field, reusable control | [composable-hooks.md][composable-hooks] (composed hook state) |
| TextEditingController / FocusNode handling | [flutter-conventions.md][flutter-conventions] |
| Testing a screen state hook | [testing.md][testing] |
| Testing global state and state interactions | [testing.md][testing] |
| Injecting a service into a screen | [di-services.md][di-services] |
| Registering a new service or state | [di-services.md][di-services] |
| Using `List` / `Map` / `Set` instead of immutable | [flutter-conventions.md][flutter-conventions] |
| Lambda style, naming, widget extraction | [flutter-conventions.md][flutter-conventions] |
| Generated code out of date | [flutter-conventions.md][flutter-conventions] |
| Replacing StatefulWidget | [screen-state-view.md][screen-state-view] + [hooks-reference.md][hooks-reference] |
| State hook is too large (>300 lines, >10 useState) | [composable-hooks.md][composable-hooks] (screen hook decomposition, Pattern 3) |

[references]: references/
[screen-state-view]: references/screen-state-view.md
[hooks-reference]: references/hooks-reference.md
[global-state]: references/global-state.md
[async-patterns]: references/async-patterns.md
[composable-hooks]: references/composable-hooks.md
[testing]: references/testing.md
[flutter-conventions]: references/flutter-conventions.md
[di-services]: references/di-services.md

## Non-Negotiable Rules

- **View never calls hooks** — no `useState`, `useProvided`, `useInjected` in `*_view.dart`. View is always `StatelessWidget`.
- **View constructor takes ONLY `state`** — no extra `onBack`, `onNavigate`, or other parameters. All callbacks are fields on the State class.
- **Screen = pure wiring** — Screen's `build()` reads `BuildContext` (for navigation/dialogs/args) and calls exactly one hook: `useXScreenState(...)`. Screen must NOT call `useInjected`, `useProvided`, `useEffect`, `useState`, or any other hook.
- **Navigation flows Screen → State → View as callbacks** — never `useProvided<NavigatorKey>` or `useInjected<AppRouter>`. State hook receives navigation as `void Function()` / `Future<T?> Function()` parameters.
- **State never imports widgets** — no Flutter widget imports in `*_screen_state.dart`
- **`useProvided` / `useInjected` only in screen state hooks** — not in Screen, not in View, not passed down as parameters
- **No mutable collections in State classes** — always `IList`/`IMap`/`ISet`, never `List`/`Map`/`Set`, including static data
- **No manual loading state** — never use `useState<bool>` + `try/catch/finally` for data loading. Always `useAutoComputedState`.
- **Prefer `useMemoized` over `useEffect`** for derived state — effects cascade; memoized values don't
- **One State class per screen** — all screen data in one place, not scattered `useState` calls across the widget tree
- **Never wrap `TextEditingController` in `useMemoized` + `useListenable`** — always `useFieldState` in the state hook + `TextEditingControllerWrapper` in the View. See [flutter-conventions.md][flutter-conventions].
- **View files ≤ ~300 lines** — extract complex widgets to `widget/` folder, using widget-level hook pattern from [composable-hooks.md](references/composable-hooks.md) when they have own state

## Self-Audit Checklist

After generating a screen, verify:

1. Does the View constructor take anything beyond `state`? → Move it to the State class
2. Does the Screen call any hook other than `useXScreenState(...)` (e.g., `useInjected`, `useProvided`, `useEffect`)? → Move to state hook
3. Are there `useState<bool>(true)` / `useState<T?>(null)` for loading/error? → Use `useAutoComputedState`
4. Are there mutable `List<T>`, `Map<K,V>`, `Set<T>` in the State class? → Use `IList`/`IMap`/`ISet`
5. Are there more than 2 `useSubmitState()` in one hook? → Group mutually exclusive actions
6. Is any view file > 300 lines? → Extract widgets to `widget/` folder
7. Does the View extend `HookWidget`? → Must be `StatelessWidget`
8. Is any state hook > ~300 lines or > ~10 useState? → Decompose into sub-hooks (see [composable-hooks.md][composable-hooks] Pattern 3)
9. Any `useProvided<NavigatorKey>` / `useInjected<AppRouter>` / `useMemoized(TextEditingController.new)`? → All three are forbidden; see [screen-state-view.md][screen-state-view] and [flutter-conventions.md][flutter-conventions]

## Attribution

Built on [utopia_hooks](https://pub.dev/packages/utopia_hooks) by UtopiaSoftware.
