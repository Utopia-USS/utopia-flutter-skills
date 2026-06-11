---
title: Entries (column + edit field, CmsEntry catalog)
impact: CRITICAL
tags: entry, column, field, modifier
---

# Skill: Entries (Column and Edit Field)

A **`CmsEntry`** declares one piece of data on the row: where to read it from
(`key`), how to label it, how it renders in the table (`buildPreview`), how it
renders in the create/edit form (`buildEditField`), and a `modifier` flag-set
that controls behavior across both contexts.

You pass a `List<CmsEntry>` to `CmsTablePage(entries: …)`. The same list drives
**both** the table columns *and* the create/edit form. They're not two separate
schemas.

## Quick Pattern

### ❌ Anti-pattern

Two parallel structures - `DataColumn` list for the table and `TextField` /
`Switch` / `Dropdown` widgets for an edit dialog. Risk: they drift apart.

### ✅ utopia_cms way

```dart
entries: [
  CmsTextEntry(key: 'id',    label: 'ID',    flex: 1, modifier: CmsEntryModifier(initializable: false, editable: false)),
  CmsTextEntry(key: 'name',  label: 'Name',          modifier: CmsEntryModifier(sortable: true)),
  CmsTextEntry(key: 'email', label: 'Email',         modifier: CmsEntryModifier(sortable: true, editable: false)),
  CmsTextEntry(
    key: 'phone',
    label: 'Phone',
    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+() -]'))],
  ),
  CmsBoolEntry(key: 'isActive', label: 'Active'),
  CmsDateEntry(key: 'created',  label: 'Joined',     modifier: CmsEntryModifier(editable: false, sortable: true)),
  CmsNumEntry (key: 'orderIndex', label: 'Order',    modifier: CmsEntryModifier(sortable: true)),
  CmsDropdownEntry<String>(
    key: 'role',
    label: 'Role',
    values: const ['user', 'admin', 'super_admin'],
    valueLabelBuilder: (v) => v?.replaceAll('_', ' ') ?? '',
  ),
]
```

## The catalog

| Entry                    | Maps to       | Use for                                              |
|--------------------------|---------------|------------------------------------------------------|
| `CmsTextEntry`           | `String?`     | names, emails, descriptions, long-form               |
| `CmsNumEntry`            | `num?`        | counts, prices (`isDecimal: true`), ages             |
| `CmsBoolEntry`           | `bool?`       | flags (visible / active / featured / archived)       |
| `CmsDateEntry`           | `DateTime?`   | timestamps, birth dates, due dates                   |
| `CmsDropdownEntry<T>`    | `T?`          | closed enum-like sets (status, role, category)       |
| `CmsCountryEntry`        | country code  | country selection                                    |
| `CmsMediaEntry`          | media list    | images / videos / files - see [media.md](media.md)   |
| `CmsToManyDropdownEntry` | relation      | M2M / O2M - see [relationships.md](relationships.md) |

You can write your own entry by extending `CmsEntry<T>` - implement `buildPreview` and `buildEditField`, optionally `toJson` / `fromJson`. See "Custom entries" below.

There is **no entry type for nested maps or lists of objects** (a map of device ids, a list of status objects). Don't force one - render those as a read-only sliver section in the create/edit overlay instead. See [management-sections.md](management-sections.md).

## The `CmsEntryModifier`

```dart
CmsEntryModifier({
  bool pinned        = true,    // appears in the table (vs only in the create/edit overlay)
  bool editable      = true,    // false → read-only in edit (rendered in the overlay's "Read only" section)
  bool initializable = true,    // create shows fields where editable OR initializable → set both false to hide in create (e.g. server-generated id)
  bool required      = true,    // shows '*' in label; submit disabled while empty
  bool sortable      = false,   // header tappable for sort - needs backend support
  bool sortInvertNulls = false, // nulls last (vs first) when sorting; needs backend support
  bool expanded      = false,   // gives the field its own row in the edit overlay (vs sharing with siblings)
})
```

### Cheat-sheet for common combinations

| Field intent              | Modifier                                                                        |
|---------------------------|---------------------------------------------------------------------------------|
| Plain editable column     | `CmsEntryModifier()`                                                            |
| Sortable column           | `CmsEntryModifier(sortable: true)`                                              |
| Server-generated `id`     | `CmsEntryModifier(initializable: false, editable: false)`                       |
| Optional field            | `CmsEntryModifier(required: false)`                                             |
| Email (set on create, not after) | `CmsEntryModifier(editable: false, sortable: true)`                       |
| Long text (own row in form) | `CmsEntryModifier(expanded: true)`                                            |
| Hidden in table, visible in form | `CmsEntryModifier(pinned: false)`                                        |
| Role-gated edit           | `CmsEntryModifier(editable: isSuperAdmin)`                                      |

## Dotted-path keys

`key` accepts dotted paths to reach nested JSON:

```dart
CmsTextEntry(key: 'contactData.name',      label: 'Name'),
CmsTextEntry(key: 'contactData.address',   label: 'Address'),
CmsTextEntry(key: 'meta.billing.vatNumber', label: 'VAT no.'),
```

This works because `JsonMapExtensions.getAtPath / setAtPath` handle the traversal. Don't flatten by hand in the delegate. Don't model nested data as a separate column.

With GraphQL / Hasura delegates, fetch the parent JSON column **once** in the delegate's field set; entries then address its leaves with dotted keys. Don't list each leaf as a separate `CmsGraphQLField`:

```dart
// Delegate field set: the whole JSON column, once
fields: {CmsGraphQLField('contactData')},

// Entries address the leaves:
CmsTextEntry(key: 'contactData.name',  label: 'Name'),
CmsTextEntry(key: 'contactData.vatNo', label: 'VAT no.'),
```

## Per-entry reference

### `CmsTextEntry`

```dart
CmsTextEntry({
  required String key,
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(),
  int maxLength = 500,
  int maxLines  = 1,
  List<TextInputFormatter>? formatters,
  TextOverflow? overflow,
  int flex = 2,
  String Function(String?)? previewBuilder,                   // custom preview rendering
})
```

- **`maxLines: > 1`** → multi-line input. Pair with `modifier: CmsEntryModifier(expanded: true)` for a full-row text area.
- **`formatters`** for input masking (phone, IBAN, etc.).
- **`previewBuilder`** to customize how the value shows in the table - e.g. truncate, format as a code, hide partially.

### `CmsNumEntry`

```dart
CmsNumEntry({
  required String key,
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(),
  bool isDecimal = false,                                    // true → allows '.' separator
  int flex = 2,
  String Function(num?)? previewBuilder,
})
```

- **`isDecimal: true`** for prices / fractions; otherwise integer input only.
- Use `previewBuilder` to add a unit / currency in the preview (`'$${v}'`).

### `CmsBoolEntry`

```dart
CmsBoolEntry({
  required String key,
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(),
  int flex = 2,
})
```

The preview is a read-only `CmsSwitch`. The edit field is a labelled switch. Perfect for `isVisible / isActive / featured / archived` columns - **do not** invent a custom toggle button for these.

### `CmsDateEntry`

```dart
CmsDateEntry({
  required String key,
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(),
  int flex = 2,
})
```

Stores `DateTime`. The edit field is `CmsDatePicker`. `toJson` is `DateTime.toString()` (space-separated, e.g. `2026-05-28 00:00:00.000` - not the ISO-8601 'T' form); `fromJson` is `DateTime.parse`, which accepts both.

**Known limitation (v0.2.3):** the stock edit field does not refresh after picking - `CmsDatePicker` renders through `CmsTextField`, which seeds `useFieldState(initialValue: ...)` on first build only, so the picked date never shows up in the field. And `toJson` emits `DateTime.toString()`, which breaks backends expecting strict ISO-8601 or date-only keys. Workaround: a drop-in custom entry that derives its visible text from the framework-provided `value`:

```dart
class DateEntry extends CmsEntry<DateTime?> {
  // key / label / modifier / flex + buildPreview as usual...

  @override
  Widget buildEditField({required BuildContext context, required DateTime? value, required void Function(DateTime?) onChanged}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);          // rebuild -> the Text below shows the fresh value
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: fixedLabelRequired),
        child: Text(value != null ? _format(value) : 'Pick a date'),
      ),
    );
  }

  @override
  String? toJson(DateTime? value) => value == null ? null : _format(value);   // 'YYYY-MM-DD', NOT value.toString()

  static String _format(DateTime d) => d.toIso8601String().substring(0, 10);
}
```

### `CmsDropdownEntry<T>`

```dart
CmsDropdownEntry<T>({
  required String key,
  required List<T> values,
  required String Function(T? value) valueLabelBuilder,
  T? defaultValue,
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(),
  int flex = 2,
})
```

Closed sets - roles, statuses, categories. `valueLabelBuilder` produces the display label (e.g. `(v) => v?.replaceAll('_', ' ') ?? ''`).

`CmsDropdownEntry.simple` is the same constructor with `flex` defaulting to 1 instead of 2 - a convenience for narrow enum columns, not different semantics.

For *open* sets coming from another collection, use `CmsToManyDropdownEntry` (see [relationships.md](relationships.md)).

### `CmsCountryEntry`

```dart
CmsCountryEntry({
  required String key,
  dynamic Function(CountryCode value)? valueBuilder,   // picked CountryCode -> stored value; default stores value.code (ISO code String)
  String Function(dynamic object)? displayBuilder,     // stored value -> text in BOTH the table preview and the field
  String? label,
  CmsEntryModifier modifier = const CmsEntryModifier(),
  TextOverflow? overflow,                              // label truncation
  int flex = 2,
})
```

`CountryCode` (`.code`, `.name`, `.dialCode`) is re-exported from `country_code_picker` through utopia_cms - no extra import needed. The default stores the ISO code string. If the backend stores the country name, dial code, or an object, set `valueBuilder` (what gets stored) and pair it with `displayBuilder` (how the stored value renders) - without the pair the table shows the raw stored value.

```dart
CmsCountryEntry(
  key: 'country',
  label: 'Country',
  valueBuilder: (code) => code.name,                   // store 'Germany' instead of 'DE'
)
```

### `CmsMediaEntry`

See [media.md](media.md).

### `CmsToManyDropdownEntry`

See [relationships.md](relationships.md).

## Custom entries

Implement the `CmsEntry<T>` interface for bespoke types - e.g. JSON blob editor,
color picker, geo-coordinate, masked-text-with-validation:

```dart
class CmsColorEntry extends CmsEntry<Color?> {
  CmsColorEntry({required this.key, this.label, this.modifier = const CmsEntryModifier(), this.flex = 2});

  @override final String key;
  @override final int flex;
  @override final String? label;
  @override final CmsEntryModifier modifier;

  @override
  Widget buildPreview(BuildContext context, Color? value) =>
      Container(width: 24, height: 24, color: value ?? Colors.transparent);

  @override
  Widget buildEditField({required BuildContext context, required Color? value, required void Function(Color?) onChanged}) =>
      CmsFieldWrapper(child: ColorPickerField(value: value, onChanged: onChanged, label: fixedLabelRequired));

  @override
  Object? toJson(Color? value) => value?.value;                          // store as int
  @override
  Color? fromJson(Object? json) => json == null ? null : Color(json as int);
}
```

Use `CmsFieldWrapper` to inherit the field chrome (border, label, padding) and
keep visual consistency with built-in entries.

### Computed read-only columns

Key an entry on a parent map to derive a display value. `editable: false,
initializable: false` hides it in create and moves it to the edit overlay's
read-only section; pass the map through `toJson` untouched, so server-owned
data is never clobbered on save:

```dart
class VoteStatsEntry extends CmsEntry<Map<String, dynamic>?> {
  VoteStatsEntry({required this.key, this.label});

  @override final String key;                          // e.g. 'voteStats' - a nested map on the row
  @override final String? label;
  @override final int flex = 2;
  @override final CmsEntryModifier modifier = const CmsEntryModifier(editable: false, initializable: false);

  @override
  Widget buildPreview(BuildContext context, Map<String, dynamic>? value) {
    final up = (value?['upCount'] as num?)?.toInt() ?? 0;
    final down = (value?['downCount'] as num?)?.toInt() ?? 0;
    final total = up + down;
    return Text(total == 0 ? '0' : '$total (${(up * 100 / total).round()}% up)');
  }

  @override
  Widget buildEditField({required BuildContext context, required Map<String, dynamic>? value, required void Function(Map<String, dynamic>?) onChanged}) =>
      const SizedBox.shrink();                         // still rendered in the read-only section - show nothing

  @override
  Object? toJson(Map<String, dynamic>? value) => value;   // round-trip server-owned counters untouched
}
```

### Cross-field entries (reading sibling values)

`buildEditField` runs inside the create/edit overlay, which provides the shared
form state via `package:provider`. An entry can read **sibling** field values
from it - e.g. a "Generate" button that needs the already-uploaded image URL.

`CmsManagementBaseState` is not exported from `package:utopia_cms/utopia_cms.dart`
as of v0.2.3, so this is the one sanctioned exception to the no-`src/`-imports rule:

```dart
import 'package:provider/provider.dart';
import 'package:utopia_cms/src/ui/item_management/state/cms_management_state.dart'; // not exported - deep import required

// In the entry:
@override
Widget buildEditField({required BuildContext context, required String? value, required void Function(String?) onChanged}) =>
    _ColorEditor(value: value, onChanged: onChanged);  // keep the entry class itself stateless

class _ColorEditor extends HookWidget {
  const _ColorEditor({required this.value, required this.onChanged});
  final String? value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final overlay = Provider.of<CmsManagementBaseState>(context);  // listening -> rebuilds as siblings change
    final imageUrl = overlay.values['imageUrl'] as String?;        // a SIBLING field's current value
    return CmsFieldWrapper(
      child: Row(children: [
        Text(value ?? 'No color'),
        CmsButton(
          dense: true,
          isEnabled: imageUrl != null,                             // live: enables once the image is uploaded
          onTap: () async => onChanged(await deriveColor(imageUrl!)),
          child: const Text('Generate from image'),
        ),
      ]),
    );
  }
}
```

Always `Provider.of<CmsManagementBaseState>(context)` here - utopia_hooks'
`useProvided` does not resolve it inside the overlay and throws. A listening
`Provider.of` keeps the field live as siblings change; use `listen: false` for
one-shot reads inside callbacks.

## Layout - `flex` and `expanded`

In the table, columns are laid out in a `Row` with `Expanded(flex: entry.flex)`. Tune for legibility:

- `flex: 1` - IDs, booleans, small enums
- `flex: 2` (default) - names, emails, dates, numbers
- `flex: 3` - descriptions, addresses
- `flex: 4` - long text, search-bar-like fields

In the edit overlay, fields share rows by default. `modifier: CmsEntryModifier(expanded: true)` gives a field its own full-width row - use it for long text, media, large dropdowns.

## Rules

- **`entries` drives both the table and the form.** Don't have a separate "form schema" - adjust modifiers to control visibility per context.
- **`key` may be a dotted path.** Use it for nested JSON; don't flatten in the delegate.
- **Use `CmsBoolEntry` for toggle columns.** Not a custom `IconButton` per row.
- **Use `CmsDropdownEntry<T>` for closed sets.** Not free-text with validation.
- **Use `CmsEntryModifier`** for permissions / visibility / required - not conditionals around the entry.
- **Per-row buttons that *do something other than edit the row* belong in `customActions`,** not in entries. See [actions.md](actions.md).
- **Custom entries extend `CmsEntry<T>`.** Don't build a custom column by wrapping `CmsTextEntry` in widgets.

## Pitfalls

1. **`required: true` on a `pinned: false` field** still blocks submit even though the user might miss it visually in the overlay. Either set `required: false` or `pinned: true`.
2. **`sortable: true` on a dotted-path key** may not be supported by all delegates (Hasura yes; the stock Firebase delegate ignores sorting entirely as of v0.2.3 - see [delegates.md](delegates.md)). Verify with the delegate.
3. **Forgetting `flex: 1` on `id` columns.** Default flex is 2 - wasteful for short UUIDs.
4. **Type mismatch in `fromJson`.** Delegate returns dynamic JSON. If your numbers come back as `int` but the entry expects `double`, parsing fails. Add `fromJson` to coerce.
5. **`defaultValue` on `CmsDropdownEntry` not being a member of `values`** - the field renders blank. Seen in production, typically masked while `canCreate: false` and detonating later. Make sure the default exists in `values`.

## See also

- [table-page.md](table-page.md) - how entries are consumed
- [delegates.md](delegates.md) - where the data comes from
- [filters.md](filters.md) - the filter-side counterpart
- [media.md](media.md) - `CmsMediaEntry`
- [relationships.md](relationships.md) - `CmsToManyDropdownEntry`
- [management-sections.md](management-sections.md) - read-only sections for nested maps / lists of objects
