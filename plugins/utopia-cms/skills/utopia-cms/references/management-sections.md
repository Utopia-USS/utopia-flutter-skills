---
title: Management sections
impact: HIGH
tags: management, overlay, sliver, nested
---

# Skill: Management Sections

`CmsManagementSectionEntry` lets you inject **custom UI into the create/edit
overlay** - anything that doesn't fit `CmsEntry` semantics: a nested
permissions matrix, a related-records list, a status panel, an audit log,
read-only metadata, etc. As of v0.3.0 the entry catalog has no type for nested
maps or lists of objects, so those columns are edited through sections too.

This is what lets `CmsTablePage` cover non-trivial admin flows without you
spawning a custom route per record.

## Quick Pattern

### ❌ Anti-pattern

A "View details" `IconButton` per row that opens a separate route with a
hand-rolled detail screen.

### ✅ utopia_cms way - sections inside the existing edit overlay

```dart
CmsTablePage(
  // …
  managementSectionEntries: [
    if (authState.canManagePermissions)
      _buildPermissionsSection(canEdit: authState.canEditPermissions),
    _buildLinkedDevicesSection(),
    _buildAuditLogSection(),
  ],
  // …
)

CmsManagementSectionEntry _buildPermissionsSection({required bool canEdit}) {
  return CmsManagementSectionEntry(
    title: canEdit ? 'Permissions' : 'Permissions (read-only)',
    sliverBuilder: (json, isEdit) {
      // json is the current row values ({} in create mode, never null in practice)
      return SliverToBoxAdapter(
        child: PermissionsMatrix(data: json ?? const {}, enabled: canEdit),
      );
    },
  );
}
```

Gate sections with capability booleans from your auth state (`canManageX` to
include the section at all, `canEditX` for a read-only variant) - see
role-based gating in [table-page.md](table-page.md).

## API

```dart
CmsManagementSectionEntry({
  required String title,
  bool showEdit   = true,   // visible when editing
  bool showCreate = false,  // visible when creating
  required Widget Function(JsonMap? json, bool isEdit) sliverBuilder,
});
```

- **`title`** - header above the sliver, themed automatically.
- **`showCreate: true`** - only flip this on if the section makes sense before the row exists (rare; usually edit-only).
- **`sliverBuilder`** - returns a `Sliver*` widget. `json` is the current row state - in create mode it's an empty map `{}` (not null), in edit mode it starts as the row from the table. `isEdit` is `true` in edit mode. The type is `JsonMap?` for historical reasons; in practice it's always a non-null map.

### Imports for coordinating sections

Any section that talks to the overlay needs two imports:

```dart
import 'package:provider/provider.dart';
import 'package:utopia_cms/utopia_cms.dart'; // CmsManagementBaseState and OnSavedCallback are public barrel exports (new in 0.3.0)
```

Resolve the state with `Provider.of<CmsManagementBaseState>(...)`, never
`useProvided` - the why is under "the overlay's state object" below.

## Responsive overlay (new in 0.3.0)

`CmsManagementView` resolves a `CmsPageType` via `CmsPageWrapper` and adapts
its layout automatically: on mobile it renders as a full-screen page that slides
up from the bottom (single column, tighter padding); on tablet and web it slides
in from the right as a constrained panel, leaving the table partially visible
behind the barrier. No configuration is needed - the overlay adapts to the
viewport width.

## Five common shapes

### 1. Read-only data panel

```dart
CmsManagementSectionEntry(
  title: 'Linked devices',
  sliverBuilder: (json, _) {
    final devices = (json?['linked_devices'] as Map?) ?? {};
    if (devices.isEmpty) {
      return const SliverToBoxAdapter(child: Text('No devices linked.'));
    }
    return SliverList.builder(
      itemCount: devices.length,
      itemBuilder: (_, index) => _deviceRow(devices.values.toList()[index]),
    );
  },
)
```

Pure display - no mutations to persist. Often used for server-derived data.

When the panel joins the row against reference data (id -> name lookups),
don't fetch the lookup per overlay open. Register one app-level state
(`useAutoComputedState`, gated with `shouldCompute`) in your utopia_hooks
provider container and resolve it inside the section:

```dart
sliverBuilder: (json, _) => HookBuilder(builder: (context) {
  final lookup = useProvided<DeviceLookupState>(); // app-level utopia_hooks state - useProvided IS correct here
  final ids = ((json?['linked_devices'] as Map?) ?? const {}).keys.toList();
  return SliverList.builder(
    itemCount: ids.length,
    itemBuilder: (_, i) => Text(lookup.endpointFor(ids[i])),
  );
}),
```

### 2. Cross-cutting save (`addOnSavedCallback`)

When the section *does* mutate something on save, hook into the overlay's save
flow via `CmsManagementBaseState`:

```dart
CmsManagementSectionEntry(
  title: 'Roles',
  sliverBuilder: (json, _) {
    return HookBuilder(builder: (context) {
      final baseState = Provider.of<CmsManagementBaseState>(context, listen: false);
      final selectedState = useState<Set<String>>(_initialRoles(json));

      // Register a callback that runs when the user clicks "Update" / "Create"
      useEffect(() {
        baseState.addOnSavedCallback((row) async {
          await userService.setRoles(row['id'] as String, selectedState.value);
        });
        return null;
      }, const []);

      return SliverToBoxAdapter(child: RolesPicker(value: selectedState.value, onChanged: (v) => selectedState.value = v));
    });
  },
)
```

- `Provider.of<CmsManagementBaseState>(context, listen: false)` - the write-only handle.
- `baseState.addOnSavedCallback((row) async { … })` - runs after the delegate save succeeds; `row` is the `JsonMap` returned by `delegate.create`/`update`, which is why delegates must return the authoritative saved row.
- `baseState.values` / `baseState.onValueChanged(key, value)` - read/write the row map directly.

### 3. Related-records list

```dart
CmsManagementSectionEntry(
  title: 'Attachments',
  sliverBuilder: (json, isEdit) {
    return HookBuilder(builder: (context) {
      final attachments = useMemoizedFuture(
        () => api.listAttachments(json?['id']),
        keys: [json?['id']],
      );
      return SliverList.builder(
        itemCount: attachments.data?.length ?? 0,
        itemBuilder: (_, i) => AttachmentTile(attachments.data![i]),
      );
    });
  },
)
```

Loads its own data; lives entirely within the section.

### 4. Nested-collection editor (`onValueChanged`)

When the row has an array or nested-object column, the section *is* the form
for that column. Keep local hook state for editing and mirror **every**
mutation into the overlay via `onValueChanged` - the built-in Save button then
persists the column through the page's delegate with zero extra save plumbing:

```dart
CmsManagementSectionEntry(
  title: 'Items',
  showCreate: true,
  sliverBuilder: (json, _) => ItemListSection(initialJson: json),
)

class ItemListSection extends HookWidget {
  final JsonMap? initialJson;
  const ItemListSection({super.key, required this.initialJson});

  @override
  Widget build(BuildContext context) {
    final baseState = Provider.of<CmsManagementBaseState>(context, listen: false); // write-only handle
    final itemsState = useState<List<Item>>(Item.listFromJson(initialJson?['items'])); // seeded once per mount

    void push(List<Item> updated) {
      itemsState.value = updated;
      baseState.onValueChanged('items', [for (final e in updated) e.toJson()]); // Save persists it
    }

    return SliverList.builder(
      itemCount: itemsState.value.length,
      itemBuilder: (_, i) => ItemEditorRow(
        key: ValueKey(itemsState.value[i].id), // text fields keep identity across inserts/removals
        item: itemsState.value[i],
        onChanged: (item) => push([...itemsState.value]..[i] = item),
        onRemoved: () => push([...itemsState.value]..removeAt(i)),
      ),
    );
  }
}
```

- `onValueChanged` writes *into* the row map; the value rides the normal Save -> `delegate.create`/`update` path. Use it for anything stored **in** the row. `addOnSavedCallback` is only for writes **outside** the row (other tables, RPCs).
- Key the rows (`ValueKey(item.id)`) so text fields survive inserts/removals; reach for `TextEditingController`s when a button must programmatically replace visible text.

### 5. Live preview panel (listening `Provider.of`)

A read-only panel that re-renders as the user edits other fields: subscribe
with a *listening* `Provider.of` and derive straight from `baseState.values` -
no button, no local copy. The overlay re-provides a fresh state object on
every change, so listeners rebuild live as you type:

```dart
CmsManagementSectionEntry(
  title: 'Preview',
  sliverBuilder: (_, __) => const LivePreviewSection(),
)

class LivePreviewSection extends StatelessWidget {
  const LivePreviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final values = Provider.of<CmsManagementBaseState>(context).values; // listening read -> rebuilds per edit
    final items = (values['items'] as List?) ?? const [];
    return SliverToBoxAdapter(child: PreviewCard(items: items));
  }
}
```

Rule of thumb: **listening reads, non-listening writes.** `listen: true` for
reactive derivations (previews, computed hints); `listen: false` for
imperative pushes (`onValueChanged`, `addOnSavedCallback`) so an editor
section doesn't rebuild from its own writes.

## Sections that save themselves

Some sections must persist immediately on change (permission toggles, role
dropdowns) instead of riding the overlay's Save. Give the section its own
submit path - `useSubmitState` from utopia_hooks - and guard against no-op
submits, because nothing here passes through Save or `addOnSavedCallback`:

```dart
CmsManagementSectionEntry(
  title: 'Role', // edit-only by default (showCreate: false)
  sliverBuilder: (json, _) {
    final row = json!; // non-null in practice; 'id' present because the section is edit-only
    return HookBuilder(builder: (context) {
      final submitState = useSubmitState();
      final currentState = useState(row['role'] as String? ?? 'USER');
      final errorState = useState<String?>(null);

      Future<void> onChanged(String role) => submitState.runSimple<void, String>(
            shouldSubmit: () => role != currentState.value, // no-op guard
            beforeSubmit: () => errorState.value = null,
            submit: () async {
              await userService.updateRole(row['id'] as String, role); // own RPC, not the row delegate
              currentState.value = role;
            },
            mapError: (e) => e is CmsDelegateException ? e.message : null,
            afterKnownError: (message) => errorState.value = message,
          );

      return SliverToBoxAdapter(
        child: Row(children: [
          RolePicker(value: currentState.value, enabled: !submitState.inProgress, onChanged: onChanged),
          if (submitState.inProgress) const CmsLoader(),
          if (errorState.value != null) Expanded(child: Text(errorState.value!)),
        ]),
      );
    });
  },
)
```

`CmsDelegateException` is the package's "show this message" error type - the
overlay's own Save maps it the same way, so your service layer can throw it
for both paths. The Save button is unaffected: a self-saving section neither
blocks nor is blocked by it.

## `CmsManagementBaseState` - the overlay's state object

```dart
abstract class CmsManagementBaseState {
  abstract final JsonMap values;
  abstract final void Function(String key, Object? value) onValueChanged;
  abstract final void Function(OnSavedCallback action) addOnSavedCallback; // OnSavedCallback = Future<void> Function(JsonMap)
}
```

The save button label is contextual (new in 0.3.0): `"Update"` when editing an
existing item, `"Create"` when creating a new one. Header text follows the same
logic: `"Manage item"` / `"Item details"` in edit mode, `"Create new"` in create
mode.

Available inside the overlay via Provider. Use it when your section needs to:

- React to other fields in the row (`values.getAtPath('email')`).
- Update fields outside the normal `CmsEntry` flow (`onValueChanged('extra.flag', true)`).
- Hook into the save flow (`addOnSavedCallback`).

### `Provider.of`, never `useProvided`

The overlay provides this state via **package:provider**
(`Provider<CmsManagementBaseState>.value`). utopia_hooks' `useProvided` only
resolves utopia_hooks `ProviderWidget` ancestors and throws
`ProvidedValueNotFoundException` otherwise - so inside the overlay it always
crashes for this type. The two provider systems coexist: *app-level* states
registered in your utopia_hooks container (auth, lookup caches) are still
resolved with `useProvided<T>()` inside a `HookBuilder` section; only the
overlay's own state goes through `Provider.of`.

> **Fixed in 0.3.0:** the stock `CmsMediaEntry` and `CmsToManyDropdownEntry` edit
> fields previously resolved this state with `useProvided` and would throw inside
> the overlay. Both now use `Provider.of<CmsManagementBaseState>` and work
> correctly. The rule still applies to your own overlay code: use `Provider.of`,
> never `useProvided`, for `CmsManagementBaseState`.

For relationship-style overlays, this is also where `CmsToManyDropdownEntry`
plugs in (see [relationships.md](relationships.md)).

## Rules

- **Custom UI in the edit flow = `CmsManagementSectionEntry`.** Don't add a separate route.
- **Section UI is sliver-based.** Return `SliverToBoxAdapter`, `SliverList`, `SliverPadding`, etc. - not plain widgets.
- **Resolve the overlay state with `Provider.of<CmsManagementBaseState>`, never `useProvided`.** `listen: false` for writes, listening for reactive reads.
- **Writes into the row go through `onValueChanged`; writes outside the row through `addOnSavedCallback`.** Don't store them in the section's local state and try to commit on dismiss.
- **Sections do not replace `CmsEntry`.** If the data is a flat field, use a `CmsEntry`; sections are for *non-form* UI and nested data.
- **`showCreate: false` is the right default.** Most sections relate to an already-existing row.

## Pitfalls

1. **Returning a non-sliver widget.** `SliverList.builder` etc. - wrap plain widgets in `SliverToBoxAdapter`.
2. **Storing state in the section's local hook without hooking it to save.** State is lost when the overlay closes; use `onValueChanged` (to commit into the row map) or `addOnSavedCallback` (to commit on save).
3. **Side effects that should run before save.** `addOnSavedCallback` runs *after* the delegate save succeeds. If you need pre-save validation, use a `CmsEntry` with `required: true` instead, or fail loudly in the delegate.
4. **Putting heavy network reads in every section.** All sections render in the overlay - a slow section makes editing painful. Cache via `useMemoizedFuture` and key by row id, or share an app-level lookup state (shape 1).
5. **Using the section to navigate away.** Don't push routes from inside the overlay; that's the wrong shape.
6. **Resolving the overlay state with `useProvided<CmsManagementBaseState>()`.** Throws `ProvidedValueNotFoundException` - it's a package:provider value, see the rules above.
7. **Last section hidden behind the floating button bar.** Save/Delete float *over* the scroll view; v0.3.0 ends the scroll view with a fixed 100 px spacer, but a visible error message or a dense final section can still slip under the gradient. Workaround: append a trailing spacer section, e.g. `CmsManagementSectionEntry(title: '', showCreate: true, sliverBuilder: (_, __) => const SliverToBoxAdapter(child: SizedBox(height: 120)))`.

## See also

- [table-page.md](table-page.md) - `managementSectionEntries` parameter and role gating
- [entries.md](entries.md) - flat-field edit UI
- [relationships.md](relationships.md) - to-many editing flows
- [actions.md](actions.md) - per-row actions vs. overlay sections
