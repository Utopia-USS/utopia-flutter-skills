---
title: Screen / State / View Pattern
impact: CRITICAL
tags: architecture, screen, pattern, widget, hooks, navigation
---

# Skill: Screen / State / View Pattern

Every screen in a utopia_hooks app consists of exactly three files: Screen, State, and View.
This separation ensures logic never bleeds into UI and UI never bleeds into logic.

- **Screen** — `HookWidget`, pure coordinator. Reads `BuildContext`, builds navigation/dialog
  callbacks, calls exactly one hook (`useXScreenState`), returns the View.
- **State** — plain data class + hook function. All logic, services, async, and derived values
  live in the hook. No widgets, no `BuildContext`.
- **View** — `StatelessWidget`, pure UI. Receives `state` and nothing else. No hooks.

## Quick Pattern

**Incorrect (logic in widget):**
```dart
class TasksScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final tasks = useProvided<TasksState>().tasks;
    final service = useInjected<TaskService>();
    final isLoading = useState(false);

    Future<void> deleteTask(TaskId id) async {
      isLoading.value = true;
      await service.delete(id);
      isLoading.value = false;
    }

    return ListView(
      children: tasks?.map((t) => ListTile(
        title: Text(t.title),
        onLongPress: () => deleteTask(t.id),
      )).toList() ?? [],
    );
  }
}
```

**Correct (Screen + State + View):**
```dart
// tasks_screen.dart
class TasksScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTasksScreenState(
      navigateToDetail: (id) => Navigator.of(context).pushNamed('/task', arguments: id),
    );
    return TasksScreenView(state: state);
  }
}

// state/tasks_screen_state.dart
class TasksScreenState {
  final IList<Task>? tasks;           // null = loading
  final bool isDeleting;
  final void Function(TaskId) onTaskTapped;
  final void Function(TaskId) onDeletePressed;

  const TasksScreenState({
    required this.tasks,
    required this.isDeleting,
    required this.onTaskTapped,
    required this.onDeletePressed,
  });
}

TasksScreenState useTasksScreenState({
  required void Function(TaskId) navigateToDetail,
}) {
  final service = useInjected<TaskService>();
  final tasksState = useProvided<TasksState>();
  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async => service.delete(id),
  );

  return TasksScreenState(
    tasks: tasksState.tasks,
    isDeleting: deleteState.inProgress,
    onTaskTapped: navigateToDetail,
    onDeletePressed: deleteTask,
  );
}

// view/tasks_screen_view.dart
class TasksScreenView extends StatelessWidget {
  final TasksScreenState state;
  const TasksScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasks;
    if (tasks == null) return const CrazyLoader();
    return ListView(
      children: tasks.map(_buildTask).toList(),
    );
  }

  Widget _buildTask(Task task) {
    return ListTile(
      title: Text(task.title),
      onTap: () => state.onTaskTapped(task.id),
      onLongPress: () => state.onDeletePressed(task.id),
    );
  }
}
```

## When to Use

- Building any new screen or route
- Adding a feature to an existing screen
- Reviewing code for architecture violations
- Replacing a `StatefulWidget` with hooks

## File Naming

| Role | File | Class |
|------|------|-------|
| Screen | `feature_screen.dart` | `FeatureScreen extends HookWidget` |
| State | `state/feature_screen_state.dart` | `FeatureScreenState` + `useFeatureScreenState()` |
| View | `view/feature_screen_view.dart` | `FeatureScreenView extends StatelessWidget` |

## Screen = pure wiring

The Screen is a coordinator, not a logic host. Its `build()` may:

- Read from `BuildContext`: `Navigator.of(context)`, `context.push(...)`, `MediaQuery.of(context)`,
  `context.routeArgs<T>()` (utopia_arch), `context.navigator` (utopia_arch), `XDialog.show(context)`
- Call **exactly one hook**: `useXScreenState(...)` with navigation/dialog callbacks built inline
- Return `XScreenView(state: state)` — nothing else

The Screen **must not** call:

- `useInjected<T>()` — services belong in the state hook
- `useProvided<T>()` — global state belongs in the state hook (including `useProvided<NavigatorKey>` — see below)
- `useEffect`, `useStreamSubscription`, `useAutoComputedState`, `useSubmitState` — effects belong in the state hook
- `useState`, `useMemoized` — local state belongs in the state hook

Everything the Screen needs (services, state, effects) is encapsulated by the single `useXScreenState(...)` call.

### Navigation flows Screen → State → View as callbacks

Navigation is built **in the Screen** from `BuildContext` and passed to the state hook as callback
parameters. The state hook stores them as fields on the State class. The View calls them.

```dart
// ✅ CORRECT — Screen builds nav from context, hook receives callbacks
class HabitDetailsScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useHabitDetailsScreenState(
      habit: habit,
      navigateToEdit: () async => EditHabitScreen.show(context, habit),
      navigateToPaywall: () => Navigator.of(context).pushNamed('/paywall'),
    );
    return HabitDetailsScreenView(state: state);
  }
}

HabitDetailsScreenState useHabitDetailsScreenState({
  required Habit habit,
  required Future<Habit?> Function() navigateToEdit,
  required void Function() navigateToPaywall,
}) { /* ... */ }
```

```dart
// ❌ FORBIDDEN — injecting navigation into the state hook
HabitDetailsScreenState useHabitDetailsScreenState({required Habit habit}) {
  final navigatorKey = useProvided<NavigatorKey>();   // ❌ NEVER
  final router = useInjected<AppRouter>();             // ❌ NEVER
  // ...
}
```

**Never use `useProvided<NavigatorKey>` or `useInjected<AppRouter>` anywhere.** The state hook
receives navigation as `void Function()` / `Future<T?> Function()` parameters. The Screen closes
over `BuildContext` from `build()` and builds those callbacks.

## Widget Callback Policy

When a sub-widget exposes callbacks (`onTap`, `onFontSizeTap`, `onSendTapped`, `onEdit`), classify
each callback before wiring it:

1. **Business callback** — triggers state logic, async work, navigation, or mutates domain data.
   → Must be a **field on the `State` class**. The state hook builds it (opening dialogs via the
   Screen-injected callback if needed). View passes it through: `MorePopupMenu(onLoginTapped: state.onLoginTapped)`.
2. **Widget-internal callback** — affects only the sub-widget's own local UI state (expand/collapse,
   focus, hover, per-tile animation).
   → Belongs in a **widget-level hook** on the sub-widget itself. See [composable-hooks.md](./composable-hooks.md) Pattern 1.

**Never build business callbacks as closures in the View.**

```dart
// ❌ Closure in View — couples View to service and BuildContext
class ItemScreenView extends StatelessWidget {
  Widget build(BuildContext context) {
    return ReplyBox(
      onSendTapped: (text) {                         // ← business logic in View
        if (!state.isLoggedIn) {
          Navigator.of(context).pushNamed('/login');
          return;
        }
        state.onReplyWith(text);
      },
    );
  }
}

// ✅ Callback is a field on State — View passes it through
class ItemScreenView extends StatelessWidget {
  Widget build(BuildContext context) {
    return ReplyBox(onSendTapped: state.onSendReply);
  }
}
```

## Step-by-Step: Creating a new screen

### 1. State class — define your data contract

```dart
class ProductScreenState {
  // Data displayed by the View
  final Product? product;           // null = loading
  final bool isSaving;

  // Mutable fields (user-editable) — View reads AND writes
  final MutableFieldState nameField;

  // Callbacks — View calls these, Screen provides implementations
  final void Function() onSavePressed;
  final void Function() onDeletePressed;

  const ProductScreenState({
    required this.product,
    required this.isSaving,
    required this.nameField,
    required this.onSavePressed,
    required this.onDeletePressed,
  });

  bool get canSave => product != null && nameField.value.isNotEmpty;
}
```

Rules for the State class:
- **Immutable data** fields (final, no setters)
- **`MutableValue<T>` / `MutableFieldState`** for fields the View needs to read AND update
- **`void Function()` callbacks** for user actions — navigation/dialogs passed from Screen
- No widget imports, no `BuildContext`, no Flutter dependencies

### 2. State hook — implement logic

```dart
ProductScreenState useProductScreenState({
  required String productId,
  required void Function() navigateBack,
  required void Function(String message) showErrorSnackbar,
}) {
  // Services
  final service = useInjected<ProductService>();

  // Local state
  final nameField = useFieldState();
  final product = useAutoComputedState(() => service.load(productId));
  final saveState = useSubmitState();

  // Sync name field when product loads
  useEffect(() {
    if (product.valueOrNull != null) nameField.value = product.value.name;
    return null;
  }, [product.valueOrNull?.name]);

  void save() => saveState.runSimple<void, AppError>(
    submit: () async => service.update(productId, name: nameField.value),
    afterSubmit: (_) => navigateBack(),
    mapError: (e) => e is AppError ? e : null,
    afterKnownError: (e) => showErrorSnackbar('Failed to save: ${e.message}'),
  );

  return ProductScreenState(
    product: product.valueOrNull,
    isSaving: saveState.inProgress,
    nameField: nameField,
    onSavePressed: save,
    onDeletePressed: () {/* ... */},
  );
}
```

### 3. Screen — wire navigation and dialogs

```dart
@RoutePage()
class ProductScreen extends HookWidget {
  final String productId;
  const ProductScreen({required this.productId});

  @override
  Widget build(BuildContext context) {
    final state = useProductScreenState(
      productId: productId,
      navigateBack: Navigator.of(context).pop,
      showErrorSnackbar: (msg) => CrazyInfoSnackbar.show(context, msg),
    );
    return ProductScreenView(state: state);
  }
}
```

### 4. View — pure UI

```dart
class ProductScreenView extends StatelessWidget {
  final ProductScreenState state;
  const ProductScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.product == null) return const CrazyLoader();

    return CrazyPage(
      title: const Text("Edit Product"),
      sliversBuilder: (_, __) => [
        SliverToBoxAdapter(child: _buildForm()),
        SliverToBoxAdapter(child: _buildButtons()),
      ],
    );
  }

  Widget _buildForm() {
    return TextEditingControllerWrapper(
      text: state.nameField,
      builder: (controller) => TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    );
  }

  Widget _buildButtons() {
    return CrazySquashButton(
      onTap: state.onSavePressed,
      enabled: state.canSave,
      child: const Text("Save"),
    );
  }
}
```

View rules:
- `extends StatelessWidget`
- Receives `final XScreenState state` — nothing else
- No hooks, no `useProvided`, no `useInjected`
- No `BuildContext` for business logic (only for UI utilities like `MediaQuery`)
- Private `_buildXxx` helper methods for long `build()` methods
- Business callbacks are fields on `state` — never built inline as closures

## Common Pitfalls

- **`useProvided` / `useInjected` in View** — View receives everything it needs via State; it never reaches for global dependencies
- **Widget imports in State class** — if `state/feature_screen_state.dart` imports `package:flutter/material.dart` for anything other than `Color`, it's a red flag
- **Navigation logic in State hook** — navigation callbacks are injected from Screen, not called directly
- **`useProvided<NavigatorKey>` / `useInjected<AppRouter>`** — never. Navigation is a callback, not an injected dependency
- **Multiple hooks in Screen** — Screen calls `useXScreenState` once. Anything else belongs in the state hook
- **Business callbacks built as View closures** — closures in View couple UI to services; callbacks go on the State class
- **Shared State class across screens** — each screen has its own State class; don't reuse across routes

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useState, useMemoized, useEffect inside the State hook
- [global-state.md](./global-state.md) — useProvided to access app-wide state
- [async-patterns.md](./async-patterns.md) — useSubmitState, useAutoComputedState in the State hook
- [di-services.md](./di-services.md) — useInjected to access services
- [composable-hooks.md](./composable-hooks.md) — widget-level hooks for local sub-widget state
- [flutter-conventions.md](./flutter-conventions.md) — TextEditingController/FocusNode canonical wrappers
