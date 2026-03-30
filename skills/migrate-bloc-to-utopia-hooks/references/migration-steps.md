---
title: Step-by-Step Migration Checklist
impact: HIGH
tags: migration, checklist, step-by-step, screen, convert, refactor
---

# Step-by-Step: Migrating a Screen from BLoC to utopia_hooks

Migrate screen-by-screen, not file-by-file. Each screen fully migrated before moving to the next.

---

## Step 0: Pre-Migration Assessment

Before touching code:

```
□ Identify the Cubit/Bloc class and its state class
□ List all methods (Cubit) or event handlers (Bloc)
□ Identify BlocProvider scope — global (app root) or local (screen)?
□ If global → migrate to _providers first (see global-state-migration.md)
□ If this Cubit depends on ANOTHER Cubit → migrate that one first
□ List all BlocListeners — what side effects do they perform?
```

---

## Step 1: Rename + delete files

Do this FIRST, before writing any code.

**Rename:**
```
lib/cubit/task_list_cubit.dart  →  lib/state/task_list_state.dart
lib/bloc/auth_bloc.dart         →  lib/state/auth_state.dart
```

**Delete immediately:**
```
lib/cubit/task_list_state.dart   ← old Freezed/part state file
lib/bloc/auth_event.dart         ← event classes — replaced by callbacks
lib/bloc/auth_state.dart         ← old state — merged into renamed bloc file
```

**Update barrel exports:**
```dart
// Before: export 'cubit/task_list_cubit.dart';
// After:  export 'state/task_list_state.dart';
```

---

## Step 2: Design the State class

Write the State class in the renamed file. Rules — **ALL mandatory, no exceptions:**

- **No `copyWith()`** — hooks use individual `useState` per field, not immutable state objects
- **No `extends Equatable`** — hooks don't need equality checks, no `props` getter
- **No `Status` enum** — hooks have built-in state machines (see below)
- **No `part` / `part of`** — everything in one file
- Nullable `T?` for data fields (null = not loaded yet)
- `bool` flags for in-progress actions
- One `void Function()` per user action
- `MutableValue<T>` for user-controlled selections (filter, tab)
- No widget imports, no BuildContext

**How Status maps to hooks (don't recreate it):**

| BLoC Status | Hook equivalent (built-in) | State class exposes |
|---|---|---|
| `idle` / `initial` | `ComputedStateValue.notInitialized` | `T? data` (null) |
| `loading` / `inProgress` | `ComputedStateValue.inProgress` | `bool isLoading` (via `!state.isInitialized`) |
| `success` / `loaded` | `ComputedStateValue.ready(T)` | `T? data` (non-null via `.valueOrNull`) |
| `failure` / `error` | error in `runSimple` callback | not in state — handled in hook |
| upload in progress | `submitState.inProgress` | `bool isSaving` |

**From Freezed union:**
```dart
// ❌ BLoC
@freezed
class TaskListState with _$TaskListState {
  const factory TaskListState.loading() = _Loading;
  const factory TaskListState.loaded(List<Task> tasks, {bool isDeleting}) = _Loaded;
  const factory TaskListState.error(String message) = _Error;
}

// ✅ Hooks — flat, no union, no copyWith, no Equatable
class TaskListPageState {
  final IList<Task>? tasks;        // null = loading
  final bool isDeleting;
  final void Function(TaskId) onDeletePressed;
  final void Function() onRefreshPressed;

  const TaskListPageState({
    required this.tasks,
    required this.isDeleting,
    required this.onDeletePressed,
    required this.onRefreshPressed,
  });
}
```

---

## Step 3: Migrate Cubit methods → hook body

| Cubit pattern | Hook equivalent |
|---|---|
| Constructor (initial load) | `useAutoComputedState(() => ...)` |
| Method that fetches data | `useAutoComputedState` with keys |
| Method that submits/mutates | `useSubmitState` + `runSimple` |
| `emit(state.copyWith(...))` | `useState` + `.value = ...` |
| Method that toggles a flag | `useState<bool>` + `.value = !.value` |
| Timer / periodic | `usePeriodicalSignal` |
| Stream subscription | `useMemoizedStream` |
| Cubit depends on another Cubit | `useProvided<XState>()` |

```dart
TaskListPageState useTaskListPageState() {
  final repo = useInjected<TaskRepository>();

  // Constructor + loadTasks() → auto-load on mount
  final tasksState = useAutoComputedState(() async => (await repo.getAll()).toIList());

  // deleteTask() → upload operation
  final deleteState = useSubmitState();
  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async {
      await repo.delete(id);
      await tasksState.refresh();
    },
  );

  return TaskListPageState(
    tasks: tasksState.valueOrNull,
    isDeleting: deleteState.inProgress,
    onDeletePressed: deleteTask,
    onRefreshPressed: () => tasksState.refresh(),
  );
}
```

---

## Step 4: Migrate BlocBuilder → View

```dart
// ❌ BLoC
BlocBuilder<TaskListCubit, TaskListState>(
  builder: (context, state) {
    return state.when(
      loading: () => const CircularProgressIndicator(),
      loaded: (tasks, isDeleting) => ListView(...),
      error: (msg) => Text(msg),
    );
  },
)

// ✅ Hooks — StatelessWidget receives state
class TaskListPageView extends StatelessWidget {
  final TaskListPageState state;
  const TaskListPageView({required this.state});

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasks;
    if (tasks == null) return const CrazyLoader();
    return ListView(
      children: tasks.map((t) => Dismissible(
        key: ValueKey(t.id),
        onDismissed: (_) => state.onDeletePressed(t.id),
        child: ListTile(title: Text(t.title)),
      )).toList(),
    );
  }
}
```

Changes:
- `context.read<XCubit>().method()` → `state.onXPressed()`
- `state.when(loading:, loaded:, ...)` → null checks on data fields
- All data comes from `state.` — no `context` access for business logic

---

## Step 5: Migrate BlocListener → useEffect or callback

```dart
// ❌ BLoC
BlocListener<TaskListCubit, TaskListState>(
  listener: (context, state) {
    if (state is _Error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
    }
  },
)

// ✅ Hooks — error handling in runSimple, no BlocListener needed
deleteState.runSimple<void, AppError>(
  submit: () async => repo.delete(id),
  mapError: (e) => e is AppError ? e : null,
  afterKnownError: (e) => showError(e.message),  // injected from Page
);
```

For navigation side effects:
```dart
useEffect(() {
  if (someCondition) navigateToX();
  return null;
}, [someCondition]);
```

---

## Step 6: Wire up the Page

```dart
// ❌ BLoC
class TaskListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskListCubit(context.read<TaskRepository>()),
      child: BlocConsumer<TaskListCubit, TaskListState>(...),
    );
  }
}

// ✅ Hooks — minimal coordinator
class TaskListPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useTaskListPageState();
    return TaskListPageView(state: state);
  }
}
```

---

## Step 7: Update pubspec.yaml

**Remove (all of these):**
```yaml
  bloc:                # remove
  bloc_concurrency:    # remove
  flutter_bloc:        # remove
  hydrated_bloc:       # remove

# dev_dependencies:
  bloc_lint:           # remove
  bloc_test:           # remove
  mockingjay:          # remove (BLoC-specific)
```

**Add:**
```yaml
  utopia_hooks:        # add (or utopia_arch if using DI/navigation/error handling)
```

Keep `equatable` if model classes use it. Keep `mocktail` for mocking.

---

## Step 8: Compilation gate

**These MUST pass before committing. If they fail, fix first.**

```bash
flutter pub get          # dependencies resolve
dart analyze             # zero errors, zero warnings
```

If `dart analyze` fails, fix the issues. Common post-migration errors:
- Missing imports (`import 'package:utopia_hooks/utopia_hooks.dart'`)
- Old state file references (update barrel exports)
- Unused imports (`flutter_bloc` still imported somewhere)

---

## Step 9: Cleanup

```
□ Verify: grep -r "flutter_bloc\|package:bloc/" lib/ returns zero results
□ Verify: no files named *_bloc.dart or *_cubit.dart in lib/
□ Verify: no copyWith() methods in state classes
□ Verify: no extends Equatable on state classes
□ Remove .freezed.dart generated files for deleted Freezed states
□ Run build_runner if project has other generated code
```

---

## Step 10: Verify

```
□ App compiles without errors
□ Screen loads data correctly
□ User actions (save, delete, etc.) work
□ Error states show appropriate feedback
□ Navigation works (back, forward, deep links)
```

### Unit test with SimpleHookContext
```dart
test('tasks load on init', () async {
  final context = SimpleHookContext(() => useTaskListPageState());
  expect(context().tasks, isNull);
  await context.waitUntil((s) => s.tasks != null);
  expect(context().tasks, isNotEmpty);
});
```

---

## Migration Order (for a full codebase)

1. **Global state first** — Migrate Cubits/Blocs at app root to `_providers`
2. **Leaf screens** — Screens with no children or dependencies
3. **Feature modules** — Group related screens and migrate together
4. **Shared Cubits** — already migrated to global state in step 1
5. **pubspec + compilation gate** — only after ALL screens are migrated

**Never** leave a screen half-migrated (mixing BLoC and hooks in one screen).

## Related

- [bloc-to-hooks-mapping.md](./bloc-to-hooks-mapping.md) — pattern-by-pattern mapping
- [global-state-migration.md](./global-state-migration.md) — provider tree migration
- `../utopia-hooks/references/page-state-view.md` — Page/State/View pattern
- `../utopia-hooks/references/testing.md` — SimpleHookContext testing
