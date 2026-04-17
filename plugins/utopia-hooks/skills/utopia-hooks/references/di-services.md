---
title: Dependency Injection & Services
impact: MEDIUM
tags: di, injection, services, useInjected, bridge, get_it, provider
---

# Skill: Dependency Injection & Services

Services are accessed via a `useInjected<T>()` bridge hook that wraps your project's existing DI.
This decouples screens from concrete implementations and enables testability.

## Quick Pattern

**Incorrect (direct instantiation):**
```dart
TasksScreenState useTasksScreenState() {
  final service = TaskService(apiClient: ApiClient()); // tight coupling, not testable
  // ...
}
```

**Correct (injected service):**
```dart
TasksScreenState useTasksScreenState() {
  final service = useInjected<TaskService>(); // resolved via DI bridge
  // ...
}
```

## When to Use

- Accessing Firebase services, API clients, or data transformation services in a screen state hook
- Accessing services in a global state hook
- Adding a new service to the app
- Writing a service that depends on other services

---

## Services Are Stateless Infrastructure Wrappers

Services own all contact with infrastructure (Firebase, gRPC, SharedPreferences, file system, HTTP). Hooks own all state. This means:

- A service exposes methods that return `Stream<T>`, `Future<T>`, or synchronous `T` — it never holds mutable state
- A hook calls `useInjected<Service>()` and passes the service's streams/futures to `useMemoizedStream`, `useAutoComputedState`, `useSubmitState`, etc.
- The hook never knows *how* data is stored or fetched — only *what* to ask for

```dart
// ❌ Hook calls infrastructure directly
ProfileState useProfileState() {
  final data = useAutoComputedState(
    () async => database.collection('profiles').doc(userId).get(),  // infra in hook
  );
  // ...
}

// ✅ Service wraps infrastructure, hook calls service
ProfileState useProfileState() {
  final profileService = useInjected<ProfileService>();
  final data = useAutoComputedState(
    () async => profileService.load(userId),  // hook doesn't know how/where
  );
  // ...
}
```

---

## Service Types

| Suffix | Responsibility | I/O | Returns |
|--------|----------------|-----|---------|
| `FirebaseService` | Firestore CRUD | Stream / Future | Stream for reads, Future for writes |
| `ApiService` | gRPC / REST calls | Future | Future |
| `DataService` | Pure transformations | None | Synchronous |
| `AssetService` | Local asset loading | Future | Future |

```dart
// FirebaseService — Firestore streams
class TaskFirebaseService extends FirestoreRepositoryService {
  Stream<IList<Task>> streamTasks(String userId) =>
      streamList('users/$userId/tasks', Task.fromJson);

  Future<void> save(Task task) => set('users/${task.userId}/tasks/${task.id}', task.toJson());
}

// ApiService — gRPC call
class TaskApiService {
  final GrpcClient _grpc;
  TaskApiService(this._grpc);

  Future<TaskResponse> createTask(CreateTaskRequest req) =>
      _grpc.execute((client) => client.createTask(req));
}

// DataService — pure, no I/O
class TaskDataService {
  IList<Task> filterByStatus(IList<Task> tasks, TaskStatus status) =>
      tasks.where((it) => it.status == status).toIList();

  TaskSummary buildSummary(IList<Task> tasks) =>
      TaskSummary(total: tasks.length, done: tasks.count((it) => it.isDone));
}
```

---

## Creating the useInjected Bridge Hook

`useInjected<T>()` is not a framework class — it's a one-liner you write yourself to bridge
your project's existing DI into hook context. Pick the variant matching your DI:

### For get_it (most common)

```dart
// hooks/use_injected.dart
T useInjected<T extends Object>() => GetIt.I<T>();
```

Services are registered as usual in get_it:
```dart
// di/injection.dart
final getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerSingleton(TaskDataService());
  getIt.registerSingleton(TaskFirebaseService());
  getIt.registerFactory(() => TaskApiService(getIt<GrpcClient>()));
}
```

### For a simple service locator

```dart
// hooks/use_injected.dart
T useInjected<T>() => ServiceLocator.instance.get<T>();
```

### For BuildContext-based DI (provider, etc.)

If your services are provided via `Provider` in the widget tree, you can use
`useProvided<T>()` directly — no bridge needed.

---

## Accessing Services via useInjected

```dart
// In any state hook (screen or global)
TasksScreenState useTasksScreenState() {
  final taskService = useInjected<TaskService>();
  final analyticsService = useInjected<AnalyticsService>();

  final deleteState = useSubmitState();

  void deleteTask(TaskId id) => deleteState.runSimple<void, Never>(
    submit: () async {
      await taskService.delete(id);
      analyticsService.track('task_deleted');
    },
  );

  // ...
}
```

**Where `useInjected` is allowed:**

| Location | Allowed? |
|----------|----------|
| Screen state hook (`useXScreenState`) | ✅ Yes |
| Global state hook (`useXState` in `_providers`) | ✅ Yes |
| View (`StatelessWidget.build`) | ❌ No — not a hook context |
| Screen widget (`HookWidget.build`) | ❌ No — Screen is pure wiring; all services go in the state hook |
| Custom hooks | ✅ Yes, if called from an allowed hook |

---

## Common Pitfalls

- **Accessing infrastructure directly in hooks** — `FirebaseDatabase.instance.ref(...)`, `SharedPreferences.getInstance()`, raw HTTP clients in a hook body. Always wrap in a service and use `useInjected<Service>()`. The hook should never know *how* data is stored or fetched — only *what* to ask for.
- **Injecting in View or Screen** — `View extends StatelessWidget` cannot call hooks; `Screen` is pure wiring and must not call `useInjected`. All services go in the state hook.
- **Ensure your DI has the type registered** — if `useInjected<T>()` throws at runtime, the service isn't registered in your DI container
- **Using `useInjected` inside a regular function** — only valid inside a hook build context; don't call it inside a `Future` or callback body
- **One service doing too much** — split large services by type (Firebase vs API vs Data); keeps responsibilities clear and tests isolated

## Related Skills

- [screen-state-view.md](./screen-state-view.md) — useInjected in the State hook
- [global-state.md](./global-state.md) — useInjected in global state hooks
- [async-patterns.md](./async-patterns.md) — calling service methods via useSubmitState
