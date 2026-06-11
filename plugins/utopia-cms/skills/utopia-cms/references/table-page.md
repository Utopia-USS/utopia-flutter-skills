---
title: Table page
impact: CRITICAL
tags: table, paging, sorting, role-gating
---

# Skill: Table Page

`CmsTablePage` is the **entire CRUD page**: paged table + filters + sort + create
overlay + edit overlay + delete-with-confirmation. You hand it three things -
**delegate** (where data lives), **entries** (which columns/fields), and
**params** (what the user is allowed to do). Everything else is generated.

## Quick Pattern

### ❌ Anti-pattern

Custom `*_screen.dart` + `*_screen_state.dart` + `*_screen_view.dart` rendering
a `DataTable` and managing a `useState<List<T>?>` plus a hand-written service.
See [anti-patterns.md](anti-patterns.md).

### ✅ utopia_cms way

```dart
class UsersPage extends HookWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = useProvided<AuthState>();
    final isSuperAdmin = authState.role == 'SUPER_ADMIN';

    return CmsTablePage(
      title: 'Users',
      delegate: UserDelegate(...),                          // see delegates.md
      pagingLimit: 50,
      params: CmsTableParams(
        canCreate: isSuperAdmin,
        canEdit:   isSuperAdmin,
        canDelete: false,
        initialSortingParams: const CmsFunctionsSortingParams(sortDesc: true, fieldKey: 'created'),
      ),
      filterEntries: [
        CmsFilterSearchEntry(filterKeys: ['email', 'name'], entryKey: 'user_search', label: 'Search'),
      ],
      customActions: [
        CmsTableAction(
          label: 'Reset password',
          shouldUpdateTable: false,
          onPressed: (row) async {
            await service.resetPassword(row['email'] as String);
            return null;
          },
        ),
      ],
      entries: [
        CmsTextEntry(key: 'id',    label: 'ID',    flex: 1, modifier: CmsEntryModifier(initializable: false, editable: false)),
        CmsTextEntry(key: 'name',  label: 'Name',           modifier: CmsEntryModifier(sortable: true)),
        CmsTextEntry(key: 'email', label: 'Email',          modifier: CmsEntryModifier(sortable: true, editable: false)),
      ],
      managementSectionEntries: [
        // custom slivers in the create/edit overlay - see management-sections.md
      ],
    );
  }
}
```

## API

```dart
CmsTablePage({
  required CmsDelegate delegate,
  required String title,
  required List<CmsEntry<dynamic>> entries,
  CmsTableParams params = CmsTableParams.defaultParams,
  List<CmsFilterEntry<dynamic>>? filterEntries,
  List<CmsTableAction>? customActions,
  List<CmsManagementSectionEntry> managementSectionEntries = const [],
  int? pagingLimit = 25,                                 // must not be 0; null disables the limit
})
```

### `CmsTableParams`

```dart
CmsTableParams({
  bool canCreate = true,
  bool canEdit   = true,
  bool canDelete = true,
  CmsFunctionsSortingParams? initialSortingParams,
  Map<String, dynamic> initialFilterValues = const {},
})
```

- **`canCreate`** - show the "Create" button (opens the management overlay in create mode).
- **`canEdit`** - show the "Edit" action in row popup menu.
- **`canDelete`** - show "Delete" in row popup menu (uses `CmsDialog` for confirmation).
- **`initialSortingParams`** - initial sort state. Field must come from an entry whose modifier has `sortable: true` (and the delegate must support sorting by that field).
- **`initialFilterValues`** - pre-fill a filter (e.g. land on the page with `status == 'unverified'`).

### `CmsFunctionsSortingParams`

```dart
CmsFunctionsSortingParams({
  required bool sortDesc,
  bool invertNulls = false,
  required String fieldKey,
})
```

## Role-based gating

**Always** push role permissions into `CmsTableParams` and `CmsEntryModifier`,
not into a wrapper widget:

```dart
// ❌ bad
return Visibility(
  visible: isSuperAdmin,
  replacement: const ReadOnlyView(),
  child: CmsTablePage(...),
);

// ✅ good
return CmsTablePage(
  params: CmsTableParams(canEdit: isSuperAdmin, canCreate: isSuperAdmin, canDelete: false),
  entries: [
    CmsTextEntry(
      key: 'email',
      modifier: CmsEntryModifier(editable: isSuperAdmin, initializable: false),
    ),
    // …
  ],
);
```

The framework will:

- Hide the "Create" button when `canCreate == false`.
- Hide "Edit" / "Delete" from the row popup when the corresponding param is `false`.
- Render the field read-only in the edit overlay when `modifier.editable == false`.
- Show a field in the create flow when it is `editable` *or* `initializable` - `initializable: true` is what lets a set-once field (e.g. email) appear at creation despite `editable: false`. To hide a field from create entirely, set both to `false`.

### Capability getters, not role strings

Decode the role once at sign-in, expose intent-named booleans on your
app-level auth state, and let pages consume capabilities. Don't string-compare
roles inside entry lists:

```dart
enum Role { none, admin, superAdmin }

class AuthState {
  final Role role;
  // ...
  bool get canManageUsers => role != Role.none;
  bool get canEditUsers   => role == Role.superAdmin;
}

// In the page:
final auth = useProvided<AuthState>();
return CmsTablePage(
  // ...
  params: CmsTableParams(canCreate: false, canDelete: false, canEdit: auth.canEditUsers),
  entries: [
    CmsDropdownEntry<String>(
      key: 'role',
      values: const ['USER', 'MANAGER', 'SUPER_ADMIN'],
      valueLabelBuilder: (v) => v?.replaceAll('_', ' ') ?? '',
      modifier: CmsEntryModifier(editable: auth.canEditUsers, initializable: auth.canEditUsers),
    ),
  ],
);
```

Where the role comes from, with a Firebase-token + Hasura-claims backend:

```dart
// At sign-in - decode once, store on AuthState:
final token = await user.getIdTokenResult();
final claims = token.claims?['https://hasura.io/jwt/claims'] as Map<String, dynamic>?;
final role = claims?['x-hasura-default-role'] as String?;
```

Supabase-style backends do the same from the user's app metadata flags. Either
way, reject non-admin roles at sign-in (sign out + throw) so the panel never
renders for them - per-page gating is for distinguishing admin tiers, not for
keeping non-admins out.

The same capability flags flow into overlay sections (a section can take a
`canEdit` flag and render a "(read-only)" title variant) - see
[management-sections.md](management-sections.md).

## Pagination

`pagingLimit` controls the page size. The table uses infinite scroll
internally - when the user reaches the bottom, the next page is fetched via
`delegate.get(paging: CmsFunctionsPagingParams(offset: N, limit: pagingLimit))`.

Tune `pagingLimit` to your dataset:

- **25** - default; good for visually dense tables.
- **50** - small lookup tables (users, products) where everything fits in a couple of pages.
- **100+** - only when items are tiny and the delegate is cheap.
- **`null`** - paging turns off after the first fetch. Whether that fetch is unbounded depends on the delegate: Hasura sends no limit, the Supabase service falls back to 100 rows, Firebase ignores paging anyway. Tiny fixed collections only.

`pagingLimit: 0` is rejected by an assert.

## Known limitations (v0.2.3)

**Known limitation (v0.2.3):** there is no manual-refresh API - the table only
refetches when filters or sorting change and after overlay CRUD, so data can go
stale under realtime backends. Workarounds: a CRUD round-trip (any overlay save
resets and refetches), remounting the page with a new `key`, or nudging a
filter value (every filter change resets paging and refetches).

**Known limitation (v0.2.3):** offset-based paging can duplicate or skip rows
when the backend mutates between page fetches, a fetch cancelled by a filter /
sort change can still append its rows, and incoming rows are deduped against
everything already loaded with an O(n^2) scan - large tables can stutter. Keep
`pagingLimit` moderate and never pass `null` for big collections.

## Sorting

A column is sortable when **both** conditions hold:

1. Its entry has `CmsEntryModifier(sortable: true)`.
2. The delegate supports sorting by that field (Supabase and Hasura delegates do for top-level fields; the stock `CmsFirebaseDelegate.get` ignores sorting entirely as of v0.2.3 - override it, see [delegates.md](delegates.md)).

Set initial sort via `initialSortingParams: CmsFunctionsSortingParams(sortDesc: true, fieldKey: 'created')`.

## Initial filter values

When you want to land on a pre-filtered view (e.g. a "Pending approval" page
that is the same backend table as "All users" but filtered to
`status == 'unverified'`), you have two options:

1. **Subclass the delegate** and override `get(filter:)` to AND in a fixed filter (preferred when the filter is permanent - the user can't turn it off).
2. **`initialFilterValues`** when the filter is user-mutable but you want a default pre-selected.

See [filters.md](filters.md) for the filter algebra.

Either way, sibling pages over the same collection must share **one** entries
builder, parameterized by capability flags. Copy-pasted entry lists drift (a
modifier fixed on one page, forgotten on the other):

```dart
List<CmsEntry<dynamic>> buildOrderEntries({required bool canEditStatus}) => [
      CmsTextEntry(key: 'id', label: 'ID', flex: 1, modifier: const CmsEntryModifier(editable: false, initializable: false)),
      CmsTextEntry(key: 'customer_email', modifier: const CmsEntryModifier(sortable: true, editable: false)),
      // ...
    ];

// AllOrdersPage:     entries: buildOrderEntries(canEditStatus: auth.canEditOrders)
// PendingOrdersPage: entries: buildOrderEntries(canEditStatus: auth.canEditOrders)
```

## Composition with custom delegates

`CmsTablePage` is happy with *any* `CmsDelegate` - including subclasses that
wrap the prebuilt ones to add business logic. Common pattern:

```dart
class UserDelegate extends CmsSupabaseDelegate {
  static const _allowedUpdateKeys = {'name', 'surname', 'phone'};

  UserDelegate(super.supabaseService, {required super.client})
      : super(
          table: const CmsSupabaseDataTable('user'),
          archivedFilter: const CmsFilterNotEquals('archived', true),
        );

  @override
  Future<JsonMap> update(JsonMap value, _) async {
    // Only allow editing a subset of fields
    final filtered = JsonMap.fromEntries(
      value.entries.where((e) => e.key == table.idKey || _allowedUpdateKeys.contains(e.key)),
    );
    return supabaseService.updateById(client, table: table, object: filtered);
  }
}
```

The page itself doesn't change - only the delegate does. See [delegates.md](delegates.md).

## Rules

- **One `CmsTablePage` per admin "table" page.** A page is *the table*; don't wrap it in custom Scaffold/Padding/Card.
- **`entries` is the source of truth** for both columns and edit-form fields. The same list drives both - they aren't separate.
- **Role permissions go in `CmsTableParams` + `CmsEntryModifier`.** Not in conditionals around `CmsTablePage`.
- **Sorting requires modifier + delegate support.** Setting `sortable: true` alone won't work if the backend can't sort by that field.
- **Don't manually refetch after a save.** When the create/edit overlay saves, the table resets paging and refetches by itself. The `JsonMap` returned by `create`/`update` is *not* swapped into the table - it feeds `addOnSavedCallback` callbacks (see [management-sections.md](management-sections.md)), so return the authoritative saved row. In-place row updates exist only for `CmsTableAction` results with `shouldUpdateTable: true` (see [actions.md](actions.md)).
- **`pagingLimit` is a hint, not a strict cap.** It's the page size requested per fetch.
- **Use `initialFilterValues` for default filters** and `initialSortingParams` for default sort - both are part of `CmsTableParams`.

## Pitfalls

1. **Forgetting `flex` on an `id` column.** Default flex is 2, which is wasteful for short UUIDs. Use `flex: 1` and `CmsEntryModifier(initializable: false, editable: false)`.
2. **Setting `sortable: true` without backend support.** The header will become tappable but sort may silently fail. Check the delegate doc.
3. **Putting filter widgets in a custom widget above `CmsTablePage`.** Filters belong in `filterEntries`. The page renders them inside its own header.
4. **Mixing role logic inside `entries`.** Compute the capability booleans once at the top of `build()`, then pass to params/modifiers - don't recompute them inside each entry constructor.
5. **Adding a second create / edit screen by routing.** The page owns these - see `CmsManagementOverlay` referenced from [management-sections.md](management-sections.md).
6. **Copy-pasting an entries list across sibling pages.** Two pages over the same collection share one builder function (see "Initial filter values" above).

## See also

- [delegates.md](delegates.md) - the `delegate:` parameter
- [entries.md](entries.md) - the `entries:` and modifier flags
- [filters.md](filters.md) - the `filterEntries:` and filter algebra
- [actions.md](actions.md) - the `customActions:` parameter
- [management-sections.md](management-sections.md) - the `managementSectionEntries:` parameter
- [shell-cms-widget.md](shell-cms-widget.md) - where the table page is mounted
