---
title: Paginated Lists
impact: HIGH
tags: pagination, usePaginatedComputedState, PaginatedComputedStateWrapper, loadMore, cursor, infinite-scroll, pull-to-refresh, shouldCompute, useIf, global paginated state
---

# Skill: Paginated Lists

`usePaginatedComputedState` is the default tool for **any cursor-based list**: infinite-scroll feeds, paginated search results, chat histories, any endpoint that returns
pages. It covers the boilerplate that every paged list re-invents: first-page auto-load, in-flight deduplication, cancellation on refresh/keys change, debounce for
search, and on-end pagination. Pair it with `PaginatedComputedStateWrapper` for a two-line infinite-scroll + pull-to-refresh list.

**Default rule:** any list that loads in pages → `usePaginatedComputedState`. Do not hand-roll `useState<List<T>>` + `hasMore` + `isLoading` + cursor state.

## Quick Pattern

**Incorrect (hand-rolled pagination):**
```dart
final itemsState = useState<List<User>?>(null);
final cursorState = useState<String?>(null);
final hasMoreState = useState(true);
final isLoadingState = useState(false);

Future<void> loadMore() async {
  if (isLoadingState.value || !hasMoreState.value) return;
  isLoadingState.value = true;
  try {
    final page = await api.getUsers(pageToken: cursorState.value);
    itemsState.value = [...?itemsState.value, ...page.items];
    cursorState.value = page.nextPageToken;
    hasMoreState.value = page.nextPageToken != null;
  } finally {
    isLoadingState.value = false;
  }
}

useEffect(() { loadMore(); return null; }, []);
```

**Correct (`usePaginatedComputedState`):**
```dart
final usersState = usePaginatedComputedState<User, String?>(
  initialCursor: null,
  (token) async {
    final response = await api.getUsers(pageToken: token);
    return PaginatedPage(items: response.items, nextCursor: response.nextPageToken);
  },
);
// usersState.items / usersState.isLoading / usersState.hasMore / usersState.error
// usersState.loadMore() / usersState.refresh() / usersState.clear()
```

---

## Core Types

### `PaginatedPage<T, C>`

What `compute` returns - one page of items plus the cursor for the **next** page.

```dart
PaginatedPage(items: [...], nextCursor: 2)   // more pages available
PaginatedPage.last(items: [...])             // final page - nextCursor is null
```

A `null` `nextCursor` signals "no more pages"; further `loadMore()` calls become no-ops until `refresh()` or a `keys` change resets `hasMore` to `true`.

### `PaginatedComputedState<T, C>` / `MutablePaginatedComputedState<T, C>`

Snapshot of the paginated computation. Returned by the hook and consumed by the View. Implements `HasInitialized`.

| Field | Type | Meaning |
|---|---|---|
| `items` | `List<T>?` | `null` before the first successful load and after `clear()`. Stays populated across `loadMore` and across `refresh(clearCache: false)` until the first page of the new load replaces it. |
| `cursor` | `C` | Cursor for the **next** `loadMore`. Starts at `initialCursor`, advances through `nextCursor` values, stays at its last non-null value once the end is reached. |
| `hasMore` | `bool` | `false` once a page returned `nextCursor == null`. Reset by `refresh()` and by `keys` change. |
| `isLoading` | `bool` | `true` whenever any load (first page / `loadMore` / `refresh`) is in flight. |
| `error` | `Object?` | Last load's exception. Cleared when the next load starts. |
| `isInitialized` | `bool` | Alias for `items != null`. |
| `hasError` | `bool` | Alias for `error != null`. |

`MutablePaginatedComputedState` adds `loadMore()`, `refresh({bool clearCache})`, `clear()`.

---

## Cursor schemes

`C` is opaque to the hook - pick the type that matches your backend.

### Offset-based

```dart
usePaginatedComputedState<User, int>(
  initialCursor: 0,
  (offset) async {
    final items = await api.getUsers(offset: offset, limit: 20);
    return PaginatedPage(
      items: items,
      nextCursor: items.length < 20 ? null : offset + items.length,
    );
  },
);
```

### Page-based

```dart
usePaginatedComputedState<User, int>(
  initialCursor: 1,
  (page) async {
    final response = await api.getUsers(page: page, pageSize: 20);
    return PaginatedPage(
      items: response.items,
      nextCursor: response.hasNext ? page + 1 : null,
    );
  },
);
```

### Token-based

For opaque continuation tokens, make `C` nullable so `null` represents "no token yet":

```dart
usePaginatedComputedState<User, String?>(
  initialCursor: null,
  (token) async {
    final response = await api.getUsers(pageToken: token);
    return PaginatedPage(
      items: response.items,
      nextCursor: response.nextPageToken,
    );
  },
);
```

---

## Options

```dart
usePaginatedComputedState<T, C>(
  Future<PaginatedPage<T, C>> Function(C cursor) compute, {
  required C initialCursor,
  bool shouldCompute = true,
  bool clearOnShouldComputeFalse = false,
  HookKeys keys = hookKeysEmpty,
  Duration debounceDuration = Duration.zero,
  Object Function(T item)? deduplicateBy,
})
```

### `shouldCompute` - gate the automatic loads

`shouldCompute` gates **only the automatic loads**: the first-page load on mount and the refresh triggered by a `keys` change. While `false`, those triggers are skipped; when it transitions back to `true`, the first page loads (a refresh from `initialCursor`).

The contract is **weaker than `useAutoComputedState`'s** (where `shouldCompute: false` clears the state immediately):

- An in-flight load is **not** cancelled when `shouldCompute` turns `false` - it completes normally.
- `items` are **not** cleared - previously loaded data stays visible.
- Manual `loadMore()` / `refresh()` calls are **never** gated - they run regardless of `shouldCompute`.

```dart
final usersState = usePaginatedComputedState<User, int>(
  initialCursor: 0,
  (offset) async => _fetchPage(offset),
  shouldCompute: authState.isInitialized && organizationId != null,
);
```

### `clearOnShouldComputeFalse` - opt into clearing

`clearOnShouldComputeFalse: true` resets the state when the gate closes: the in-flight load is cancelled and `items` / `error` drop back to their initial state (same as calling `clear()`). Use it when the gating condition is "user logged in" and you don't want the previous user's data lingering. Without it, `shouldCompute: false` leaves everything in place.

### `keys` - refresh on dependency change

Any change to `keys` triggers `refresh()` from `initialCursor` (only while `shouldCompute` is `true`). Items **stay visible** during the reload (no flicker) - they are replaced by the first page of the new load. Use this exactly like `useAutoComputedState`'s `keys`.

```dart
final messagesState = usePaginatedComputedState<Message, String?>(
  initialCursor: null,
  (token) async => api.messages(chatId: chatId, pageToken: token),
  keys: [chatId],   // switching chat refreshes from page 1
);
```

### `debounceDuration` - delay the first-page load after `keys` change

For paginated search. Only affects the first-page load triggered by `keys` / initial mount - subsequent `loadMore()` calls are immediate.

```dart
final searchState = useFieldState();
final query = useDebounced(searchState.value, duration: const Duration(milliseconds: 300));

final resultsState = usePaginatedComputedState<Result, int>(
  initialCursor: 0,
  (offset) async => api.search(query: query, offset: offset),
  keys: [query],
  debounceDuration: const Duration(milliseconds: 300),
);
```

(With `useDebounced` already in the keys, the extra `debounceDuration` is optional - but if you drive `keys` directly from the raw query, `debounceDuration` does the debouncing for you.)

### `deduplicateBy` - drop overlapping items

Optional identifier extractor. Items whose key matches any already-collected item are dropped before being appended. Useful when adjacent pages overlap due to concurrent server-side writes or when `nextCursor` is inclusive.

```dart
final reactionsState = usePaginatedComputedState<Reaction, String?>(
  initialCursor: null,
  (token) async => api.reactions(activityId: id, pageToken: token),
  deduplicateBy: (r) => r.id,
);
```

First-occurrence wins. Without `deduplicateBy`, duplicates are kept.

### `initialCursor` - captured on first build

`initialCursor` is captured once and ignored on subsequent builds. For dynamic starting points (e.g. a "jump to date" UI), wrap the whole hook in `useKeyed([startDate], () => usePaginatedComputedState(...))` so the entire state is recreated.

---

## Actions

### `loadMore()`

- No-op when `hasMore` is `false`.
- While a load is in flight, returns the in-flight operation - concurrent calls share it. The wrapper's scroll listener therefore cannot trigger duplicate loads.
- On failure, sets `error` and keeps previously loaded `items`.

### `refresh({bool clearCache = false})`

- Cancels any in-flight load, resets `cursor` to `initialCursor`, `hasMore` to `true`, clears `error`, then loads the first page.
- **Default `clearCache: false`** - `items` stay visible and are replaced by the first page of the new load. No flicker. This is what pull-to-refresh and keys-triggered reloads want.
- `clearCache: true` drops `items` to `null` before reloading - use only when you explicitly want a blank slate (e.g. switching to a fundamentally different dataset).

### `clear()`

Cancels any in-flight load and resets **all** fields (`items`, `cursor`, `hasMore`, `error`, `isLoading`) to their initial state. Does **not** trigger a reload. Rarely needed directly - `refresh(clearCache: true)` is usually what you want.

---

## Error handling

- Errors from `compute` are stored in `state.error`. `items` remain unchanged.
- The next `loadMore()` or `refresh()` clears `error` when it starts.
- Unhandled errors from the **auto-triggered** first load propagate via the zone - if you need to observe them, use an error-boundary widget at the screen level, or gate the initial load with `shouldCompute: false` + manual `refresh()` so you can `await` it.

```dart
// Typical View-side error handling
if (state.error != null && state.items == null) {
  return ErrorView(error: state.error!, onRetry: state.refresh);
}
```

---

## Rendering with `PaginatedComputedStateWrapper`

The companion widget wires the scroll listener + pull-to-refresh to a `MutablePaginatedComputedState`. The caller owns **all** rendering - empty, error, and loading states are your business.

```dart
PaginatedComputedStateWrapper<User, int>(
  state: state.users,
  builder: (context, items, loadingMore) {
    if (items == null) return const CrazyLoader();
    if (items.isEmpty) return const EmptyState();
    return ListView.builder(
      itemCount: items.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, i) => i < items.length
          ? UserTile(user: items[i])
          : const Padding(padding: EdgeInsets.all(16), child: CrazyLoader()),
    );
  },
)
```

**Contract:**
- `builder` receives `(context, items, loadingMore)`.
  - `items` is `null` until the first successful load - render your top-level loader here.
  - `loadingMore` is `state.isLoading && items != null` - a follow-up load is in flight on top of visible items. Render a bottom spinner / shimmer.
- `builder` **must return a scrollable** (`ListView`, `CustomScrollView`, `GridView`, …) - the `NotificationListener` that drives `loadMore` listens to scroll notifications from the child.
- `loadMoreThreshold` (default `200`) - pixels-from-end at which `loadMore()` fires.
- `refreshable` (default `true`) - wraps the child in `RefreshIndicator(onRefresh: state.refresh)`. Set `false` when you don't want pull-to-refresh (e.g. reverse-scrolling chat history).
- **Auto-`loadMore` is suppressed while `error != null`** (and while `items` is `null` or empty) - a failed `loadMore` will not retry in an endless scroll loop. The user must trigger the retry; render an explicit affordance at the end of the list:

```dart
PaginatedComputedStateWrapper<User, int>(
  state: state.users,
  builder: (context, items, loadingMore) {
    if (items == null) return const CrazyLoader();
    final hasTrailingRow = loadingMore || state.users.hasError;
    return ListView.builder(
      itemCount: items.length + (hasTrailingRow ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < items.length) return UserTile(user: items[i]);
        if (state.users.hasError) {
          // loadMore() clears error when it starts, which re-enables auto-loading.
          return TextButton(onPressed: state.users.loadMore, child: const Text("Retry"));
        }
        return const Padding(padding: EdgeInsets.all(16), child: CrazyLoader());
      },
    );
  },
)
```

**The wrapper does not render spinners or errors.** If all you pass for an empty list is `const SizedBox.shrink()`, the user sees nothing. Render explicit empty / error states from `items` and `state.error`.

### Why the wrapper is thin

It intentionally has no `emptyBuilder` / `errorBuilder` / `loadingBuilder` parameters. Every screen has its own idea of what "empty" looks like (illustration + CTA, filters hint, …) - forcing builders would mean a dozen parameters and still missing cases. Keep empty/error logic next to the data in your `builder`.

---

## Rendering without the wrapper

For non-scroll-driven pagination ("Load more" button, reverse-scroll chat, custom viewport), skip the wrapper and wire `loadMore` yourself.

```dart
// "Load more" button
Column(
  children: [
    for (final msg in state.messages.items ?? const []) MessageTile(msg),
    if (state.messages.hasMore)
      CrazySquashButton(
        onTap: state.messages.isLoading ? null : state.messages.loadMore,
        child: state.messages.isLoading
            ? const CrazyLoader(small: true)
            : const Text("Load more"),
      ),
  ],
)
```

---

## Integration with other state

Paginated state fits cleanly into the Screen / State / View pattern. The hook is called inside the screen state hook; the result is exposed as a field on the State class.

```dart
class FeedScreenState {
  final MutablePaginatedComputedState<Post, String?> posts;
  final FieldState searchField;
  final void Function(PostId) onPostTapped;

  const FeedScreenState({
    required this.posts,
    required this.searchField,
    required this.onPostTapped,
  });
}

FeedScreenState useFeedScreenState({
  required void Function(PostId) navigateToPost,
}) {
  final api = useInjected<FeedApi>();
  final searchState = useFieldState();
  final query = useDebounced(searchState.value, duration: const Duration(milliseconds: 300));

  final postsState = usePaginatedComputedState<Post, String?>(
    initialCursor: null,
    (token) async {
      final response = await api.feed(query: query, pageToken: token);
      return PaginatedPage(items: response.items, nextCursor: response.nextPageToken);
    },
    keys: [query],
    deduplicateBy: (p) => p.id,
  );

  return FeedScreenState(
    posts: postsState,
    searchField: searchState,
    onPostTapped: navigateToPost,
  );
}
```

**Expose the mutable state directly.** The View needs `loadMore` / `refresh`, so passing `MutablePaginatedComputedState<T, C>` through is correct - do **not** project each field separately on the State class.

### Optimistic mutations on a paginated list

`items` is read-only - the hook owns its buffer. For optimistic add/edit/delete, keep a **local override layer** and overlay it at render time. After the server confirms, call `refresh()` (or clear the overlay).

```dart
// State hook
final postsState = usePaginatedComputedState<Post, String?>(/* ... */);
final deletedIdsState = useState<ISet<PostId>>(const ISet.empty());
final draftEditsState = useState<IMap<PostId, Post>>(const IMap.empty());
final deleteSubmitState = useSubmitState();

final visiblePosts = useMemoized(
  () => postsState.items
      ?.where((p) => !deletedIdsState.value.contains(p.id))
      .map((p) => draftEditsState.value[p.id] ?? p)
      .toIList(),
  [postsState.items, deletedIdsState.value, draftEditsState.value],
);

void deletePost(PostId id) => deleteSubmitState.runSimple<void, Never>(
  beforeSubmit: () => deletedIdsState.modify((it) => it.add(id)),
  submit: () async => api.deletePost(id),
  // On failure, roll back:
  afterError: () => deletedIdsState.modify((it) => it.remove(id)),
);
```

This keeps the paginated buffer honest (always mirrors the server) while the UI shows the optimistic view. Do **not** try to replace `items` - there is no setter on purpose.

---

## Global paginated state

A paginated list shared by several screens (home feed, notification list) can live in a global state hook like any other state - see [global-state.md](./global-state.md) for registration. The `MutablePaginatedComputedState` is exposed as a field; items stay cached across screen pushes/pops, and a mutation anywhere in the app can call `refresh()` on it.

```dart
class FeedState {
  final MutablePaginatedComputedState<Post, String?> posts;

  const FeedState({required this.posts});
}

FeedState useFeedState() {
  final api = useInjected<FeedApi>();

  final postsState = usePaginatedComputedState<Post, String?>(
    initialCursor: null,
    (token) async {
      final response = await api.feed(pageToken: token);
      return PaginatedPage(items: response.items, nextCursor: response.nextPageToken);
    },
  );

  return FeedState(posts: postsState);
}

// Registered in _providers:  FeedState: useFeedState,

// Elsewhere - e.g. in the create-post screen's submit:
final feed = useProvided<FeedState>();
// ... afterSubmit: (_) => feed.posts.refresh(),
```

`refresh()`'s default `clearCache: false` shines here: every screen currently showing the feed keeps its items visible while the new first page loads.

### Screen-local fallback composition with `useIf`

Sometimes a screen needs its **own** paginated state only under a condition (an active search query, a filter) and the shared global state otherwise. Hooks must be called unconditionally, so you cannot wrap the hook call in an `if` statement - `useIf(condition, block)` is the sanctioned conditional wrapper: it returns `block()`'s result while `condition` is `true` and `null` otherwise.

```dart
final feed = useProvided<FeedState>();
final api = useInjected<FeedApi>();
final searchState = useFieldState();
final query = useDebounced(searchState.value, duration: const Duration(milliseconds: 300));

final searchResults = useIf(
  query.isNotEmpty,
  () => usePaginatedComputedState<Post, String?>(
    initialCursor: null,
    (token) async {
      final response = await api.search(query: query, pageToken: token);
      return PaginatedPage(items: response.items, nextCursor: response.nextPageToken);
    },
    keys: [query],
  ),
);

final posts = searchResults ?? feed.posts;
// Expose `posts` on the State - the View never knows whether it is local or global.
```

Notes:

- `useIf` keys its inner hooks on the condition: when `query` becomes empty, the search state is disposed (results discarded); when it becomes non-empty again, a fresh state is created and auto-loads. For search this is usually exactly what you want.
- Give the local and the global state the **same** `T` and `C` type arguments so `??` produces a usable `MutablePaginatedComputedState<T, C>` instead of an unhelpful common supertype.

---

## When not to use it: reactive bidirectional lists

`usePaginatedComputedState` is one-directional pull: a cursor walks forward, pages append. A live chat view - a database watch stream pushing new messages at one end while the user scrolls back through history at the other - does not fit a single paginated state. Split the two directions instead:

```dart
// Older pages: plain backward pagination (newest -> oldest).
final historyState = usePaginatedComputedState<Message, DateTime?>(
  initialCursor: null,
  (before) async {
    final batch = await api.messagesBefore(roomId, before: before, limit: 50);
    return PaginatedPage(items: batch, nextCursor: batch.isEmpty ? null : batch.last.sentAt);
  },
  keys: [roomId],
);

// Live tail: watch stream from the DB / socket.
final live = useMemoizedStream(() => api.watchMessages(roomId), keys: [roomId]);

// Merge at render time, deduplicated by id.
final messages = useMemoized(
  () => [...?live.data, ...?historyState.items].distinctBy((m) => m.id).toList(),
  [live.data, historyState.items],
);
```

This split holds while stream items only prepend. Once the stream pushes **in-place edits and deletes** that must rewrite already-paginated history, the merge gets stateful - at that point hand-roll a dedicated state hook around your database's query API instead of fighting the paginated hook. That is the honest limit of `usePaginatedComputedState`.

---

## Testing

`usePaginatedComputedState` is tested the same way as any hook - with `SimpleHookContext`. See [testing.md](./testing.md) for the fundamentals, including how to mock injected services.

```dart
test("loadMore appends items and advances cursor", () async {
  final context = SimpleHookContext(
    () => usePaginatedComputedState<int, int>(
      (c) async => PaginatedPage(
        items: List.generate(3, (i) => c * 3 + i),
        nextCursor: c + 1,
      ),
      initialCursor: 0,
    ),
  );
  addTearDown(context.dispose);

  await context.waitUntil((s) => s.items != null);
  expect(context.value.items, [0, 1, 2]);

  await context.value.loadMore();
  expect(context.value.items, [0, 1, 2, 3, 4, 5]);
  expect(context.value.cursor, 2);
});
```

**Testing tips:**
- Auto-triggered first-load errors propagate as uncaught zone errors and fail tests before assertions run. To test error paths, pass `shouldCompute: false` and call `refresh()` manually so you can `await` its future and `expectLater(...)` the error.
- Use `Completer<PaginatedPage<T, C>>`s in the `compute` callback when you need to control load ordering (concurrent loads, mid-load refresh cancellation, etc.).

---

## Common Pitfalls

- **Hand-rolling pagination with `useState` + `useEffect`** - you will re-invent debouncing, in-flight deduplication, cancellation, and the stay-visible-during-refresh behavior badly. Use the hook.
- **Projecting every field on the State class** (`items`, `isLoading`, `loadMore`, …) - pass the `MutablePaginatedComputedState<T, C>` through as a single field. The View needs the actions, not just the data.
- **Forgetting `deduplicateBy` for token-based APIs that return overlapping pages** - symptom: the same item appears twice near page boundaries. Add `deduplicateBy: (it) => it.id`.
- **Using `refresh(clearCache: true)` for pull-to-refresh** - causes a flicker as items vanish then reappear. Default `clearCache: false` is correct here.
- **Expecting `initialCursor` to be reactive** - it's captured on first build. For runtime-dynamic starting points, wrap in `useKeyed`.
- **Expecting `shouldCompute: false` to cancel or clear** - it only skips the automatic loads; in-flight loads finish, items stay, and manual `loadMore()`/`refresh()` still work. Pass `clearOnShouldComputeFalse: true` if you need the state wiped when the gate closes.
- **Wondering why infinite scroll stopped after a failure** - the wrapper suppresses auto-`loadMore` while `error != null` (no retry loops). Render a retry affordance that calls `loadMore()`; it clears the error and resumes.
- **Returning a non-scrollable from the wrapper's `builder`** - the scroll listener can never fire, so `loadMore()` is never triggered. Must be a `ListView` / `GridView` / `CustomScrollView` / any scrollable.
- **Writing to `items`** - there's no setter. Optimistic mutations belong in an override layer (see pattern above).
- **Using `usePaginatedComputedState` for non-paged data** - single-shot loads should use `useAutoComputedState`, streams should use `useMemoizedStream`. Paginated is for cursor-driven pages.

## Related Skills

- [hooks-reference.md](./hooks-reference.md) - catalogue including `useAutoComputedState` and `useMemoizedStream` for non-paged shapes
- [async-patterns.md](./async-patterns.md) - download/upload/stream mental model; paginated is the cursor-based cousin of download
- [screen-state-view.md](./screen-state-view.md) - where the paginated state field lives on the State class
- [global-state.md](./global-state.md) - registering a shared paginated state in `_providers`
- [complex-state-examples.md](./complex-state-examples.md) - feed-style list with optimistic updates (shape 3) built on `usePaginatedComputedState`
- [testing.md](./testing.md) - `SimpleHookContext` fundamentals and mocking injected services
