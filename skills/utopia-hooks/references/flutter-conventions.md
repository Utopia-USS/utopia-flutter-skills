---
title: Flutter Conventions
impact: HIGH
tags: conventions, collections, IList, IMap, ISet, naming, lambda, spacing, generated-code
---

# Skill: Flutter Conventions

Dart/Flutter coding conventions for projects using utopia_hooks and fast_immutable_collections.
These conventions are opinionated and strict — they eliminate entire categories of bugs.
Apply to **every `.dart` file**, not just state management code.

## When to Apply

- Writing or reviewing any `.dart` file
- Creating new widgets, models, or services
- Reviewing pull requests for style consistency

## Priority-Ordered Guidelines

| Priority | Guideline | Impact |
|----------|-----------|--------|
| 1 | Use `IList`, `IMap`, `ISet` — never raw `List`, `Map`, `Set` | CRITICAL |
| 2 | Let Dart infer types — `final name = value`, not `String name = value` | HIGH |
| 3 | Lambda convention: `it` — `items.where((it) => it.isActive)` | HIGH |
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
- No implicit `dynamic` — every type must be inferable or explicit
- No raw generic types — `List<Task>` not `List`
- No implicit casts — explicit `.cast<T>()` or type parameters required

---

## 2. Collections — fast_immutable_collections

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
items.firstOrNull                              // nullable first
items.whereNotNull                             // filter nulls
items.toIList()                                // convert Iterable → IList
items.sortedBy((it) => it.name).toIList()      // sort + convert
items.count((it) => it.isDone)                 // count matching
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
map.entries.map((key, value) => '$key: $value')
```

---

## 3. Type Inference

Prefer `final name = value` — let Dart infer the type. Only add explicit types when inference can't determine the type or when it improves readability of complex generics.

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
| Classes | `PascalCase` | `TaskPageState` |
| Variables, functions | `camelCase` | `taskCount`, `loadTasks()` |
| Private members | `_prefixed` | `_buildHeader()`, `_items` |
| Constants | `camelCase` | `defaultPageSize` (not `DEFAULT_PAGE_SIZE`) |

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
| Simple, used once in this widget | Private `_buildXxx` method in same file |
| Complex or reused across widgets | Separate file with public widget class |
| Reusable across the app | Common widget directory |

- Extracted helpers are **private by default** (`_buildXxx`)
- Only make public when intentionally part of the widget's API surface
- If a helper grows beyond a few lines, consider promoting to a separate widget class

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
// ✅ Short — arrow is fine
bool get isValid => name.isNotEmpty;
String format(Task task) => '${task.title} (${task.status})';

// ❌ Long body with arrow — hard to read
Widget build(BuildContext context) => Scaffold(
  appBar: AppBar(title: const Text('Tasks')),
  body: ListView(children: state.tasks.map((it) => TaskTile(task: it)).toList()),
);

// ✅ Long body — use curly braces
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
- `auto_route_generator` — for `auto_route` navigation (`.gr.dart`)
- `protobuf` / `grpc` — for protobuf models (`.pb.dart`)

### Running code generation

```bash
# With melos (monorepo) — if melos.yaml exists in project root
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

## Common Pitfalls

- **`List<Task>` instead of `IList<Task>`** — mutable collections in state lead to missed rebuilds and mutation bugs
- **Editing `.pb.dart` or `.freezed.dart`** — changes will be overwritten; modify the source `.proto` or `.dart` file instead
- **Verbose lambda parameters** — `(task) =>` instead of `(it) =>` breaks reading flow in chains
- **`SizedBox` spam** — if every gap is the same, use `spacing` on the parent
- **Arrow function for multi-line body** — makes diffs harder to read and formatting inconsistent
- **Explicit types everywhere** — `final String name = 'Alice'` is noise; Dart's inference is strong, trust it

## Related Skills

- [hooks-reference.md](./hooks-reference.md) — hooks follow all these conventions (IList in state, `it` lambdas, etc.)
- [page-state-view.md](./page-state-view.md) — widget extraction rules apply to View `_buildXxx` helpers
