---
title: Filters (CmsFilterEntry + CmsFilter algebra)
impact: HIGH
tags: filter, search, query
---

# Skill: Filters (Filter Entries and Filter Algebra)

Two distinct concepts:

- **`CmsFilterEntry`** - *UI* for a filter (a search field, a date bound, etc.) rendered above the table. List items in `CmsTablePage(filterEntries: …)`.
- **`CmsFilter`** - *server* filter algebra (`.equals`, `.containsString`, `.and`, …) passed to the delegate's `get`. Filter entries produce these; you also use them directly when subclassing delegates.

## Quick Pattern

### ❌ Anti-pattern

A `TextField` above the table that triggers a `useState<String>` that filters
the already-fetched list on the client. (Doesn't scale; loses paging; reinvents
the framework.)

### ✅ utopia_cms way

```dart
CmsTablePage(
  // …
  filterEntries: [
    CmsFilterSearchEntry(
      filterKeys: ['name', 'surname', 'email', 'phone'],
      entryKey: 'user_search',
      label: 'Search',
    ),
    // One CmsFilterDateEntry = ONE bound. A range needs a pair:
    CmsFilterDateEntry(filterKeys: ['created'], entryKey: 'created_from', label: 'Joined from'),                                   // >= (default)
    CmsFilterDateEntry(filterKeys: ['created'], entryKey: 'created_to', label: 'Joined to', mode: CmsFilterDateEntryMode.lesser),  // <=
  ],
  // …
)
```

The framework converts entries → `CmsFilter` → delegate's `get(filter:)` →
backend query. Paging and sorting continue to work.

## Built-in filter entries

### `CmsFilterSearchEntry`

```dart
CmsFilterSearchEntry({
  required List<String> filterKeys,                              // fields to search across (OR-ed)
  required String entryKey,                                      // identity for internal state
  String? label,
  List<TextInputFormatter>? formatters,
  int flex = 4,
})
```

- **Single key** → produces `CmsFilterContains(filterKeys.first, value, caseSensitive: false)`.
- **Multiple keys** → produces `CmsFilterOr([for k in filterKeys: CmsFilterContains(k, value)])`.
- The `filterKeys` may be dotted paths (`contactData.name`) when the delegate supports it.

### `CmsFilterDateEntry`

A **single** date picker producing **one** bound - not a range picker.

```dart
CmsFilterDateEntry({
  required List<String> filterKeys,
  required String entryKey,
  String? label,
  int flex = 2,
  CmsFilterDateEntryMode mode = CmsFilterDateEntryMode.greater,    // greater | lesser
  CmsFilterDateEntryUnit unit = CmsFilterDateEntryUnit.dateTime,   // how the picked DateTime serializes
})
```

- **`mode:`** picks the comparison: `greater` (default) produces `CmsFilterGreaterOrEq(field, date)`; `lesser` produces `CmsFilterLesserOrEq(field, date)`.
- A date **range** ("joined between A and B") = two entries on the same `filterKeys` with distinct `entryKey`s and opposite modes; filter entries are AND-ed together:

```dart
CmsFilterDateEntry(filterKeys: ['created'], entryKey: 'created_from', label: 'From'),
CmsFilterDateEntry(filterKeys: ['created'], entryKey: 'created_to', label: 'To', mode: CmsFilterDateEntryMode.lesser),
```

- **`unit:`** matches backends that store epoch numbers instead of timestamps: `dateTime` (string), `secondsSinceEpoch`, `millisecondsSinceEpoch`, `microsecondsSinceEpoch`. With the wrong unit the filter silently compares date strings against epoch columns and matches nothing.
- As of v0.2.3, keep `filterKeys` to a single key: the multi-key OR branch has an upstream bug that applies `filterKeys.first` for every key.

## The `CmsFilter` algebra

`CmsFilter` is a sealed union with constructors for equality, comparison, containment, list
membership, and logical composition (`all`, `and`, `or`, `not`). Compose filters with operators:

```dart
filter & other;    // AND
filter | other;    // OR
~filter;           // NOT (with De Morgan distribution)
```

Common uses:

```dart
const archived = CmsFilterNotEquals('archived', true);
const adminsOnly = CmsFilterEquals('role', 'admin');
final combined = archived & adminsOnly;                                                // archived AND admins

const verified = CmsFilterInList('status', ['verified', 'super_verified']);
final search = CmsFilterContains('email', '@example.com', caseSensitive: false);
final query = (verified & search) | CmsFilterEquals('id', 'special-id');
```

### NULL and NOT filters

**Known limitation (v0.2.3):** "field is not null" has no reliable expression. `CmsFilter.notEquals(field, null)` type-checks (`value` is `Object?`), but the backend delegates don't turn it into an "is not null" query, and on the Supabase backend the paths that could express null checks are runtime-broken: `CmsFilterEquals(field, null)` and `CmsFilterNot(...)` hit `CmsSupabaseService` calls whose arity doesn't match postgrest 2.x (`isFilter` / `not` invoked on a dynamic builder), throwing `NoSuchMethodError`. Workaround: push null-based constraints into a custom delegate's `get()` override - apply `.not('col', 'is', null)` directly on the Supabase query builder, or read from a pre-filtered DB view.

## Custom filter entries

Build one when the built-ins don't fit (an enum dropdown, a multi-select, a
boolean toggle). The full member set: `filterKeys`, `entryKey`, `label`, `flex`,
`buildField`, `filterFromValues`. A dropdown filter over an enum-ish column:

```dart
const kStatuses = ['draft', 'published', 'archived'];

class StatusFilterEntry extends CmsFilterEntry<String?> {
  @override final List<String> filterKeys = const ['status'];
  @override final String entryKey = 'status';
  @override final String? label = 'Status';
  @override final int flex = 2;

  @override
  Widget buildField({required BuildContext context, required String? value, required void Function(String?) onChanged}) {
    return CmsFieldWrapper(                                        // inherit the built-in field chrome
      child: DropdownButton<String?>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        onChanged: onChanged,
        items: [
          const DropdownMenuItem(child: Text('All')),              // value: null -> "no filter"
          for (final s in kStatuses) DropdownMenuItem(value: s, child: Text(s)),
        ],
      ),
    );
  }

  @override
  CmsFilter filterFromValues(JsonMap value) {
    final selected = value.getAtPath(entryKey) as String?;
    return selected == null ? const CmsFilterAll() : CmsFilterEquals(filterKeys.first, selected);
  }
}
```

`CmsFilterAll()` is the escape hatch for "nothing selected" - it is the AND
identity, so the table fetches unfiltered. For a multi-select, type the entry
`CmsFilterEntry<List<String>?>`, return `CmsFilterInList(filterKeys.first, selected)`,
and override `toJson` / `fromJson` to cast the stored list.

The framework stores the field's value in the page's internal filter map
under `entryKey`, renders `buildField` above the table, and calls
`filterFromValues` to produce the server filter (entries are AND-ed together).

## Implementing a custom delegate's `get(filter:)`

When you implement `CmsDelegate` for an unsupported backend, you translate
`CmsFilter` into your backend's query format. Use the `freezed` union helpers:

```dart
String _filterToQuery(CmsFilter filter) {
  return filter.when(
    all:            ()                    => 'true',
    equals:         (f, v)                => '$f = ${_lit(v)}',
    notEquals:      (f, v)                => '$f != ${_lit(v)}',
    containsString: (f, v, cs)            => '$f LIKE ${_lit(_wildcard(v))}',
    inList:         (f, values)           => '$f IN (${values.map(_lit).join(', ')})',
    greaterOrEq:    (f, v)                => '$f >= ${_lit(v)}',
    lesserOrEq:     (f, v)                => '$f <= ${_lit(v)}',
    and:            (filters)             => filters.map(_filterToQuery).join(' AND '),
    or:             (filters)             => filters.map(_filterToQuery).join(' OR '),
    not:            (f)                   => 'NOT (${_filterToQuery(f)})',
  );
}
```

The prebuilt delegates do this for you in their respective backends.

## Pre-filtering - when to use what

| Goal | Where it goes |
|------|---------------|
| Always-on filter (archive flag, tenant isolation) | Subclass the delegate; AND into `get` or use `archivedFilter` |
| User-toggleable filter the user controls | `CmsFilterEntry` |
| Default value for a user-toggleable filter | `CmsTableParams(initialFilterValues: {entryKey: defaultValue})` |
| "Two views of the same table" (e.g. "Pending approval" vs "All users") | Subclass the delegate twice with different fixed filters; expose as two `CmsWidgetItem.page`s |

## Rules

- **Filters run server-side via the delegate.** Don't filter the page-rendered list in widget code.
- **One `CmsFilterEntry` per filter widget.** Don't pack two filters into one entry.
- **`filterKeys` may be dotted paths** when the delegate supports them (Hasura yes; the stock Firebase delegate ignores filters entirely as of v0.2.3 - see [delegates.md](delegates.md)).
- **Use the `&` / `|` / `~` operators** when composing filters in code - they distribute / dedup naturally.
- **`CmsFilterAll` is the identity** for AND; use it to short-circuit "no filter selected."
- **Always-on filters belong on the delegate**, not as a hidden `CmsFilterEntry`.

## Pitfalls

1. **Forgetting to AND the user's filter with your always-on filter** when overriding `get`. Always do `CmsFilterAnd([fixed, filter])`, not just `fixed`.
2. **`CmsFilterContains` with case-sensitive default**. Default is `false` - fine for human-readable searches. Override only when needed.
3. **Filtering on a field that isn't indexed** on the backend can be slow. Especially Firestore - composite indexes are required for some `AND` / `OR` patterns.
4. **Numeric strings in `CmsFilterEquals`.** If the field is numeric in the backend but a String in the JSON, the equality check will fail. Coerce upstream.
5. **Date filters with timezones.** `CmsFilterDateEntry` works in local time; if your backend stores UTC, the boundary day may be off-by-one. Adjust in the custom entry's `filterFromValues`.
6. **`CmsFilterDateEntry` with the default `unit:` against an epoch column.** The picked date serializes as a string; set `unit:` to the epoch flavor the column stores, or the filter matches nothing.

## See also

- [delegates.md](delegates.md) - where filters land
- [table-page.md](table-page.md) - `filterEntries`, `initialFilterValues`
- [entries.md](entries.md) - column entries (separate concept!)
