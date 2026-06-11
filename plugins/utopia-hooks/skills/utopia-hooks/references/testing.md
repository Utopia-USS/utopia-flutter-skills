---
title: Testing Hooks
impact: HIGH
tags: testing, SimpleHookContext, SimpleHookProviderContainer, unit-test, hooks, mocking, Injector, get_it
---

# Skill: Testing Hooks

utopia_hooks provides two test utilities that let you test hook logic in isolation -
no widget tree, no `pumpWidget`, no `WidgetTester`. Tests are fast, synchronous-friendly,
and focus on the hook's behavior, not the UI.

| Tool | Use when |
|------|----------|
| `SimpleHookContext` | Testing a single hook or a screen state hook in isolation |
| `SimpleHookProviderContainer` | Testing global state hooks that use `useProvided` |

---

## Quick Pattern

**Incorrect (widget test for hook logic):**
```dart
testWidgets('saves task', (tester) async {
  await tester.pumpWidget(MaterialApp(home: TasksScreen()));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  expect(find.text('Saved!'), findsOneWidget); // testing UI, not logic
});
```

**Correct (hook unit test):**
```dart
test('save triggers service and navigates back', () async {
  var navigatedBack = false;
  final mockService = MockTaskService();
  when(mockService.save(any)).thenAnswer((_) async {});

  final context = SimpleHookContext(
    () => useTaskScreenState(navigateBack: () => navigatedBack = true),
    provided: {
      // useInjected<TaskService>() inside the hook resolves the mock
      Injector: Injector.build((register) => register.instance<TaskService>(mockService)),
    },
  );

  context().onSavePressed();
  await context.waitUntil((it) => !it.isSaving);

  expect(navigatedBack, true);
  verify(mockService.save(any)).called(1);
});
```

---

## Mocking Injected Services

State hooks resolve services with `useInjected<T>()`, which reads the provided `Injector`
(from `utopia_injector`, re-exported by `utopia_arch`). In tests, build a throwaway
`Injector` containing your mocks and pass it through the `provided` map - both
`SimpleHookContext` and `SimpleHookProviderContainer` accept one. Hooks that touch no
services (plain `useState` logic) don't need any of this.

### utopia_injector path (the default)

```dart
late MockTaskService mockService;
late Injector testInjector;

setUp(() {
  mockService = MockTaskService();
  testInjector = Injector.build((register) {
    register.instance<TaskService>(mockService);
    register.instance<AnalyticsService>(MockAnalyticsService());
  });
});

test('hook resolves mocks', () async {
  final context = SimpleHookContext(
    () => useTaskScreenState(navigateBack: () {}),
    provided: {Injector: testInjector},  // useInjected<TaskService>() returns mockService
  );
  // ...
  context.dispose();
});
```

Notes:
- `register.instance<TaskService>(mockService)` - the explicit type parameter matters;
  without it the mock is registered under its own runtime type (`MockTaskService`) and
  `useInjected<TaskService>()` throws `NotDefinedException`.
- To override a single service on top of a real composition root, build with a parent:
  `Injector.build((register) => register.instance<TaskService>(mock), parent: realInjector)` -
  lookups fall back to the parent for everything not overridden.
- A missing `Injector` in `provided` makes any `useInjected` call throw
  `ProvidedValueNotFoundException`.

### get_it path (non-utopia DI)

If the project resolves services through `get_it` (`GetIt.I<TaskService>()`), no `provided`
entry is needed - the registry is global. Register mocks in `setUp` and reset in `tearDown`:

```dart
setUp(() {
  GetIt.I.registerSingleton<TaskService>(MockTaskService());
});

tearDown(() async {
  await GetIt.I.reset();  // without this, mocks leak into the next test
});
```

---

## SimpleHookContext

Tests a single hook function. Automatically runs the hook on construction and after each state change.

### Basic usage

```dart
test('counter increments', () {
  final context = SimpleHookContext(() {
    final count = useState(0);
    return (value: count.value, increment: () => count.value++);
  });

  expect(context().value, 0);

  context().increment();
  expect(context().value, 1);
});
```

### API

```dart
// Create
final context = SimpleHookContext(
  () => useMyHook(param: value),  // hook function
);

// Access current value
context()          // calls context to get current state
context.value      // same, property form

// Manual rebuild (not usually needed - state changes trigger automatic rebuild)
context.rebuild()

// Wait for async state
await context.waitUntil((state) => state.isLoaded);

// Inject provided dependencies (for hooks that call useProvided / useInjected)
SimpleHookContext(
  () => useMyHook(),
  provided: {
    AuthState: AuthState(isInitialized: true, user: fakeUser),  // useProvided<AuthState>()
    Injector: Injector.build(                                   // useInjected<MyService>()
      (register) => register.instance<MyService>(mockService),
    ),
  },
)

// Cleanup
context.dispose()
```

### Testing async operations

```dart
test('loads product on init', () async {
  final mockService = MockProductService();
  when(mockService.load('123')).thenAnswer((_) async => Product(id: '123', name: 'Widget'));

  final context = SimpleHookContext(
    () => useProductScreenState(productId: '123', navigateBack: () {}),
    provided: {
      Injector: Injector.build((register) => register.instance<ProductService>(mockService)),
    },
  );

  // Initially loading
  expect(context().isLoading, true);

  // Wait for async load to complete
  await context.waitUntil((state) => !state.isLoading);
  expect(context().product?.name, 'Widget');
});
```

### Testing useEffect side effects

```dart
test('effect runs when key changes', () {
  var effectRunCount = 0;

  final context = SimpleHookContext(() {
    final id = useState('a');

    useEffect(() {
      effectRunCount++;
      return null;
    }, [id.value]);

    return id;
  });

  expect(effectRunCount, 1); // ran on mount

  context().value = 'b';
  expect(effectRunCount, 2); // ran on key change

  context().value = 'b';    // same value
  expect(effectRunCount, 2); // did not run
});
```

### Testing callbacks and navigation

```dart
test('onSavePressed calls service and navigates', () async {
  var navigatedBack = false;
  final mockService = MockItemService();
  when(mockService.load('item-1')).thenAnswer((_) async => testItem);
  when(mockService.save(any)).thenAnswer((_) async {});

  final context = SimpleHookContext(
    () => useItemScreenState(itemId: 'item-1', navigateBack: () => navigatedBack = true),
    provided: {
      Injector: Injector.build((register) => register.instance<ItemService>(mockService)),
    },
  );

  await context.waitUntil((s) => !s.isLoading);

  context().nameState.value = 'New Name';
  context().onSavePressed();

  await context.waitUntil((s) => !s.isSaving);
  expect(navigatedBack, true);
});
```

### Testing MutableValue fields

```dart
test('filter change updates displayed items', () async {
  final mockService = MockTaskService();
  when(mockService.loadTasks()).thenAnswer((_) async => testTasks); // 5 tasks, 3 active

  final context = SimpleHookContext(
    () => useTasksScreenState(navigateToDetail: (_) {}),
    provided: {
      Injector: Injector.build((register) => register.instance<TaskService>(mockService)),
    },
  );

  await context.waitUntil((it) => it.tasks != null);
  expect(context().tasks?.length, 5); // all tasks

  context().filter.value = FilterType.active;
  expect(context().tasks?.length, 3); // only active
});
```

---

## SimpleHookProviderContainer

Tests global state hooks and their interactions. Each entry in the map is a `useX`
hook registered by type - exactly mirrors the `_providers` map in the app root.

### Basic usage

```dart
test('auth state initializes', () async {
  final container = SimpleHookProviderContainer(
    {AuthState: useAuthState},
    provided: {
      // useAuthState calls useInjected<AuthService>() internally
      Injector: Injector.build((register) => register.instance<AuthService>(MockAuthService())),
    },
  );

  expect(container.get<AuthState>().isInitialized, false);
  await container.waitUntil<AuthState>((it) => it.isInitialized);
  expect(container.get<AuthState>().isLoggedIn, false);
});
```

### Testing state that depends on other state

```dart
test('courses state waits for auth', () async {
  final courseService = MockCourseService();
  when(courseService.loadCourses()).thenAnswer((_) async => [testCourse]);

  final container = SimpleHookProviderContainer(
    {
      AuthState: useAuthState,
      CoursesState: useCoursesState,  // internally calls useProvided<AuthState>()
    },
    provided: {
      Injector: Injector.build((register) {
        register.instance<AuthService>(MockAuthService());
        register.instance<CourseService>(courseService);
      }),
    },
  );

  // CoursesState won't initialize until AuthState.isInitialized
  expect(container.get<CoursesState>().isInitialized, false);

  await container.waitUntil<CoursesState>((it) => it.isInitialized);
  expect(container.get<CoursesState>().courses, isNotEmpty);
});
```

### Injecting external dependencies (provided map)

Use the `provided` map for values that come from outside the container: globals you want
to stub as plain values instead of registering as live hooks, and the `Injector` carrying
mocked services (see Mocking Injected Services above):

```dart
test('screen state hook uses provided auth', () async {
  final fakeUser = FakeUser(uid: 'user-123');
  final taskService = MockTaskService();
  when(taskService.loadTasks()).thenAnswer((_) async => [testTask]);

  final container = SimpleHookProviderContainer(
    {TasksState: useTasksState},
    provided: {
      AuthState: AuthState(isInitialized: true, user: fakeUser),
      Injector: Injector.build((register) => register.instance<TaskService>(taskService)),
    },
  );

  await container.waitUntil<TasksState>((it) => it.isInitialized);
  expect(container.get<TasksState>().tasks, isNotEmpty);
});
```

### Updating provided values at runtime

```dart
test('state updates when auth changes', () async {
  final profileService = MockProfileService();
  when(profileService.load(any)).thenAnswer((it) async => Profile(id: it.positionalArguments.first as String));

  final container = SimpleHookProviderContainer(
    {ProfileState: useProfileState},
    provided: {
      AuthState: AuthState(isInitialized: true, user: null),
      Injector: Injector.build((register) => register.instance<ProfileService>(profileService)),
    },
  );

  expect(container.get<ProfileState>().profile, isNull);

  // Simulate login
  container.setProvided<AuthState>(
    AuthState(isInitialized: true, user: FakeUser(uid: 'abc')),
  );

  await container.waitUntil<ProfileState>((it) => it.profile != null);
  expect(container.get<ProfileState>().profile?.id, 'abc');
});
```

### API

```dart
// Create
final container = SimpleHookProviderContainer(
  {StateA: useA, StateB: useB},    // hook registry - mirrors _providers
  provided: {
    int: 42,                        // external provided values
    Injector: testInjector,         // mocked services for useInjected
  },
);

// Access current state
container.get<StateA>()            // returns current StateA
container<StateA>()                // callable shorthand

// Update external dependency
container.setProvided<int>(100);

// Wait for async condition
await container.waitUntil<StateA>((it) => it.isReady);
```

---

## What to Test

### Do test:
- **Logic in State hooks** - filtering, sorting, derived values
- **Async operations** - loading states, success/error transitions
- **Callback behavior** - does `onSavePressed` call the service? navigate back?
- **State transitions** - does filter change update displayed items?
- **Global state interactions** - does CoursesState wait for AuthState?

### Don't test via hooks:
- **UI layout** - which widget appears where (use widget tests for that)
- **Navigation** - test that the callback was called, not that routing worked
- **Service internals** - mock the service; test that the hook calls it correctly

---

## Common Pitfalls

- **Forgetting `await context.waitUntil()`** - async hooks (useAutoComputedState, useMemoizedStream) don't resolve instantly; always wait for the expected state
- **Forgetting the `Injector` in `provided`** - any `useInjected` call throws `ProvidedValueNotFoundException` without it; build a test injector with your mocks (see Mocking Injected Services)
- **Registering a mock without the interface type parameter** - `register.instance(mock)` registers under `MockTaskService`, not `TaskService`; always `register.instance<TaskService>(mock)`
- **Asserting that a second `run` call was skipped** - `useSubmitState.run` does not block duplicate calls (it counts in-flight runs); only `runSimple(skipIfInProgress: true)` and `useSubmitButtonState` guard re-entry, so test those explicitly if that behavior matters
- **Testing without dispose** - `SimpleHookContext` and `SimpleHookProviderContainer` hold resources; call `dispose()` in `tearDown` if using `setUp`
- **Asserting before async completes** - check `isLoading` first, then wait, then check the result
- **Testing View in hook tests** - View is a `StatelessWidget`, test it separately via widget tests if needed; hook tests cover the State hook

## Running Tests

Prefer the Dart MCP `run_tests` tool (instead of shell `dart test` / `flutter test`) - it returns structured per-test results and uses the active SDK. Fall back to `dart test` / `flutter test` only in CI scripts or when MCP isn't available. See the **Dart Tooling** section in [SKILL.md](../SKILL.md) for setup.

## Related Skills

- [hooks-reference.md](./hooks-reference.md) - all hooks used in state hooks under test
- [screen-state-view.md](./screen-state-view.md) - what a screen state hook looks like
- [global-state.md](./global-state.md) - testing global state hooks with SimpleHookProviderContainer
- [async-patterns.md](./async-patterns.md) - testing useSubmitState and useAutoComputedState
- [di-services.md](./di-services.md) - how the app builds and provides the real `Injector`
