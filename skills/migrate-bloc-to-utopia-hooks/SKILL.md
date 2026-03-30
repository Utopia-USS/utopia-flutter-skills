---
name: migrate-bloc-to-utopia-hooks
description: >
  Migrate Flutter BLoC/Cubit codebases to utopia_hooks. Applies when flutter_bloc imports,
  Bloc/Cubit classes, BlocProvider, BlocBuilder, BlocListener, or emit() calls are detected.
  Proactively suggests migration when BLoC patterns are found.
license: MIT
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, bloc, cubit, migration, utopia_hooks, state-management
---

# Migrate BLoC → utopia_hooks

## Prerequisites

If the `utopia-hooks` skill is installed, load it now — this migration skill assumes you
understand hook rules and patterns from that skill. If not installed, read
`../utopia-hooks/references/` first for the target architecture.

## Proactive Detection

**When you encounter ANY of these, suggest migration:**

```dart
// Imports
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc/bloc.dart';

// Patterns in code
class XCubit extends Cubit<XState> { ... }
class XBloc extends Bloc<XEvent, XState> { ... }
BlocProvider(create: ...)
BlocBuilder<XCubit, XState>(builder: ...)
BlocListener<XCubit, XState>(listener: ...)
BlocConsumer<XCubit, XState>(...)
context.read<XCubit>()
context.watch<XCubit>()
emit(newState)
```

**Suggested message:** "This code uses BLoC/Cubit. I can migrate it to utopia_hooks — the
result will be simpler (typically ~30% less code) with the same functionality. Want me to proceed?"

## Concept Map

| BLoC / Cubit | utopia_hooks | Notes |
|---|---|---|
| `Cubit<State>` class | `useXState()` hook function | Hook replaces entire class — no extends, no dispose |
| `Bloc<Event, State>` class | `useXState()` hook + callbacks | Events become function calls, no event classes needed |
| `emit(newState)` | `useState` / `.value =` | Direct state mutation, no immutable state copying |
| Freezed BLoC state (union) | Flat State class with nullable fields | `state.when(loading:, loaded:, error:)` → `if (state.isLoading)` |
| `BlocProvider` | `_providers` map at app root | Global state registered once |
| `BlocProvider` (local, per-screen) | Hook called inside `useXPageState()` | State lives in the hook, no Provider widget needed |
| `BlocBuilder` | `StatelessWidget` View with State param | View receives state via constructor |
| `BlocListener` | `useEffect` / callback in hook | Side effects live in hook, not in widget tree |
| `BlocConsumer` | `HookWidget` Page + `StatelessWidget` View | Page = coordinator, View = pure UI |
| `MultiBlocProvider` | `HookConsumerProviderContainerWidget` | Single widget at app root, flat map |
| `RepositoryProvider` | `Injector` + `useInjected<T>()` | Service registration via DI container |
| `context.read<XCubit>()` | `useProvided<XState>()` | Reads global state (auto-rebuilds) |
| `context.watch<XCubit>()` | `useProvided<XState>()` | Same hook — always reactive |
| `context.select<C, T>()` | `useMemoized(() => derive(state), [state])` | Derived values via memoization |
| `buildWhen: (prev, curr) => ...` | `useMemoized` with selective keys | Rebuild control via dependency array |
| `listenWhen: (prev, curr) => ...` | `useEffect` with selective keys | Effect runs only when keys change |
| `BlocObserver` | No direct equivalent | Use logging in hooks or global error handler |
| `Cubit.close()` / `Bloc.close()` | Automatic | Hooks are disposed when widget unmounts |

## Quick Migration Example

### Before (BLoC)

```dart
// counter_cubit.dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

// counter_page.dart
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CounterCubit(),
      child: BlocBuilder<CounterCubit, int>(
        builder: (context, count) {
          return Column(children: [
            Text('$count'),
            ElevatedButton(
              onPressed: () => context.read<CounterCubit>().increment(),
              child: const Text('+'),
            ),
          ]);
        },
      ),
    );
  }
}
```

### After (utopia_hooks)

```dart
// state/counter_page_state.dart
class CounterPageState {
  final int count;
  final void Function() onIncrement;
  final void Function() onDecrement;

  const CounterPageState({
    required this.count,
    required this.onIncrement,
    required this.onDecrement,
  });
}

CounterPageState useCounterPageState() {
  final count = useState(0);
  return CounterPageState(
    count: count.value,
    onIncrement: () => count.value++,
    onDecrement: () => count.value--,
  );
}

// counter_page.dart
class CounterPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useCounterPageState();
    return CounterPageView(state: state);
  }
}

// view/counter_page_view.dart
class CounterPageView extends StatelessWidget {
  final CounterPageState state;
  const CounterPageView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('${state.count}'),
      ElevatedButton(
        onPressed: state.onIncrement,
        child: const Text('+'),
      ),
    ]);
  }
}
```

**Result:** 3 classes + BlocProvider → 3 focused files, no framework classes to extend, automatic cleanup.

## References

| File | Impact | Description |
|------|--------|-------------|
| [bloc-to-hooks-mapping.md][mapping] | CRITICAL | Every BLoC pattern → hooks equivalent with side-by-side code |
| [migration-steps.md][steps] | HIGH | Step-by-step checklist for converting one screen |
| [global-state-migration.md][global] | HIGH | Provider tree → _providers, RepositoryProvider → Injector |

[mapping]: references/bloc-to-hooks-mapping.md
[steps]: references/migration-steps.md
[global]: references/global-state-migration.md

## Problem → Reference

| Situation | Start With |
|-----------|------------|
| Converting a Cubit to hooks | [bloc-to-hooks-mapping.md][mapping] |
| Converting a Bloc with events to hooks | [bloc-to-hooks-mapping.md][mapping] |
| Migrating BlocProvider tree | [global-state-migration.md][global] |
| Migrating RepositoryProvider | [global-state-migration.md][global] |
| Step-by-step process for one screen | [migration-steps.md][steps] |
| Freezed union state → hooks state | [bloc-to-hooks-mapping.md][mapping] |
| BlocListener side effects | [bloc-to-hooks-mapping.md][mapping] |
| Removing flutter_bloc dependency | [migration-steps.md][steps] |

## Non-Negotiable Migration Rules

- **Never mix BLoC and hooks in the same screen** — migrate completely or leave as-is
- **Always create Page/State/View** — don't replace BlocBuilder with a HookWidget that has inline UI
- **State class must NOT import widgets** — same rule as in utopia-hooks
- **View never calls hooks** — BlocBuilder's `builder:` becomes a StatelessWidget
- **Delete BLoC files after migration** — don't leave dead code
- **The ~30% code reduction is a consequence** — focus on correctness, not size

## Migration Anti-Patterns — NEVER DO THESE

These are the most common mistakes when migrating. Every single one must be absent from migrated code.

```dart
// ❌ NEVER: copyWith() in hooks — this is BLoC thinking, not hooks thinking
state.value = state.value.copyWith(isLoading: true);
// ✅ INSTEAD: one useState per mutable field
final isLoading = useState(false);
isLoading.value = true;

// ❌ NEVER: Equatable on state classes — hooks don't need equality checks
class MyState extends Equatable {
  @override List<Object?> get props => [field1, field2];
}
// ✅ INSTEAD: plain class with final fields
class MyState {
  final String? data;
  final bool isLoading;
  const MyState({required this.data, required this.isLoading});
}

// ❌ NEVER: Status enum (idle/loading/success/failure) — hooks have built-in state machines
final Status status;
// ✅ INSTEAD: useAutoComputedState has ComputedStateValue (notInitialized/inProgress/ready/failed)
//            useSubmitState has .inProgress bool
//            State class exposes: T? data (via .valueOrNull), bool isSaving (via .inProgress)

// ❌ NEVER: passing Cubit/Bloc instances to hooks
FavState useFavState({required AuthBloc authBloc}) {
  authBloc.stream.listen(...);   // BLoC API in hooks
  authBloc.state.username;       // reading .state from BLoC
}
// ✅ INSTEAD: useProvided for global state
FavState useFavState() {
  final authState = useProvided<AuthState>();
  // authState.username — direct field access, reactive

// ❌ NEVER: emit() wrapper function
void emit(MyState newState) { state.value = newState; }
// ✅ INSTEAD: mutate individual useState fields directly

// ❌ NEVER: keeping files named _bloc.dart or _cubit.dart
// ✅ INSTEAD: rename to _state.dart (e.g. auth_bloc.dart → auth_state.dart)

// ❌ NEVER: adding comments like "// State", "// Hook", "// ---" section dividers
// ✅ INSTEAD: clean code, no noise comments

// ❌ NEVER: manual stream subscriptions in useEffect for data that should be reactive
useEffect(() { cubit.stream.listen(...); }, []);
// ✅ INSTEAD: useMemoizedStream or useAutoComputedState
final data = useMemoizedStream(service.streamData);
```

## Pre-Submit Checklist

Before considering migration complete, verify ALL of these. **If any fail, the migration is not done.**

### Compilation gates (run these first)
```
□ flutter pub get succeeds
□ dart analyze returns zero errors
```

### Code audit (grep to verify)
```
□ Zero imports of flutter_bloc, bloc, hydrated_bloc anywhere in lib/
□ Zero copyWith() methods in state classes
□ Zero extends Equatable on state classes
□ Zero Status enums — hooks have built-in state machines (ComputedStateValue, submitState.inProgress)
□ Zero files named _bloc.dart or _cubit.dart (renamed to _state.dart)
□ Zero cubit/bloc class parameters in hooks (use useProvided instead)
□ Zero .stream or .state access on old cubit/bloc objects
□ Zero added comments (no "// State", "// Hook", "// ---" dividers, no typedefs for backward compat)
□ flutter_bloc, bloc, bloc_concurrency, hydrated_bloc, bloc_test, bloc_lint removed from pubspec.yaml
□ utopia_hooks (or utopia_arch) added to pubspec.yaml
```

## Attribution

Migration from [flutter_bloc](https://pub.dev/packages/flutter_bloc) to
[utopia_hooks](https://pub.dev/packages/utopia_hooks) / [utopia_arch](https://pub.dev/packages/utopia_arch)
by UtopiaSoftware.
