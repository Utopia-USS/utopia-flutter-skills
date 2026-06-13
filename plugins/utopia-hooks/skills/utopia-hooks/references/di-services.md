---
title: Dependency Injection & Services
impact: MEDIUM
tags: di, injection, services, useInjected, utopia_injector, Injector, get_it, bridge
---

# Skill: Dependency Injection & Services

Services are accessed in state hooks via `useInjected<T>()` - a one-line hook you declare over
whatever DI the project already has. This skill does not care which container that is or how it
is set up; this file covers only the hook-side wiring (utopia_injector, get_it, or
BuildContext-based DI underneath).

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
  final service = useInjected<TaskService>(); // resolved from the provided Injector
  // ...
}
```

## When to Use

- Accessing Firebase services, API clients, or data transformation services in a screen state hook
- Accessing services in a global state hook
- Declaring `useInjected` in a project that doesn't have it yet

---

## Services Are Stateless Infrastructure Wrappers

Services own all contact with infrastructure (Firebase, gRPC, SharedPreferences, file system, HTTP). Hooks own all state. This means:

- A service exposes methods that return `Stream<T>`, `Future<T>`, or synchronous `T` - it never holds mutable state
- A hook calls `useInjected<Service>()` and passes the service's streams/futures to `useMemoizedStream`, `useAutoComputedState`, `useSubmitState`, etc.
- The hook never knows *how* data is stored or fetched - only *what* to ask for

```dart
// ❌ Hook calls infrastructure directly
ProfileState useProfileState() {
  final dataState = useAutoComputedState(
    () async => database.collection('profiles').doc(userId).get(),  // infra in hook
  );
  // ...
}

// ✅ Service wraps infrastructure, hook calls service
ProfileState useProfileState() {
  final profileService = useInjected<ProfileService>();
  final dataState = useAutoComputedState(
    () async => profileService.load(userId),  // hook doesn't know how/where
  );
  // ...
}
```

---

## Declaring useInjected

`useInjected` is a one-liner over the project's container, declared once:

```dart
T useInjected<T>() => useProvided<Injector>().get();
```

With utopia_injector, the `Injector` is built before `runApp` and registered as the first
`_providers` entry, so everything below it may `useInjected`:

```dart
const _providers = {
  Injector: AppInjector.use,
  AuthState: useAuthState,
  // ...
};
```

(`utopia_arch`, if the project uses it, ships exactly this one-liner ready-made - keep only
one `useInjected` in scope. Container setup, registration variants, and layering are the DI
package's own concern, not this skill's.)

**Where `useInjected` is allowed:**

| Location | Allowed? |
|----------|----------|
| Screen state hook (`useXScreenState`) | ✅ Yes |
| Global state hook (`useXState` in `_providers`) | ✅ Yes |
| View (`StatelessWidget.build`) | ❌ No - not a hook context, and Views stay service-free |
| Screen widget (`HookWidget.build`) | ❌ No - Screen is pure wiring; all services go in the state hook |
| Custom hooks | ✅ Yes, if called from an allowed hook |

---

## Fallback: Bridging Non-Utopia DI

If the project already uses another container, write your own `useInjected` bridge instead of
importing `utopia_arch`'s. Keep exactly one `useInjected` in scope.

### get_it

```dart
// hooks/use_injected.dart
T useInjected<T extends Object>() => GetIt.I<T>();
```

Services are registered as usual in get_it:

```dart
final getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerSingleton(TaskDataService());
  getIt.registerSingleton(TaskFirebaseService());
  getIt.registerFactory(() => TaskApiService(getIt<GrpcClientService>()));
}
```

### package:provider and other BuildContext-based DI

`useProvided<T>()` does **not** read `package:provider` - it only reads utopia's own provider
container (`HookProviderContainerWidget`, `ValueProvider`). To consume services provided with
`package:provider`, either bridge through the BuildContext:

```dart
// hooks/use_injected.dart
T useInjected<T>() => Provider.of<T>(useBuildContext(), listen: false);
```

or re-provide the value into the utopia container so `useProvided<T>()` works:

```dart
ValueProvider(apiClient, child: /* subtree where useProvided<ApiClient>() resolves */);
```

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

---

## Reverse Bridge: Exposing Live Hook State to Services

When a service method needs the current value of hook state (e.g. current user, locale), register
a `ServiceContext` - a `MutableInjector` into which a global state hook publishes a
`useValueWrapper`-wrapped value; services then resolve that `Value<T>` at call time, not boot time.
Reach for this only when the service genuinely requires live hook state; keep the published set
value-only to avoid inverting the architecture.

```dart
// Inside useAuthState() - publishes live user to ServiceContext
final serviceContext = useInjected<ServiceContext>();
final userValue = useValueWrapper(user); // stable wrapper, fresh .value each build
useImmediateEffect(() {
  serviceContext.register.override.instance<Value<User?>>(userValue);
}, []);
```

---

## Common Pitfalls

- **Accessing infrastructure directly in hooks** - `FirebaseDatabase.instance.ref(...)`, `SharedPreferences.getInstance()`, raw HTTP clients in a hook body. Always wrap in a service and use `useInjected<Service>()`.
- **Injecting in View or Screen** - `View extends StatelessWidget` cannot call hooks; `Screen` is pure wiring and must not call `useInjected`. All services go in the state hook.
- **`useInjected` fails at runtime** - the service isn't registered in the container, or the `Injector` entry is missing from `_providers` (then it fails on `useProvided<Injector>` instead).
- **Using `useInjected` inside a regular function** - only valid inside a hook build context; don't call it inside a `Future` or callback body. Resolve the service during build, use it in the callback.
- **One service doing too much** - split large services by type (Firebase vs API vs Data); keeps responsibilities clear and tests isolated.

## Related Skills

- [screen-state-view.md](./screen-state-view.md) - useInjected in the State hook
- [global-state.md](./global-state.md) - useInjected in global state hooks, ordered _providers map
- [async-patterns.md](./async-patterns.md) - calling service methods via useSubmitState
- [testing.md](./testing.md) - test Injector with register.instance / register.override mocks
