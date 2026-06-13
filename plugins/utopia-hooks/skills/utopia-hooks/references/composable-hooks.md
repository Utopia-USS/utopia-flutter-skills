---
title: Composable & Widget-Level Hooks
impact: HIGH
tags: composition, reusable, widget-hooks, extract, paging, HookWidget, decomposition, large-hook, useMap, recipes, useOverridable, useMinimumLoading, optimistic
---

# Skill: Composable & Widget-Level Hooks

Hooks are extractable and composable. Three patterns emerge from this:

1. **Widget-level hook** - a complex widget manages its own hook for local state (animations, lazy loading, expand/collapse). Uses the full Screen/State/View breakdown at widget scope.
2. **Composed hook state** - a reusable widget's state is a hook called *from the parent screen's state hook* and passed down. The widget receives state; it doesn't create it.
3. **Screen hook decomposition** - a large screen hook is split into focused sub-hooks that the main hook composes. Used when a single hook grows too large or mixes unrelated domains.

---

## Pattern 1: Widget-Level Hook

Use when a widget has enough local complexity to warrant its own hook: animations, lazy-loaded content, expand/collapse, per-item async operations.

**Quick Pattern:**

```dart
// ❌ Local complexity inlined in screen state - ties screen logic to tile behavior
ScreenState useScreenState() {
  final expandedIdsState = useState<ISet<ItemId>>(const ISet.empty());
  final loadedDetails = useMap(expandedIdsState.value.toSet(), (id) =>
    useAutoComputedState(() => service.loadDetails(id)));

  // screen state is now entangled with tile animation/loading logic
}

// ✅ Tile extracts its own hook - screen state stays clean
class ItemTile extends HookWidget {
  final Item item;
  const ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = useItemTileState(item: item);
    return ItemTileView(state: state);
  }
}
```

**File structure:**

```
ui/pages/items/
  items_page.dart
  state/items_page_state.dart
  view/items_page_view.dart
  widgets/
    item_tile/
      item_tile_widget.dart        ← HookWidget, calls useItemTileState
      state/item_tile_state.dart   ← ItemTileState class + useItemTileState hook
      view/item_tile_view.dart     ← StatelessWidget, pure UI
```

**Full example - expandable tile with lazy loading** (the state hook is the teaching core; widget shell + view follow the standard Screen/State/View shape):

```dart
// state/item_tile_state.dart
class ItemTileState {
  final Item item;
  final ItemDetails? details;     // null = not yet loaded
  final bool isExpanded;
  final bool isLoadingDetails;
  final void Function() onToggle;
  const ItemTileState({
    required this.item, required this.details, required this.isExpanded,
    required this.isLoadingDetails, required this.onToggle,
  });
}

ItemTileState useItemTileState({required Item item}) {
  final service = useInjected<ItemService>();
  final isExpandedState = useState(false);
  final detailsState = useAutoComputedState(
    () async => service.loadDetails(item.id),
    keys: [item.id],
    shouldCompute: isExpandedState.value,  // lazy - only load when expanded
  );

  return ItemTileState(
    item: item,
    details: detailsState.valueOrNull,
    isExpanded: isExpandedState.value,
    isLoadingDetails: isExpandedState.value && !detailsState.isInitialized,
    onToggle: () => isExpandedState.value = !isExpandedState.value,
  );
}

// item_tile_widget.dart - HookWidget shell: calls useItemTileState(item: item), returns ItemTileView(state: state)
// view/item_tile_view.dart - StatelessWidget: ListTile + trailing expand icon, reveals details (CrazyLoader while isLoadingDetails) when isExpanded
```

**When to extract a widget-level hook:**
- The widget has 2+ pieces of local state (isExpanded + loadedData, animationController + isVisible)
- The widget performs its own async operation (lazy loading, per-item fetch)
- The logic is specific to this widget and has no business being in the screen state
- You want to reuse this widget as a `HookWidget` in multiple screens

**Same rules apply at widget scope:**
- `item_tile_widget.dart` - HookWidget, zero logic, just calls hook and renders view
- `state/item_tile_state.dart` - no widget imports
- `view/item_tile_view.dart` - StatelessWidget, no hooks

---

## Pattern 2: Composed Hook State

Use when a reusable widget (paging control, specialized text field, date picker) would otherwise duplicate the same hook logic in every screen that uses it.

**The key rule: state hook is called from the screen's state hook, not inside the widget.**

**Quick Pattern:**

```dart
// ❌ State created inside widget - screen can't coordinate it, can't access results
class PagingWidget extends HookWidget {
  Widget build(BuildContext context) {
    final pagingState = usePagingState(totalPages: 10); // hidden from screen
    // screen doesn't know current page, can't react to page changes
  }
}

// Used in screen state:
return ScreenState(
  // How does screen know the current page? It can't.
);

// ✅ State created in screen's state hook, passed to widget
ScreenState useScreenState() {
  final pagingState = usePagingState(totalPages: 10); // screen owns it
  final itemsState = useAutoComputedState(
    () => service.load(page: pagingState.currentPage),
    keys: [pagingState.currentPage],   // screen can react to page changes
  );

  return ScreenState(
    items: itemsState.valueOrNull,
    paging: pagingState,   // passed to PagingWidget via ScreenState
  );
}

// PagingWidget just renders - it doesn't create state
class PagingWidget extends StatelessWidget {
  final PagingState state;
  const PagingWidget({required this.state});
  // ...
}
```

**Full example - reusable paging:**

```dart
// Reusable state + hook (lives in common/widgets/paging/)
class PagingState {
  final int currentPage;
  final int totalPages;
  final void Function() onNext;
  final void Function() onPrevious;

  const PagingState({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onPrevious,
  });

  bool get canGoNext => currentPage < totalPages - 1;
  bool get canGoPrevious => currentPage > 0;
}

// The composable hook - called from parent screen state
PagingState usePagingState({required int totalPages}) {
  final pageState = useState(0);
  return PagingState(
    currentPage: pageState.value,
    totalPages: totalPages,
    onNext: () { if (pageState.value < totalPages - 1) pageState.value++; },
    onPrevious: () { if (pageState.value > 0) pageState.value--; },
  );
}

// Reusable widget - StatelessWidget, receives state (prev/next IconButtons gated on
// state.canGoPrevious / state.canGoNext, with a '${currentPage + 1} / $totalPages' label)
class PagingWidget extends StatelessWidget {
  final PagingState state;
  const PagingWidget({required this.state});
  // build(): Row of chevron IconButtons + page label
}

// Screen state hook - composes usePagingState, reacts to page changes
ProductListScreenState useProductListScreenState() {
  final service = useInjected<ProductService>();
  final totalPages = ((useProvided<ProductsState>().totalCount ?? 0) / 20).ceil();
  final paging = usePagingState(totalPages: totalPages);  // screen owns it
  final productsState = useAutoComputedState(
    () => service.loadPage(paging.currentPage, pageSize: 20),
    keys: [paging.currentPage],
  );

  return ProductListScreenState(
    products: productsState.valueOrNull,
    isLoading: !productsState.isInitialized,
    paging: paging,  // View passes the whole PagingState to PagingWidget(state: state.paging)
  );
}
```

**File structure for a reusable composable widget:**

```
ui/common/widgets/paging/
  paging_widget.dart         ← StatelessWidget, receives PagingState
  paging_state.dart          ← PagingState class + usePagingState hook
```

No `view/` subdirectory - the widget is simple enough to not need it. No `HookWidget` - state is always provided from outside.

---

## Pattern 3: Screen Hook Decomposition

Use when a screen's state hook grows too large - too many concerns, too many `useState` calls, too many lines. Instead of one monolithic hook, split it into focused sub-hooks that the main screen hook composes.

**Signals to decompose:**
- More than ~10 `useState` calls in one hook
- More than ~300 lines in one hook function
- Unrelated domains mixed together (data fetching + search + scroll + selection)
- State class has too many unrelated fields (overchunked)

**Quick Pattern:**

```dart
// ❌ One monolithic hook - 1200 lines, 15 useState, fetch + search + scroll interleaved
OrderScreenState useOrderScreenState() {
  // ... data fetching (200 lines)
  // ... search/filter (150 lines)
  // ... infinite scroll (100 lines)
  // ... selection management (80 lines)
  // ... all tangled together, hard to follow
}

// ✅ Main hook composes focused sub-hooks
OrderScreenState useOrderScreenState({
  required void Function(OrderId) navigateToDetail,
}) {
  final fetch = useOrderFetchState();
  final search = useOrderSearchState(orders: fetch.orders);
  final scroll = useOrderScrollState(
    hasMore: fetch.hasMore,
    onLoadMore: fetch.loadMore,
  );

  return OrderScreenState(
    orders: search.filteredOrders,
    isLoading: fetch.isLoading,
    searchQuery: search.query,
    isLoadingMore: scroll.isLoadingMore,
    onOrderTapped: navigateToDetail,
    onSearchChanged: search.onQueryChanged,
    scrollController: scroll.controller,
  );
}
```

**How sub-hooks communicate:**
- Each sub-hook returns its own typed state object (e.g., `OrderFetchState`, `OrderSearchState`)
- The main hook passes outputs from one sub-hook as inputs to another
- Sub-hooks never call each other directly - the main hook is the coordinator
- The Screen State class aggregates fields from all sub-hooks into a single flat interface for the View

**Sub-hook example:**

```dart
class OrderFetchState {
  final IList<Order>? orders;
  final bool isLoading;
  final bool hasMore;
  final void Function() loadMore;

  const OrderFetchState({
    required this.orders,
    required this.isLoading,
    required this.hasMore,
    required this.loadMore,
  });
}

OrderFetchState useOrderFetchState() {
  final service = useInjected<OrderService>();
  final ordersState = useAutoComputedState(
    () async => (await service.loadOrders()).toIList(),
  );
  final loadMoreState = useSubmitState();

  return OrderFetchState(
    orders: ordersState.valueOrNull,
    isLoading: !ordersState.isInitialized,
    hasMore: /* ... */,
    loadMore: () => loadMoreState.runSimple<void, Never>(
      submit: () async { /* ... */ },
    ),
  );
}
```

**File structure:**

```
ui/screens/orders/
  orders_screen.dart
  state/
    orders_screen_state.dart       ← main hook, composes sub-hooks
    order_fetch_state.dart         ← sub-hook: data loading
    order_search_state.dart        ← sub-hook: search/filter
    order_scroll_state.dart        ← sub-hook: infinite scroll
  view/orders_screen_view.dart
```

Sub-hooks live in the same `state/` directory as the main hook. They are private to this screen - not reusable (that's Pattern 2).

**What this is NOT:**
- Not Pattern 1 - sub-hooks are not extracted to child widgets; they're called from the same screen hook
- Not Pattern 2 - sub-hooks are not reusable across screens; they're specific to this screen's domain
- If a sub-hook IS reusable (e.g., paging logic used on 3 screens), it becomes Pattern 2

---

## Per-item state: three archetypes

A list of N items where each item has its own state (expansion, per-item async, validation, drafts, UI resources) raises one question: **where does that state live?** Three valid archetypes - the choice depends on whether the parent needs to read or modify individual item state.

### Decision tree

| Does parent need to read/modify individual item state? | N of items | Per-item complexity | Recommended |
|---|---|---|---|
| No - parent only cares when done | Any | Any | **A**: Widget-level Pattern 1 (full `widget/state/view`), optional feedback callback |
| Yes - parent aggregates / coordinates | **Fixed** (known at code-time) | Multi-field / async / lifecycle | **B.1**: Composed hook called multiple times (`final a = useX(); final b = useX();`) |
| Yes - parent aggregates / coordinates | **Dynamic** (runtime add/remove) | Multi-field / async / lifecycle | **B.2**: `useMap<Key, useX>` at parent |
| Yes - parent reads often | Any | Single small flag | **C**: Screen-state `Map<Key, Flag>` (OK, but reconsider if state grows) |

`useMap` is the dynamic-N variant of B.1 - same coupling shape (parent-owns-state, widget-gets-prop), just with runtime-growing keys. For fixed N, just call the hook multiple times; reaching for `useMap` is overkill.

### Archetype A: Widget-level Pattern 1 - per-item state is self-contained

Use when parent never needs to inspect individual item state. The tile owns its own async, flags, caches; if parent needs "it's done," a single feedback callback suffices.

Same shape as the Pattern 1 expandable tile above (full `widget/state/view`), with one addition: an optional `onResultLoaded` feedback callback so the parent learns "it's done" without owning the state.

```dart
ItemTileState useItemTileState({
  required Item item,
  void Function(ItemId, ItemDetails)? onResultLoaded,  // optional feedback
}) {
  final service = useInjected<ItemService>();
  final expandedState = useState(false);
  final detailsState = useComputedState(() async => service.loadDetails(item.id));

  // Trigger load when expanded; notify parent when done (if caller cares)
  useEffect(() async {
    if (expandedState.value && detailsState.value is! ComputedStateValueInProgress) {
      onResultLoaded?.call(item.id, await detailsState.refresh());
    }
    return null;
  }, [expandedState.value, item]);

  return ItemTileState(
    item: item,
    expandedState: expandedState,
    details: detailsState.valueOrNull,
    isLoadingDetails: expandedState.value && !detailsState.isInitialized,
    onReload: detailsState.refresh,
  );
}
```

Parent passes only the item + an optional callback. `loadMore`, `expandedIdsState`, `loadedDetails` concerns disappear from the screen state entirely.

### Archetype B.1: Fixed N - just call the hook multiple times

When parent needs to aggregate and N is known at code-time, no special primitive is needed. Call the hook directly per instance.

```dart
// Parent state hook - two specific editors on one form
EditorFormScreenState useEditorFormScreenState() {
  final primary = useEditorItemState(label: 'Primary');
  final secondary = useEditorItemState(label: 'Secondary');

  final allValid = primary.isValid && secondary.isValid;

  void submitAll() => [primary, secondary].forEach((it) => it.save());

  return EditorFormScreenState(
    primary: primary,
    secondary: secondary,
    canSubmit: allValid,
    onSubmit: submitAll,
  );
}
```

The widgets receive the state:

```dart
Column([
  EditorItemTile(state: state.primary),
  EditorItemTile(state: state.secondary),
])
```

This is just Pattern 2 with two instances. No `useMap`, no ceremony.

### Archetype B.2: Dynamic N - `useMap<Key, useXState>`

When N grows/shrinks at runtime, `useMap` gives you one hook instance per key, stable across rebuilds. Parent holds the Map; widgets look up by key.

```dart
// The per-item hook - non-trivial, multiple internal hooks
EditorItemState useEditorItemState({required ItemId id}) {
  final valueState = useFieldState();
  final labelState = useFieldState();
  final saveState = useSubmitState();
  final isValid = valueState.value.isNotEmpty && labelState.value.isNotEmpty;

  return EditorItemState(
    id: id,
    value: valueState,
    label: labelState,
    isValid: isValid,
    isSaving: saveState.inProgress,
    save: () => saveState.runSimple<void, Never>(
      submit: () async => service.save(id, valueState.value, labelState.value),
    ),
    reset: () {
      valueState.value = '';
      labelState.value = '';
    },
  );
}

// Parent - one instance per dynamic id, aggregates and coordinates
EditorListScreenState useEditorListScreenState({required IList<ItemId> itemIds}) {
  final itemStates = useMap(
    itemIds.toSet(),
    (id) => useEditorItemState(id: id),
  );

  final allValid = itemStates.values.every((it) => it.isValid);

  void submitAll() =>
      itemStates.values.map((it) => {'id': it.id, 'value': it.value.value}).toList();
      //                                                                    ^ → API

  void resetAll() => itemStates.values.forEach((it) => it.reset());

  return EditorListScreenState(
    itemStates: itemStates,
    canSubmit: allValid,
    onSubmit: submitAll,
    onResetAll: resetAll,
  );
}
```

Widget receives the per-item state via Map lookup:

```dart
for (final id in itemIds)
  EditorItemTile(state: state.itemStates[id]!)
```

Key lifecycle: adding an id to `itemIds` → new hook instance initialised; removing an id → that instance disposed. `useMap` keeps the Map identity stable across rebuilds. For user-editable rows, let the parent own a mutable `useState<ISet<ItemId>>` and pass a removal closure into each sub-state (`onRemove: () => itemIds.modify((it) => it.remove(id))`); removing from the set disposes that instance on the next build, and the View can render `itemStates.values.toIList()` with no Map lookups.

### Archetype C: Screen-state `Map<Key, Flag>` - only for trivial single-flag cases

If per-item state is one small flag and parent always reads it, the screen hook can hold `Map<Key, Flag>` directly.

```dart
// Dismissible banners - screen tracks which are dismissed
final dismissedBannersState = useState<ISet<BannerId>>(const ISet.empty());

void dismiss(BannerId id) =>
    dismissedBannersState.value = dismissedBannersState.value.add(id);
```

Don't scale this: the moment per-item state adds a second field, async, or lifecycle, move to archetype A or B.

### Anti-patterns

- **Don't use `useMap` when archetype A suffices.** Parent doesn't need per-item access? Stay widget-level. Reaching for `useMap` couples parent to item state it doesn't use.
- **Don't use A when B is needed.** If parent has a "submit-all" or "reset-all" action, you'll end up plumbing N feedback callbacks per item - at which point B is cleaner.
- **Don't use C when B is needed.** A `Map<Key, Flag>` doesn't scale to per-item async or lifecycle. Convert to per-item hook (A or B) as complexity grows.
- **Don't use B when A suffices.** Running per-item hooks at the parent when the parent never reads them just pushes per-item lifecycle into the screen hook unnecessarily.

---

## Recipes - Small Composable Hooks to Copy

Two recurring problems with a known-good composable-hook shape. These are **recipes to copy
into your project** (e.g. `common/hook/`) - they are not utopia_hooks APIs.

### useOverridable - optimistic override of a server-backed scalar

A toggle or dropdown backed by a server value: changing it should update the UI immediately,
persist in the background, revert on failure, and resume tracking the server value once it
has caught up. Exposing the result as `MutableValue<T>` keeps the View dumb (reads `.value`,
writes `.value`).

```dart
MutableValue<T> useOverridable<T extends Object>(
  T serverValue, {
  required Future<void> Function(T value) persist,
}) {
  final overrideState = useState<T?>(null);
  final submitState = useSubmitState();
  final isMounted = useIsMounted();

  // Server caught up with the override - resume tracking the server value.
  useEffect(() {
    if (overrideState.value != null && overrideState.value == serverValue) overrideState.value = null;
  }, [serverValue]);

  return MutableValue.computed(
    () => overrideState.value ?? serverValue,
    (newValue) {
      final previous = overrideState.value;
      overrideState.value = newValue; // optimistic - UI updates immediately
      unawaited(submitState.runSimple<void, Never>(
        submit: () => persist(newValue),
        afterError: () {
          if (isMounted()) overrideState.value = previous; // revert on failure
        },
      ));
    },
  );
}

// Usage in a state hook:
final notificationsEnabled = useOverridable(
  profile.valueOrNull?.notificationsEnabled ?? false,
  persist: (it) => service.setNotificationsEnabled(it),
);
```

Unknown persistence errors still rethrow into the global error pipeline (the override has
already been reverted by then). For optimistic updates over a *list*, use the override-layer
shape in [complex-state-examples.md](./complex-state-examples.md) (shape 3) instead.

### useMinimumLoading - minimum skeleton duration

Once a loader or skeleton has appeared, keep it visible for a minimum beat - a skeleton that
flashes for 80ms reads as a glitch, not as loading.

```dart
bool useMinimumLoading(bool isLoading, {Duration minimum = const Duration(milliseconds: 500)}) {
  final shownAtState = useState<DateTime?>(null, listen: false); // latch - no rebuild needed
  final holdingState = useState(false);

  useEffect(() {
    if (isLoading) {
      shownAtState.value = DateTime.now();
      return null;
    }
    if (shownAtState.value == null) return null; // loader never showed
    final remaining = minimum - DateTime.now().difference(shownAtState.value!);
    if (remaining <= Duration.zero) {
      holdingState.value = false; // reset - a previous hold may still be latched
      return null;
    }
    holdingState.value = true;
    final timer = Timer(remaining, () => holdingState.setIfMounted(false));
    return timer.cancel;
  }, [isLoading]);

  return isLoading || holdingState.value;
}

// Usage in a state hook:
final showSkeleton = useMinimumLoading(!items.isInitialized);
```

---

## Decision Guide

| Situation | Pattern |
|-----------|---------|
| Widget has local complexity (expand, animation, per-item async) | Widget-level hook (Pattern 1) |
| Widget is reused across screens, screen needs to react to its state | Composed hook state (Pattern 2) |
| Widget is simple, no async, no state coordination needed | Plain `StatelessWidget`, no hook |
| Screen state would get polluted with per-tile logic for N tiles | Widget-level hook (Pattern 1) |
| Multiple fields of the same type on one screen | Composed hook state (Pattern 2) - one `useXState()` call per instance in screen state hook |
| Screen hook > ~300 lines or > ~10 useState | Screen hook decomposition (Pattern 3) |
| Screen hook mixes unrelated domains (fetch + search + scroll) | Screen hook decomposition (Pattern 3) |
| State class has too many unrelated fields | Screen hook decomposition (Pattern 3) - split into sub-hooks with own state objects |

---

## Common Pitfalls

- **Calling usePagingState inside PagingWidget** - screen can't react to page changes; always compose from screen state hook
- **Widget-level hook for simple state** - if the widget only has one `useState`, it doesn't need the full [state, widget, view] breakdown; a single `HookWidget` with inline hook calls is fine
- **Mixing both patterns** - don't have a widget that both calls its own hook AND accepts state from outside; pick one
- **Screen state passing individual fields instead of state object** - pass the whole `PagingState`, not `currentPage: paging.currentPage, onNext: paging.onNext, …`
- **Sub-hooks calling each other directly** - sub-hooks should return state; the main screen hook coordinates and passes values between them
- **Decomposing too early** - a hook with 5 useState and 100 lines doesn't need Pattern 3; only decompose when the signals are clearly present

## Related Skills

- [screen-state-view.md](./screen-state-view.md) - same rules apply at widget scope
- [hooks-reference.md](./hooks-reference.md) - useState, useAutoComputedState inside widget-level hooks
- [async-patterns.md](./async-patterns.md) - lazy loading in widget-level hooks
- [complex-state-examples.md](./complex-state-examples.md) - full worked examples of the three per-item archetypes and screen decomposition shapes
