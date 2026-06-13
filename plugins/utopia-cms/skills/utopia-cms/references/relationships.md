---
title: Relationships with CmsToManyDelegate and CmsToManyDropdownEntry
impact: MEDIUM
tags: relationships, to-many, one-to-many, many-to-many
---

# Skill: Relationships

For a "user has many tags" or "product belongs to many categories" relationship,
the framework offers `CmsToManyDelegate` (server-layer for relationship CRUD)
and `CmsToManyDropdownEntry` (UI for picking related items).

## Quick Pattern

```dart
// Many-to-many: user ↔ tag via user_tag association
final userTagDelegate = CmsSupabase.instance.manyToManyDelegate(
  client: supabase,
  associationTable: const CmsSupabaseAssociationTable(
    'user_tag',
    originTable:  CmsSupabaseDataTable('user'),
    foreignTable: CmsSupabaseDataTable('tag'),
    originKey:    'user_id',
    foreignKey:   'tag_id',
  ),
);

// One-to-many: user → posts (foreign key `user_id` on posts)
final userPostsDelegate = CmsSupabase.instance.oneToManyDelegate(
  client: supabase,
  originTable:  const CmsSupabaseDataTable('user'),
  foreignTable: const CmsSupabaseDataTable('post'),
  foreignKey:   'user_id',
);

// Plug into an entry that lives in the edit overlay
CmsToManyDropdownEntry(
  delegate: userTagDelegate,
  filterFields: const ['name'],
  fieldDisplayBuilder: (tag) => tag['name'] as String,
  previewDisplayBuilder: (tag) => tag['name'] as String,
  label: 'Tags',
)
```

## API

### `CmsToManyDelegate`

```dart
abstract class CmsToManyDelegate {
  abstract final String originIdKey, foreignIdKey;

  Future<List<JsonMap>> get({Object? originId, CmsFilter filter});

  Future<void> update({
    required Object originId,
    required ISet<Object> addedForeignIds,
    required ISet<Object> removedForeignIds,
  });
}
```

- `get(originId: null)` → all options (for the picker).
- `get(originId: id)`  → already-related items (for display / preselection).
- `update(originId:, addedForeignIds:, removedForeignIds:)` → diff-based commit.

Prebuilt impls (Supabase / Hasura):

- `CmsSupabaseOneToManyDelegate`  / `CmsHasuraOneToManyDelegate`
- `CmsSupabaseManyToManyDelegate` / `CmsHasuraManyToManyDelegate`

Construct them via the `CmsSupabase.instance` factories (Quick Pattern above)
or the `CmsHasura.instance` factories (below). All four accept an optional
`archivedFilter` (see "Soft delete in pickers" below).

### `CmsToManyDropdownEntry`

```dart
CmsToManyDropdownEntry({
  required CmsToManyDelegate delegate,
  required List<String> filterFields,                                  // server search fields
  required String Function(JsonMap) fieldDisplayBuilder,               // in the edit dropdown
  String Function(JsonMap)? previewDisplayBuilder,                     // in the table preview
  required String label,
  CmsEntryModifier modifier = const CmsEntryModifier(pinned: false),
  int flex = 4,
})
```

- The entry's `key` is derived from `delegate.originIdKey` automatically.
- `filterFields` enables typeahead search inside the dropdown - the picker calls `delegate.get` with an OR of case-insensitive `CmsFilter.containsString(field, query)` filters over these fields.
- `fieldDisplayBuilder` controls the label *inside the dropdown picker*.
- `previewDisplayBuilder` controls the label *inside the table cell* (falls back to `fieldDisplayBuilder` if null).

**Known limitation (v0.2.3):** the stock `CmsToManyDropdownEntry` edit field
resolves the overlay's `CmsManagementBaseState` with utopia_hooks'
`useProvided`, but the overlay provides it via `package:provider` - the lookup
can throw `ProvidedValueNotFoundException` when the field mounts (the stock
`CmsToManyDropdownField` performs the same lookup internally, so wrapping it
doesn't help). If you hit it, the workaround is a custom entry that obtains
the state with `Provider.of<CmsManagementBaseState>(context, listen: false)`,
registers the diff-update via `addOnSavedCallback`, and renders its own
multi-select; see media.md for the deep-import path. The same rule applies to
all your own overlay code: always `Provider.of`, never `useProvided`.

## Hasura factories

Same shapes as Supabase plus one extra **required** parameter:
`foreignFields` - the GraphQL projection of the foreign table selected by
every picker query. `CmsGraphQLFields` is a `Set<CmsGraphQLField>` from
`utopia_cms_graphql`.

```dart
// Many-to-many: article ↔ tag via article_tag association
final articleTagDelegate = CmsHasura.instance.manyToManyDelegate(
  client: client,                                   // GraphQLClient
  associationTable: const CmsHasuraAssociationTable(
    'article_tag',
    originTable:  CmsHasuraDataTable('article'),
    foreignTable: CmsHasuraDataTable('tag'),
    originKey:    'article_id',
    foreignKey:   'tag_id',
  ),
  foreignFields: const {CmsGraphQLField('id'), CmsGraphQLField('name')},
);

// One-to-many: article → comments (foreign key `article_id` on comment)
final articleCommentsDelegate = CmsHasura.instance.oneToManyDelegate(
  client: client,
  originTable:   const CmsHasuraDataTable('article'),
  foreignTable:  const CmsHasuraDataTable('comment'),
  foreignKey:    'article_id',
  foreignFields: const {CmsGraphQLField('id'), CmsGraphQLField('body')},
);
```

- **`foreignFields` must include the foreign id key** (`id` here):
  preselection, diffing, and the dropdown's `compareFn` all read it from every
  fetched row.
- **Many-to-many schema requirement:** preselected values are fetched by
  querying the foreign table with
  `where: {article: {article_id: {_eq: <originId>}}}` - the filter path is
  `'<originTable.name>.<originKey>'`, so the foreign table needs a Hasura
  relationship *named after the origin table* that reaches the association
  rows. Without it the query fails validation and nothing is preselected.
- `CmsHasuraDataTable(name, {idKey = 'id'})` has no `schema` parameter, unlike
  its Supabase counterpart.

## Soft delete in pickers: archivedFilter

All four to-many factories (Supabase and Hasura, one-to-many and many-to-many)
take `archivedFilter: CmsFilterNotEquals?`. It is AND-ed into *every* `get`
the delegate performs, so archived rows vanish from both the picker options
and the preselected values:

```dart
final articleTagDelegate = CmsHasura.instance.manyToManyDelegate(
  // ... as above ...
  archivedFilter: const CmsFilterNotEquals('archived', true),
);
```

If the related table soft-deletes via `archivedFilter` on its main delegate
(see delegates.md), pass the same filter here - otherwise archived rows keep
appearing in every relationship picker.

## Both directions: reversed

Both association-table classes expose a `reversed` getter - the same
association with origin/foreign tables and keys swapped. Define it once and
offer the picker on both pages instead of hand-swapping a duplicate
definition:

```dart
const userTag = CmsSupabaseAssociationTable(
  'user_tag',
  originTable:  CmsSupabaseDataTable('user'),
  foreignTable: CmsSupabaseDataTable('tag'),
  originKey:    'user_id',
  foreignKey:   'tag_id',
);

// user page: tags picker
CmsSupabase.instance.manyToManyDelegate(client: supabase, associationTable: userTag);
// tag page: users picker
CmsSupabase.instance.manyToManyDelegate(client: supabase, associationTable: userTag.reversed);
```

## Where the entry lives

`CmsToManyDropdownEntry` is a normal `CmsEntry` - pass it in `entries`. The
edit overlay renders the picker; the table preview renders the comma-separated
list of related items. The `update` call is sent via the to-many delegate, not
the main row delegate, and it's diff-based (added/removed sets), so you don't
need to reconcile state manually. It runs *after* the row itself saves: the
field registers a saved callback and reads `originId` from the saved row, so
it works on create as well (your delegate's `create` must return the new row
including its id).

For more complex relationship UIs (a sortable join with extra fields per
relation, e.g. "user has many tasks with priority"), use a
`CmsManagementSectionEntry` and orchestrate the saves via `addOnSavedCallback`.
See [management-sections.md](management-sections.md).

## Rules

- **For closed sets (small, static):** prefer `CmsDropdownEntry<T>` - it doesn't talk to the backend.
- **For open sets (looked up from another table):** `CmsToManyDropdownEntry` + a `CmsToManyDelegate`.
- **For relations with extra data** (e.g. priority, role per assignment), use `CmsManagementSectionEntry` + `addOnSavedCallback` to handle the bespoke save logic.
- **Use the prebuilt many-to-many / one-to-many delegates** - Hasura and Supabase have them. Implement only when you need a custom backend.
- **Soft-deleted related rows:** pass the same `archivedFilter` you use on the related table's main delegate to the to-many factory, or archived rows show up in pickers.

## See also

- [delegates.md](delegates.md) - primary row delegate
- [entries.md](entries.md) - the entry catalog
- [filters.md](filters.md) - `CmsFilter` constructors (`archivedFilter` takes a `CmsFilterNotEquals`)
- [management-sections.md](management-sections.md) - for relationship UIs that go beyond a multi-select
