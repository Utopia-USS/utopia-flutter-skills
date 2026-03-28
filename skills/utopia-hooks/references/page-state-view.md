---
title: Page / State / View Pattern
impact: CRITICAL
tags: architecture, screen, pattern, widget, hooks
---

# Skill: Page / State / View Pattern

Every screen in a utopia_hooks app consists of exactly three files: Page, State, and View.
This separation ensures logic never bleeds into UI and UI never bleeds into logic.

## Quick Pattern

**Incorrect (logic in widget):**
```dart
class TasksPage extends HookWidget {
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

**Correct (Page + State + View):**
```dart
// tasks_page.dart
class TasksPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTasksPageState(
      navigateToDetail: (id) => context.router.push(TaskDetailRoute(id: id)),
    );
    return TasksPageView(state: state);
  }
}

// state/tasks_page_state.dart
class TasksPageState {
  final IList<Task>? tasks;           // null = loading
  final bool isDeleting;
  final void Function(TaskId) onTaskTapped;
  final void Function(TaskId) onDeletePressed;

  const TasksPageState({
    required this.tasks,
    required this.isDeleting,
    required this.onTaskTapped,
    required this.onDeletePressed,
  });
}

TasksPageState useTasksPageState({
  required void Function(TaskId) navigateToDetail,
}) {
  final service = useInjected<TaskService>();
  final tasksState = useProvided<TasksState>();
  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async => service.delete(id),
  );

  return TasksPageState(
    tasks: tasksState.tasks,
    isDeleting: deleteState.inProgress,
    onTaskTapped: navigateToDetail,
    onDeletePressed: deleteTask,
  );
}

// view/tasks_page_view.dart
class TasksPageView extends StatelessWidget {
  final TasksPageState state;
  const TasksPageView({required this.state});

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
| Page | `feature_page.dart` | `FeaturePage extends HookWidget` |
| State | `state/feature_page_state.dart` | `FeaturePageState` + `useFeaturePageState()` |
| View | `view/feature_page_view.dart` | `FeaturePageView extends StatelessWidget` |

## Step-by-Step: Creating a new screen

### 1. State class — define your data contract

```dart
class ProductPageState {
  // Data displayed by the View
  final Product? product;           // null = loading
  final bool isSaving;

  // Mutable fields (user-editable) — View reads AND writes
  final MutableValue<String> nameState;

  // Callbacks — View calls these, Page provides implementations
  final void Function() onSavePressed;
  final void Function() onDeletePressed;

  const ProductPageState({
    required this.product,
    required this.isSaving,
    required this.nameState,
    required this.onSavePressed,
    required this.onDeletePressed,
  });

  bool get canSave => product != null && nameState.value.isNotEmpty;
}
```

Rules for the State class:
- **Immutable data** fields (final, no setters)
- **MutableValue<T>** for fields the View needs to read AND update
- **void Function()** callbacks for user actions — navigation/dialogs passed from Page
- No widget imports, no BuildContext, no Flutter dependencies

### 2. State hook — implement logic

```dart
ProductPageState useProductPageState({
  required String productId,
  required void Function() navigateBack,
  required void Function(String message) showErrorSnackbar,
}) {
  // Services
  final service = useInjected<ProductService>();

  // Local state
  final nameState = useState('');
  final product = useAutoComputedState(() => service.load(productId));
  final saveState = useSubmitState();

  // Sync name field when product loads
  useEffect(() {
    if (product.value != null) nameState.value = product.value!.name;
    return null;
  }, [product.value?.name]);

  void save() => saveState.runSimple<void, AppError>(
    submit: () async => service.update(productId, name: nameState.value),
    afterSubmit: (_) => navigateBack(),
    mapError: (e) => e is AppError ? e : null,
    afterKnownError: (e) => showErrorSnackbar('Failed to save: ${e.message}'),
  );

  return ProductPageState(
    product: product.valueOrNull,
    isSaving: saveState.inProgress,
    nameState: nameState,
    onSavePressed: save,
    onDeletePressed: () {/* ... */},
  );
}
```

### 3. Page — wire navigation and dialogs

```dart
@RoutePage()
class ProductPage extends HookWidget {
  final String productId;
  const ProductPage({required this.productId});

  @override
  Widget build(BuildContext context) {
    final state = useProductPageState(
      productId: productId,
      navigateBack: context.router.pop,
      showErrorSnackbar: (msg) => CrazyInfoSnackbar.show(context, msg),
    );
    return ProductPageView(state: state);
  }
}
```

Page rules:
- `extends HookWidget`
- Calls `useXPageState(...)` once
- Passes navigation, dialogs, and context-dependent callbacks
- Returns `XPageView(state: state)` — nothing else

### 4. View — pure UI

```dart
class ProductPageView extends StatelessWidget {
  final ProductPageState state;
  const ProductPageView({required this.state});

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
    return CrazyTextField(
      state: state.nameState,
      label: const Text("Name"),
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
- Receives `final XState state` — nothing else
- No hooks, no `useProvided`, no `useInjected`
- No `BuildContext` for business logic (only for UI utilities like `MediaQuery`)
- Private `_buildXxx` helper methods for long `build()` methods

## Common Pitfalls

- **useProvided / useInjected in View** — View receives everything it needs via State; it never reaches for global dependencies
- **Widget imports in State class** — if `state/feature_page_state.dart` imports `package:flutter/material.dart` for anything other than `Color`, it's a red flag
- **Navigation logic in State hook** — navigation callbacks are injected from Page, not called directly
- **Multiple useState scattered across Page** — all local state belongs in the State hook, not in the Page widget
- **Shared State class across screens** — each screen has its own State class; don't reuse across routes

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — useState, useMemoized, useEffect inside the State hook
- [global-state.md](./global-state.md) — useProvided to access app-wide state
- [async-patterns.md](./async-patterns.md) — useSubmitState, useAutoComputedState in the State hook
- [di-services.md](./di-services.md) — useInjected to access services
