---
title: Flutter Conventions
impact: HIGH
tags: conventions, collections, IList, IMap, ISet, naming, lambda, spacing, generated-code, design-system, ButtonState, FieldState, errorMessage
---

# Skill: Flutter Conventions

Dart/Flutter coding conventions for projects using utopia_hooks and fast_immutable_collections.
These conventions are opinionated and strict - they eliminate entire categories of bugs.
Apply to **every `.dart` file**, not just state management code.

## When to Apply

- Writing or reviewing any `.dart` file
- Creating new widgets, models, or services
- Reviewing pull requests for style consistency

## Priority-Ordered Guidelines

| Priority | Guideline | Impact |
|----------|-----------|--------|
| 1 | Use `IList`, `IMap`, `ISet` - never raw `List`, `Map`, `Set` | CRITICAL |
| 2 | Let Dart infer types - `final name = value`, not `String name = value` | HIGH |
| 3 | Lambda convention: `it` - `items.where((it) => it.isActive)` | HIGH |
| 4 | Extract long `build()` into private `_buildXxx` helpers | HIGH |
| 5 | Prefer `spacing` / `runSpacing` over manual `SizedBox` | MEDIUM |
| 6 | Curly braces for function bodies > 2 lines | MEDIUM |
| 7 | Never edit generated files (`.pb.dart`, `.freezed.dart`, `.g.dart`, `.gr.dart`) | CRITICAL |

---

## 1. Strict Analyzer

Projects use maximum strictness. These are non-negotiable:

```yaml
# analysis_options.yaml
analyzer:
  language:
    strict-inference: true
    strict-raw-types: true
    strict-casts: true
```

This means:
- No implicit `dynamic` - every type must be inferable or explicit
- No raw generic types - `List<Task>` not `List`
- No implicit casts - explicit `.cast<T>()` or type parameters required

---

## 2. Collections - fast_immutable_collections

**Always use `IList`, `IMap`, `ISet`** instead of `List`, `Map`, `Set`. This includes function parameters, return types, and state fields.

```dart
// ❌ Mutable collections
final List<Task> tasks = [];
tasks.add(newTask);

// ✅ Immutable collections
final IList<Task> tasks = const IList.empty();
final updated = tasks.add(newTask);  // returns new IList
```

### Key utilities

```dart
items.findOrNull((it) => it.id == targetId)   // nullable find
items.firstOrNull()                            // nullable first (takes an optional predicate)
items.whereNotNull()                           // filter nulls: Iterable<T?> → Iterable<T>
items.toIList()                                // convert Iterable → IList
items.toSortedList((a, b) => a.name.compareTo(b.name)).toIList() // sort + convert
items.where((it) => it.isDone).length          // count matching
```

### Lambda convention: `it`

Always use `it` as the lambda parameter name for single-parameter closures:

```dart
// ❌ Verbose / inconsistent
tasks.where((task) => task.isActive)
tasks.map((element) => element.title)

// ✅ Convention: `it`
tasks.where((it) => it.isActive)
tasks.map((it) => it.title)
tasks.sortedBy((it) => it.dueDate)
```

Multi-parameter lambdas use descriptive names:

```dart
items.fold(0, (sum, item) => sum + item.count)
map.forEach((key, value) => buffer.writeln('$key: $value'))
```

---

## 3. Type Inference

Prefer `final name = value` - let Dart infer the type. Only add explicit types when inference can't determine the type or when it improves readability of complex generics.

```dart
// ❌ Redundant type annotation
final String name = 'Alice';
final int count = items.length;
final bool isValid = name.isNotEmpty;
final IList<Task> tasks = state.tasks;

// ✅ Let Dart infer
final name = 'Alice';
final count = items.length;
final isValid = name.isNotEmpty;
final tasks = state.tasks;

// ✅ Explicit type when needed (inference fails or complex generic)
final IList<Task> tasks = const IList.empty();
final Map<String, List<int>> index = {};
useState<IList<Task>>(const IList.empty());  // generic parameter for hook
```

---

## 4. Naming

| Kind | Convention | Example |
|------|-----------|---------|
| Files | `snake_case` | `task_page_state.dart` |
| Classes | `PascalCase` | `TaskScreenState` |
| Variables, functions | `camelCase` | `taskCount`, `loadTasks()` |
| Private members | `_prefixed` | `_buildHeader()`, `_items` |
| Constants | `camelCase` | `defaultPageSize` (not `DEFAULT_PAGE_SIZE`) |

### File basename ↔ top-level class name

The top-level class in a `.dart` file shares its basename, PascalCased. The file path encodes
the feature scope; the class name reflects that scope, not just the local concept. Same rule
for the matching hook: `useFileBasenameInCamelCase()`.

```dart
// file: account_onboarding/state/account_onboarding_champions_state.dart

// ❌ Drops the parent feature; collides with any other ChampionsState in the app
class ChampionsState { /* ... */ }
AccountOnboardingChampionsState useChampionsState({ /* ... */ }) { /* ... */ }

// ✅ Class name = file basename, PascalCased. Hook name = file basename, camelCased.
class AccountOnboardingChampionsState { /* ... */ }
AccountOnboardingChampionsState useAccountOnboardingChampionsState({ /* ... */ }) { /* ... */ }
```

Applies to screen/state/view files and to sub-state files in `state/` folders. Private helper
classes inside the file are exempt.

---

## 5. Widget Extraction

When `build()` gets long, extract parts into private `_buildXxx` helper methods.

```dart
// ❌ Massive build method
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // 20 lines of header...
      // 30 lines of body...
      // 15 lines of footer...
    ],
  );
}

// ✅ Extracted helpers
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      _buildHeader(),
      _buildBody(),
      _buildFooter(),
    ],
  );
}

Widget _buildHeader() { ... }
Widget _buildBody() { ... }
Widget _buildFooter() { ... }
```

### Rules

| Situation | Approach |
|-----------|----------|
| Simple, ≤ ~30 lines, used once | Private `_buildXxx` method in same file (NOT a private `StatelessWidget` class) |
| > ~40 lines or has own state | Extract to `screen/{feature}/widget/` - see [composable-hooks.md](./composable-hooks.md) for widget-level hook pattern |
| Reusable across screens | `common/widget/` directory |

For row 1, the private-class form is the common over-extraction trap: a trivial widget gets
wrapped in `class _Foo extends StatelessWidget` whose boilerplate (fields, constructor, `@override`,
`build`) matches or exceeds the widget body. The reader pays in indirection (scroll to the bottom
of the file to see what `_Foo` renders) for no structural benefit.

```dart
// ❌ Private StatelessWidget for a trivial widget: wrapper boilerplate ≈ body, body lives away from call site
class _DebugSkipButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _DebugSkipButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: const Text('Skip (debug)'),
  );
}

// ✅ Private method: half the LoC, body lives next to the call site inside build()
Widget _buildDebugSkipButton() => TextButton(
  onPressed: state.onSkipPressed,
  child: const Text('Skip (debug)'),
);
```

**Cost heuristic:** if `class _Foo extends StatelessWidget { ...constructor + build... }` writes
as much or more LoC than the widget body itself, the class wrapper is paying for itself in
indirection, not in structure. Use a method. Reach for a class only when the body crosses the
~40-LoC / own-state threshold from row 2.

- View files should stay under ~300 lines - extract beyond that
- Stateful/HookWidget classes never live inside a view file - always extract them

---

## 6. Layout Spacing

Prefer `spacing` / `runSpacing` on container widgets over manual `SizedBox` spacers:

```dart
// ❌ Manual SizedBox spacers
Column(
  children: [
    Text('Title'),
    SizedBox(height: 8),
    Text('Subtitle'),
    SizedBox(height: 8),
    Text('Body'),
  ],
)

// ✅ Container spacing
Column(
  spacing: 8,
  children: [
    Text('Title'),
    Text('Subtitle'),
    Text('Body'),
  ],
)
```

Works with `Row`, `Column`, `Wrap`, `Flex`:

```dart
Row(spacing: 12, children: [...])
Wrap(spacing: 8, runSpacing: 8, children: [...])
```

Use manual `SizedBox` only for **irregular layouts** with intentionally different gaps between specific children.

---

## 7. Function Style

If the function body formats to **more than 2 lines**, use curly-brace form:

```dart
// ✅ Short - arrow is fine
bool get isValid => name.isNotEmpty;
String format(Task task) => '${task.title} (${task.status})';

// ❌ Long body with arrow - hard to read
Widget build(BuildContext context) => Scaffold(
  appBar: AppBar(title: const Text('Tasks')),
  body: ListView(children: state.tasks.map((it) => TaskTile(task: it)).toList()),
);

// ✅ Long body - use curly braces
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Tasks')),
    body: ListView(
      children: state.tasks.map((it) => TaskTile(task: it)).toList(),
    ),
  );
}
```

---

## 8. Code Generation

Projects should use `freezed` for immutable data classes and `build_runner` for code generation.

### Required packages

```yaml
# pubspec.yaml
dependencies:
  freezed_annotation: ^2.0.0
  json_annotation: ^4.0.0    # if using json_serializable

dev_dependencies:
  build_runner: ^2.0.0
  freezed: ^2.0.0
  json_serializable: ^6.0.0  # if using JSON
```

Optional generators (add as needed):
- `auto_route_generator` - for `auto_route` navigation (`.gr.dart`)
- `protobuf` / `grpc` - for protobuf models (`.pb.dart`)

### Running code generation

```bash
# With melos (monorepo) - if melos.yaml exists in project root
melos build_runner:build

# Without melos (single package)
dart run build_runner build --delete-conflicting-outputs
```

Check if project uses melos: look for `melos.yaml` in root. If yes, prefer `melos` commands. If no, use `dart run build_runner` directly.

### Generated file suffixes

| Suffix | Generator | Never edit |
|--------|-----------|------------|
| `.freezed.dart` | freezed | ✅ |
| `.g.dart` | json_serializable / other | ✅ |
| `.gr.dart` | auto_route | ✅ |
| `.pb.dart`, `.pbenum.dart`, `.pbjson.dart`, `.pbgrpc.dart` | protobuf | ✅ |

After editing a `part` file (e.g., a file with `part 'file.freezed.dart';`), always re-run code generation.

---

## 9. TextEditingController - always `useFieldState` + `TextEditingControllerWrapper`

**Never manage a `TextEditingController` directly from hooks.** Always use `useFieldState()` as the source of truth in the state hook, and render the field through `TextEditingControllerWrapper` in the View.

```dart
// ❌ FORBIDDEN - useMemoized + useListenable cannot resync cleanly when the
//                external value changes while the user is typing
final controller = useMemoized(TextEditingController.new);
useListenable(controller);
useEffect(() {
  controller.text = externalValue;
  return null;
}, [externalValue]);

// ❌ ALSO FORBIDDEN - manual dispose leaks on hot reload and double-disposes
//                      when keys change
final controller = useMemoized(() => TextEditingController(text: initial));
useEffect(() => controller.dispose, const []);

// ❌ ALSO FORBIDDEN - any useEffect that writes to controller.text
useEffect(() {
  if (controller.text != external) controller.text = external;
  return null;
}, [external]);
```

**Why**: `TextEditingController` has its own lifecycle (focus, selection, composing region) that does not compose with hook rebuilds. `useMemoized` does not rebuild the controller when the source of truth changes; `useEffect` writes to `.text` stomp on user input and lose cursor position. `useFieldState` was designed specifically because `useMemoized` + `useListenable` fail to stay in sync under concurrent external updates + user edits.

### Correct pattern

**State hook** - `useFieldState` is the source of truth:

```dart
class EditProductScreenState {
  final MutableFieldState nameField;
  final bool isSaving;
  final void Function() onSavePressed;
  const EditProductScreenState({
    required this.nameField,
    required this.isSaving,
    required this.onSavePressed,
  });
}

EditProductScreenState useEditProductScreenState({
  required String initialName,
  required void Function() navigateBack,
}) {
  final nameField = useFieldState(initialValue: initialName);
  final saveState = useSubmitState();
  // ...
  return EditProductScreenState(
    nameField: nameField,
    isSaving: saveState.inProgress,
    onSavePressed: () => saveState.runSimple<void, Never>(
      submit: () async => service.update(name: nameField.value),
      afterSubmit: (_) => navigateBack(),
    ),
  );
}
```

**View** - `TextEditingControllerWrapper` owns the controller and bi-directionally syncs with the field state:

```dart
class EditProductScreenView extends StatelessWidget {
  final EditProductScreenState state;
  const EditProductScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextEditingControllerWrapper(
        text: state.nameField,
        builder: (controller) => TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ),
      ElevatedButton(
        onPressed: state.onSavePressed,
        child: const Text('Save'),
      ),
    ]);
  }
}
```

Projects typically wrap `TextEditingControllerWrapper` in their own field widget (`AppTextField(state: nameField)`, `CrazyTextField(state: nameField)`) - that's fine and encouraged for UI consistency. The core contract stays: the field state is the source of truth, and `TextEditingControllerWrapper` owns the controller lifecycle.

### FocusNode follows the same rule

> **Availability caveat**: `useFocusNode` is exported on current utopia_hooks master
> (unreleased at 0.4.25); on the published 0.4.25 release it is NOT exported - use the
> `flutter_hooks` `useFocusNode` or a local definition (see hooks-reference.md section 8),
> and delete the local copy when you upgrade. The convention below applies either way.

Use a hook-owned `FocusNode` (`useFocusNode()`) so its lifecycle is managed for you.
**Never** sync focus with `useEffect` + `focusNode.requestFocus()` / `unfocus()` based on an external flag - that's the same class of bug.

```dart
// ❌ FORBIDDEN
useEffect(() {
  if (shouldFocus) focusNode.requestFocus();
  else focusNode.unfocus();
  return null;
}, [shouldFocus]);

// ✅ Instead: trigger focus from the callback that sets shouldFocus (imperatively),
//            or use a dedicated focus wrapper that coordinates with the field's state.
```

---

## 10. Design-System Widgets Accept Hook State Objects

Project design-system widgets (buttons, text fields, switches, list shells) should accept
the hook state objects directly - `FieldState`, `ButtonState`, `MutableValue<bool>`,
`PaginatedComputedState` - instead of exploded primitives. Views then become pass-through:
they hand the state object to the widget rather than re-deriving `isLoading` / `enabled` /
`onPressed` at every call site.

```dart
// ❌ Exploded primitives - every View re-wires loading/enabled/onTap by hand
CrazyButton(
  label: 'Save',
  isLoading: state.isSaving,
  onPressed: state.isSaving ? null : state.onSavePressed,
)

// ✅ Widget accepts the state object - View is pass-through
class CrazyButton extends StatelessWidget {
  final String label;
  final ButtonState state;
  const CrazyButton({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: state.onTapIfEnabled,
      child: state.loading ? const CrazyButtonLoader() : Text(label),
    );
  }
}

CrazyButton(label: 'Save', state: state.saveButton)
```

The same applies across the design system: `CrazyTextField(state: nameField)` wrapping
`TextEditingControllerWrapper` (section 9), `CrazySwitch(state: state.notificationsEnabled)`
taking a `MutableValue<bool>`, a list shell taking a `PaginatedComputedState` directly.
(`Crazy*` widgets are placeholders for your own design system.)

### ButtonState is never hand-constructed for submit-backed buttons

Always derive it from the submit state - `submitState.toButtonState(onTap: ...)` wires
`loading` automatically, and `useSubmitButtonState(action)` additionally guards re-entrant
taps:

```dart
// ❌ Hand-rolled - loading wiring drifts from the actual submit over time
ButtonState(onTap: onSave, loading: saveState.inProgress)

// ✅ Derived from the submit state
saveState.toButtonState(onTap: onSave)
```

---

## 11. Localizable Error Messages - `String Function(BuildContext)`

`FieldState.errorMessage` is a `ValidatorResult?` - a typedef for
`String Function(BuildContext)?` (from `utopia_validation`). Error text is resolved against
a `BuildContext` at render time, so state hooks stay context-free: the hook assigns the
message, the View resolves it.

```dart
// State hook - no BuildContext anywhere
emailField.errorMessage = (context) => Strings.of(context).invalidEmail;

// View - resolve at render time
final errorText = state.emailField.errorMessage?.call(context);
```

Follow the same convention for your own error-bearing state fields: store
`String Function(BuildContext)?`, never a pre-resolved `String` (which would force the state
hook to touch localization and context) and never a raw error code (which would force the
View to switch over domain errors).

---

## Common Pitfalls

- **`List<Task>` instead of `IList<Task>`** - mutable collections in state lead to missed rebuilds and mutation bugs
- **Editing `.pb.dart` or `.freezed.dart`** - changes will be overwritten; modify the source `.proto` or `.dart` file instead
- **Verbose lambda parameters** - `(task) =>` instead of `(it) =>` breaks reading flow in chains
- **`SizedBox` spam** - if every gap is the same, use `spacing` on the parent
- **Arrow function for multi-line body** - makes diffs harder to read and formatting inconsistent
- **Explicit types everywhere** - `final String name = 'Alice'` is noise; Dart's inference is strong, trust it
- **Hand-constructed `ButtonState` next to a `SubmitState`** - always `submitState.toButtonState()` so loading can't drift (section 10)
- **Pre-resolved error strings in state hooks** - error text is `String Function(BuildContext)?`; resolving it in the hook drags context/localization into state (section 11)

## Related Skills

- [hooks-reference.md](./hooks-reference.md) - hooks follow all these conventions (IList in state, `it` lambdas, etc.)
- [screen-state-view.md](./screen-state-view.md) - widget extraction rules apply to View `_buildXxx` helpers
