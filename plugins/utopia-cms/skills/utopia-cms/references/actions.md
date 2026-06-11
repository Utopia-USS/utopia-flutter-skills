---
title: Row actions (CmsTableAction, per-row popup menu)
impact: HIGH
tags: action, popup, row
---

# Skill: Row Actions

`CmsTableAction` adds a **custom action to the row popup menu** - anything
beyond the built-in "Edit" / "Delete." Examples: "Reset password," "Approve,"
"Reject," "Send invite," "Move up."

## Quick Pattern

### ❌ Anti-pattern

Two `IconButton`s per row rendered into an "Actions" column, each hand-wiring
its own state updates and refetches.

### ✅ utopia_cms way

```dart
customActions: [
  CmsTableAction(
    label: 'Reset password',
    shouldUpdateTable: false,
    onPressed: (row) async {
      await service.resetPassword(row['email'] as String);
      return null;
    },
  ),
  CmsTableAction(
    label: 'Approve',
    shouldUpdateTable: true,
    onPressed: (row) async {
      final updated = {...row, 'status': 'APPROVED'};  // copy - never mutate `row`
      return delegate.update(updated, row);            // return the delegate's result
    },
  ),
  CmsTableAction(
    label: 'Reject',
    shouldUpdateTable: true,
    onPressed: (row) async {
      final updated = {...row, 'status': 'REJECTED'};
      return delegate.update(updated, row);
    },
  ),
]
```

The popup menu appears on every row. The action's `onPressed` receives the row
`JsonMap` and returns either the updated row (which the table swaps in-place)
or `null`.

## API

```dart
CmsTableAction({
  required String label,
  required bool shouldUpdateTable,                                   // true → swap row with return value
  required Future<JsonMap?> Function(JsonMap value) onPressed,
})
```

- **`label`** - what appears in the popup menu.
- **`shouldUpdateTable: false`** - fire-and-forget side effect (send email, archive, log audit). `onPressed` can return `null`.
- **`shouldUpdateTable: true`** - the action returns the updated row, the table swaps it in-place without refetching. `onPressed` typically calls `delegate.update`.
- **`onPressed(row)`** - `row` is the **live map backing the table row**, not a copy (as of v0.2.3 the framework passes its stored map straight through). Never mutate it in place: build a copy (`{...row, 'status': ...}`), send the copy to the delegate, and return the updated map. Returning `null` skips the swap.

## When to use what

| Scenario | Approach |
|----------|----------|
| "Reset password" (side effect, no row change) | `CmsTableAction(shouldUpdateTable: false)` |
| "Approve user" (changes the row in DB) | `CmsTableAction(shouldUpdateTable: true)` returning updated row |
| "View analytics" (standalone dashboard screen) | `CmsTableAction(shouldUpdateTable: false)` that navigates and returns `null` - see "Navigation actions" |
| "Edit this row" | Don't - that's `CmsTableParams(canEdit: true)` and the built-in edit overlay |
| "Delete this row" | Don't - that's `CmsTableParams(canDelete: true)` |
| "Visibility toggle" (1-click inline) | Don't - use `CmsBoolEntry(key: 'isVisible')` instead |
| "Bulk operations across rows" | Not a per-row action - exposed as a dedicated `CmsWidgetItem.page` or page-level button (advanced) |

## Confirmation dialogs

The built-in Delete flow confirms automatically with the framework's themed
dialog. Custom destructive actions bring their own dialog via `showDialog`:

**Known limitation (v0.2.3):** `CmsDialog`, the themed confirm dialog used by
the built-in delete flow, is internal - it is not exported from
`package:utopia_cms/utopia_cms.dart`, and `src/` deep imports are forbidden.
Use `showDialog` with your own confirm widget.

```dart
CmsTableAction(
  label: 'Reject',
  shouldUpdateTable: true,
  onPressed: (row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this application?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true) return null;                              // null → no update, no swap
    final updated = {...row, 'status': 'REJECTED'};
    return delegate.update(updated, row);
  },
),
```

`context` here is the page `HookWidget`'s build context, captured by the
closure. After any `await` inside `onPressed`, check `context.mounted` before
touching the context again - the page can be disposed while the action runs.

## Combining with delegate methods

`CmsTableAction.onPressed` has direct access to whichever delegate you
constructed locally. Common pattern - a shared status helper:

```dart
class PendingUsersPage extends HookWidget {
  const PendingUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final delegate = UnverifiedUserDelegate(hasura.service, client: client);

    Future<JsonMap?> setStatus(JsonMap row, String status) =>
        delegate.update({...row, 'status': status}, row);           // copy in, delegate result out

    return CmsTablePage(
      title: 'Pending users',
      delegate: delegate,
      customActions: [
        CmsTableAction(
          label: 'Approve',
          shouldUpdateTable: true,
          onPressed: (row) => setStatus(row, 'active'),
        ),
        CmsTableAction(
          label: 'Reject',
          shouldUpdateTable: true,
          onPressed: (row) => setStatus(row, 'rejected'),
        ),
      ],
      entries: [/* … */],
    );
  }
}
```

### Multi-step actions

Moderation flows often need a dialog plus a write to another aggregate before
the status update. Abort by returning `null` at every step; re-check
`context.mounted` after every `await` that precedes a UI call:

```dart
// inside build(), next to setStatus above
CmsTableAction(
  label: 'Approve and file...',
  shouldUpdateTable: true,
  onPressed: (row) async {
    final folders = await folderService.loadFolders();
    if (!context.mounted) return null;             // re-check after EVERY await
    final folderId = await showFolderPicker(context, folders);
    if (folderId == null) return null;             // user cancelled - no swap
    await folderService.addToFolder(folderId, row); // cross-aggregate write
    return setStatus(row, 'approved');             // returned map replaces the row
  },
),
```

## Navigation actions

Don't navigate for **row detail** - the edit overlay is the detail view, and
[management-sections.md](management-sections.md) covers extra space inside it.
Navigating to a **standalone analytical or workflow screen** (a chart-heavy
dashboard, a log explorer) is legitimate: it isn't row editing and doesn't fit
an overlay. Shape:

```dart
CmsTableAction(
  label: 'View analytics',
  shouldUpdateTable: false,
  onPressed: (row) async {
    final id = row[delegate.idKey] as String?;
    if (id != null && context.mounted) context.push(AppRoutes.analytics(id));
    return null;                                   // nothing to swap
  },
),
```

(`context.push` is go_router; any router works. The load-bearing parts are
`shouldUpdateTable: false` and `return null`.)

## Rules

- **Per-row custom buttons = `CmsTableAction`**, not `IconButton` in a column.
- **Never mutate the `row` argument.** It is the live map held by table state; mutating it changes the UI even when the backend write fails. Copy, update, return the copy.
- **`shouldUpdateTable: true` requires a `JsonMap` return** that matches the row schema. Otherwise the table will show inconsistent state.
- **Side-effect actions return `null`** - clearer intent and skips the in-place swap.
- **Don't navigate for row detail** (e.g. "View details" pushing a route). The edit overlay is the detail view; add a `CmsManagementSectionEntry` if you need more space ([management-sections.md](management-sections.md)). Standalone analytics/workflow screens are the exception - see "Navigation actions" above.
- **Bulk operations are not actions.** Action runs on one row; bulk needs a different UI.

## Pitfalls

1. **Mutating the row in place.** `row['status'] = …` edits the table's state map directly (the framework passes the live map, not a copy) - the UI lies if `update()` then throws, and `shouldUpdateTable: true` swaps in your mutated input instead of the delegate's result. Always build `{...row, …}` and return what `delegate.update` returns.
2. **Forgetting the confirm dialog on destructive actions.** Users will tap "Reject" by mistake.
3. **Using `context` after an `await` without a `mounted` check.** The closure captures the page's build context; the page can be disposed while `onPressed` runs.
4. **An action labeled "Edit"** - overrides nothing; you've duplicated the built-in. Either rename to clarify intent or remove and use the built-in.
5. **A column of `IconButton`s.** Always wrong for admin tables. Either move to `customActions` or remove (the framework does this).

## See also

- [table-page.md](table-page.md) - `customActions` parameter
- [delegates.md](delegates.md) - where row updates are persisted
- [management-sections.md](management-sections.md) - custom UI *inside* edit overlay (vs row popup)
