---
title: Delegates, the server layer (CmsDelegate family)
impact: CRITICAL
tags: delegate, firebase, supabase, hasura, graphql
---

# Skill: Delegates (Server Layer)

A **`CmsDelegate`** is the bridge between `CmsTablePage` and your backend. It's
four async methods: `get / create / update / delete`. The prebuilt delegates
(`CmsFirebaseDelegate`, `CmsSupabaseDelegate`, `CmsHasuraDelegate`) implement
these against their respective backends. You extend them when you need business
logic; you implement `CmsDelegate` directly for any other backend - including
plain (non-Hasura) GraphQL, where `utopia_cms_graphql` provides the building
blocks but **no prebuilt delegate** (see below).

## Quick Pattern

### ❌ Anti-pattern - separate "service" class

```dart
class ProductService {
  Future<List<Product>> loadProducts() async {
    final docs = await FirebaseFirestore.instance.collection('products').get();
    return docs.docs.map((d) => Product.fromMap(d.data())).toList();
  }
  Future<void> createProduct(Product p) { … }                          // + update, delete…
}
```

…then this service is called by a hand-rolled state hook. **All of this is what `CmsFirebaseDelegate` already does.**

### ✅ utopia_cms way

```dart
// Trivial case - collection name + idKey
final delegate = const CmsFirebaseDelegate('products');

// Custom - extend & override only what changes
class UserDelegate extends CmsSupabaseDelegate {
  final UserService userService;
  UserDelegate(super.supabaseService, this.userService, {required super.client})
      : super(
          table: const CmsSupabaseDataTable('user'),
          archivedFilter: const CmsFilterNotEquals('archived', true),  // soft delete
        );

  @override
  Future<JsonMap> create(JsonMap value) =>                             // call your own RPC
      userService.createUser(email: value['email'] as String, name: value['name'] as String);

  @override
  Future<void> delete(JsonMap value) =>
      userService.archiveUser(value[table.idKey] as String);            // archive instead of delete
}
```

## The interface

```dart
abstract class CmsDelegate {
  abstract final String idKey;                                          // usually 'id'

  Future<List<JsonMap>> get({
    CmsFunctionsSortingParams? sorting,
    CmsFilter filter,
    required CmsFunctionsPagingParams paging,
  });

  Future<JsonMap> update(JsonMap value, JsonMap oldValue);
  Future<JsonMap> create(JsonMap value);
  Future<void>    delete(JsonMap value);
}
```

`JsonMap = Map<String, dynamic>`. The returned `JsonMap` from `get/create/update` becomes a row in the table. Keys can be dotted paths (`contactData.name`) - see [entries.md](entries.md).

**Delegate lifetime.** Delegates are cheap, stateless value objects: constructing
one inline in `build()` is safe as of v0.2.3 - the table refetches only when
sorting or filter values change, never on delegate identity. Wrapping in
`useMemoized(() => MyDelegate(…))` is a fine tidiness convention (stable identity
for your own keyed hooks) but not required by the framework. Do memoize the
**GraphQL client** though - see "Client + auth" below.

## Prebuilt delegates

### `CmsFirebaseDelegate` - `utopia_cms_firebase`

```dart
const CmsFirebaseDelegate('products');                                  // collection 'products', idKey 'id'
const CmsFirebaseDelegate('users', idKey: 'uid');
```

Reads/writes a single Firestore collection. `create` uses `collection.add(…)`
(random doc id), `update`/`delete` target `doc(value[idKey])`, and `get` merges
the doc id into each row under `idKey`.

**Known limitation (v0.2.3):** the stock `get()` ignores `sorting`, `filter` and
`paging` entirely and hardcodes `limit(30)`. Column-sort clicks, filter entries
and `pagingLimit` all silently do nothing on Firebase. The workaround is one
reusable subclass that overrides `get()`; every per-entity delegate extends it
instead of `CmsFirebaseDelegate`.

```dart
class AppFirestoreDelegate extends CmsFirebaseDelegate {
  const AppFirestoreDelegate(super.collection, {super.idKey});

  @override
  Future<List<JsonMap>> get({
    CmsFunctionsSortingParams? sorting,
    CmsFilter? filter,                       // base class declares this nullable
    required CmsFunctionsPagingParams paging,
  }) async {
    Query<JsonMap> query = _applyFilter(
      FirebaseFirestore.instance.collection(collection),
      filter ?? const CmsFilter.all(),
    );
    if (sorting != null) {
      query = query.orderBy(sorting.fieldKey, descending: sorting.sortDesc);
    }
    // Firestore has no offset(): fetch offset+limit docs and skip client-side
    // (switch to cursor paging via startAfterDocument if lists grow large).
    final limit = paging.limit;
    if (limit != null) query = query.limit(paging.offset + limit);
    final snapshot = await query.get();
    return snapshot.docs.skip(paging.offset).map((e) => {...e.data(), idKey: e.id}).toList();
  }

  Query<JsonMap> _applyFilter(Query<JsonMap> query, CmsFilter filter) {
    return filter.when(
      all: () => query,
      equals: (field, value) => query.where(field, isEqualTo: value),
      notEquals: (field, value) => query.where(field, isNotEqualTo: value),
      greaterOrEq: (field, value) => query.where(field, isGreaterThanOrEqualTo: value),
      lesserOrEq: (field, value) => query.where(field, isLessThanOrEqualTo: value),
      inList: (field, values) => query.where(field, whereIn: values),
      and: (filters) => filters.fold(query, _applyFilter),
      // No substring match in Firestore - this is a case-sensitive PREFIX match.
      containsString: (field, value, _) => query
          .where(field, isGreaterThanOrEqualTo: value)
          .where(field, isLessThanOrEqualTo: '$value\uf8ff'),
      // Degrade LOUDLY: silently dropping a filter would show wrong rows.
      or: (_) => throw UnsupportedError('CmsFilterOr is not supported on Firestore'),
      not: (_) => throw UnsupportedError('CmsFilterNot is not supported on Firestore'),
    );
  }
}
```

Two Firestore-specific gotchas: `or`/`not` are not expressible, so the code above throws `UnsupportedError` - throwing beats silently returning wrong rows; replace with an in-memory post-filter only when the collection is small (and give search/date entries a single `filterKey` to avoid emitting `CmsFilterOr`). Compound `where` + `orderBy` combos may require a composite index - Firestore throws at runtime with a create-index link. For the full `CmsFilter` algebra see [filters.md](filters.md).

No `archivedFilter` here (unlike Supabase/Hasura). For soft delete, override
`delete()` to flip a flag via `update()`, and AND a
`CmsFilterNotEquals('archived', true)` into your `get()` override.

### `CmsSupabaseDelegate` - `utopia_cms_supabase`

```dart
final delegate = CmsSupabase.instance.delegate(
  client: supabase,
  table: const CmsSupabaseDataTable('user'),                            // table name (+ optional schema, idKey)
  archivedFilter: const CmsFilterNotEquals('archived', true),           // optional soft-delete
);
```

`CmsSupabaseDataTable(String name, {String idKey = 'id', String? schema})` -
schema-qualified table reference. `archivedFilter` is AND-ed into every `get`
and used by `delete` to *archive* rows instead of removing them (sets the
archive field via `update`). When subclassing, `supabaseService` is the first
**positional** constructor parameter:
`MyDelegate(super.supabaseService, {required super.client}) : super(table: …)`.

### `CmsHasuraDelegate` - `utopia_cms_hasura`

```dart
// Declare your tables + field projections once (typically in lib/tables.dart):
class AppTables {
  const AppTables._();
  static const users = CmsHasuraDataTable('users');
  static const orders = CmsHasuraDataTable('orders');
}

class AppTableFields {
  const AppTableFields._();
  static const users = {
    CmsGraphQLField('id'),
    CmsGraphQLField('email'),
    // Nested field set = relationship join in the projection:
    CmsGraphQLField('company', {CmsGraphQLField('id'), CmsGraphQLField('name')}),
  };
}

const hasura = CmsHasura(namingConvention: CmsHasuraNamingConvention.graphql);

class UserDelegate extends CmsHasuraDelegate {
  UserDelegate(super.hasuraService, {required super.client})
      : super(table: AppTables.users, fields: AppTableFields.users);
}

// In the page: UserDelegate(hasura.service, client: client)
```

Requires a `CmsHasuraDataTable` reference and a set of `CmsGraphQLField`
describing the projection (which fields to select, plus nested sets for joins -
field sets are plain consts, so one set can be reused inside another). Keep the
registry file honest: delete table/field consts that no page references.

Pick the naming convention matching your server's
`HASURA_GRAPHQL_DEFAULT_NAMING_CONVENTION`:

- `CmsHasuraNamingConvention.hasura` (constructor default) - uniform snake_case
  for fields, types, arguments and enum values (`users_aggregate`, `order_by`).
- `CmsHasuraNamingConvention.graphql` - camelCase fields/arguments, capitalized
  types, SNAKE_UPPERCASE enum values (`usersAggregate`, `orderBy`).

There is no `.default` value; `.hasura` is the default.

#### Client + auth

Build the `client:` every delegate takes with the provided factory - don't
hand-roll `HttpLink`/`AuthLink`:

```dart
// In the shell screen. Memoize: createClient builds a link chain per call.
final client = useMemoized(
  () => CmsGraphQL.instance.createClient(
    'https://api.example.com/v1/graphql',
    tokenProvider: () async => 'Bearer ${await authService.currentUser?.getIdToken()}',
  ),
);
// Pass `client` into every page; delegates take it via `required super.client`.
```

- `createClient(uri, {header, tokenProvider, reporter})` - `header` defaults to
  `'Authorization'`; the async `tokenProvider` can refresh tokens per request;
  an optional `reporter` (utopia_reporter) logs every request/response.
- `CmsHasura.instance.createAdminClient(uri, secret: …)` presets the
  `x-hasura-admin-secret` header - local development only, never ship it.
- Queries run with `FetchPolicy.noCache` - the table always shows fresh data.

#### Pitfall: sorting on aggregate columns

A sortable column over an aggregate uses an entry key that mirrors the **result
JSON** (`orders_aggregate.aggregate.count`), but Hasura's `order_by` argument
omits the inner `aggregate` level (`orders_aggregate.count`). The service builds
`order_by` by naively splitting the key on `.`, so remap it in `get()`:

```dart
@override
Future<List<JsonMap>> get(
    {CmsFunctionsSortingParams? sorting, CmsFilter filter = const CmsFilter.all(), required CmsFunctionsPagingParams paging}) {
  sorting = sorting?.copyWith(
    fieldKey: sorting.fieldKey.replaceFirst('orders_aggregate.aggregate', 'orders_aggregate'),
  );
  return super.get(sorting: sorting, filter: filter, paging: paging);
}
```

### GraphQL without Hasura - `utopia_cms_graphql`

**Known limitation (v0.2.3):** there is **no** `CmsGraphQLDelegate` - the
package is the document-building layer the Hasura package sits on, not a
delegate. For a non-Hasura GraphQL backend, implement `CmsDelegate` yourself on
top of `CmsGraphQLService`.

What the package exports: `CmsGraphQL` (`createClient` plus the `service` /
`clientService` singletons), `CmsGraphQLService` (`query` / `mutate` - build an
operation document from a name + `CmsGraphQLFields` projection + `arguments`,
run it, return the aliased `result` payload), `CmsGraphQLField`, and AST helper
extensions (`toValueNode()` on `String`, `toValueNodeUnsafe()` on any JSON-ish value).

```dart
class ArticleDelegate implements CmsDelegate {
  static const _fields = {
    CmsGraphQLField('id'),
    CmsGraphQLField('title'),
    CmsGraphQLField('author', {CmsGraphQLField('id'), CmsGraphQLField('email')}),
  };

  final CmsGraphQLService service;                  // CmsGraphQL.instance.service
  final GraphQLClient client;

  const ArticleDelegate(this.service, {required this.client});

  @override
  String get idKey => 'id';

  @override
  Future<List<JsonMap>> get({
    CmsFunctionsSortingParams? sorting,
    CmsFilter filter = const CmsFilter.all(),
    required CmsFunctionsPagingParams paging,
  }) async {
    final result = await service.query(
      client,
      name: 'articles',                             // query field in your schema
      fields: _fields,
      arguments: {
        'limit': paging.limit.toValueNodeUnsafe(),
        'offset': paging.offset.toValueNodeUnsafe(),
        // Map `filter`/`sorting` onto your schema's arguments - see filters.md
        // for walking the CmsFilter tree.
      },
    );
    return (result! as List).cast<JsonMap>();
  }

  @override
  Future<JsonMap> create(JsonMap value) => _save('createArticle', value);

  @override
  Future<JsonMap> update(JsonMap value, _) => _save('updateArticle', value);

  Future<JsonMap> _save(String name, JsonMap value) async {
    final result = await service.mutate(
      client,
      name: name,
      fields: _fields,                              // selection on the returned row
      arguments: {'input': value.toValueNodeUnsafe()},
    );
    return result! as JsonMap;
  }

  @override
  Future<void> delete(JsonMap value) async {
    await service.mutate(
      client,
      name: 'deleteArticle',
      arguments: {'id': (value['id'] as String).toValueNode()},
    );
  }
}
```

`query`/`mutate` also accept `variableTypes` + `variables` when you'd rather
send values as GraphQL variables than inline argument nodes. Failed operations
throw the client's `OperationException`.

### Service toolbox

The prebuilt delegates are thin wrappers over per-backend services. Overrides
should call these instead of dropping to raw client calls - `query()` already
translates `CmsFilter`, sorting and paging:

| Backend | Service | Methods |
|---|---|---|
| Supabase | `CmsSupabaseService` (`CmsSupabase.instance.service`) | `query`, `insert`, `insertOne`, `updateById`, `delete` (by filter), `deleteById` |
| Hasura | `CmsHasuraService` (`CmsHasura.instance.service`) | `query`, `insert`, `insertOne`, `updateByPk`, `updateById`, `delete` (by filter), `deleteByPk`, `buildFilter` (CmsFilter -> `where` AST) |
| Any GraphQL | `CmsGraphQLService` (`CmsGraphQL.instance.service`) | `query`, `mutate` |

## Extending - when and how

Extend a prebuilt delegate when the backend needs create/update **side-effects**
(invite email, related rows), **soft delete**, a writable **subset of fields**,
**RPC / edge-function** CRUD, a **pre-filtered view** over the same table, or
server-side **defaulted / derived** fields. Override **only** the methods that
change. Common patterns:

### Default-enrichment create

The smallest useful override: inject defaults the admin never types, then call
`super.create`. Show such fields as read-only columns
(`CmsEntryModifier(editable: false, initializable: false)` - see [entries.md](entries.md)).

```dart
@override
Future<JsonMap> create(JsonMap value) => super.create({
      ...value,
      if (!value.containsKey('createdAt')) 'createdAt': DateTime.now().toIso8601String(),
      if (!value.containsKey('status')) 'status': 'pending',
    });
```

### Pre-filter the list (fixed-filter views)

`archivedFilter` is typed `CmsFilterNotEquals?` - it cannot express an
`equals` / `inList` / range fixed filter. Any other always-on filter goes
through a `get()` override with `CmsFilterAnd`. Parameterize one delegate class
with a flag to back both the full page and the filtered view:

```dart
class OrderDelegate extends CmsHasuraDelegate {
  final bool pendingOnly;

  const OrderDelegate(super.hasuraService, {required super.client, this.pendingOnly = false})
      : super(table: AppTables.orders, fields: AppTableFields.orders);

  @override
  Future<List<JsonMap>> get(
      {CmsFunctionsSortingParams? sorting, CmsFilter filter = const CmsFilter.all(), required CmsFunctionsPagingParams paging}) {
    final fixed = CmsFilterAnd([if (pendingOnly) const CmsFilterEquals('status', 'PENDING'), filter]);
    return super.get(sorting: sorting, filter: fixed, paging: paging);
  }
}
```

### Read from a view, write to the table

When the page needs columns that live in other tables (joined metadata,
aggregates), read from a DB **view** and keep writes on the base table.
Bypassing `super.get()` bypasses `archivedFilter` - AND it back in (pitfall #1):

```dart
class UserDelegate extends CmsSupabaseDelegate {
  static const _readView = CmsSupabaseDataTable('user_cms');   // view with joined columns

  UserDelegate(super.supabaseService, {required super.client})
      : super(table: const CmsSupabaseDataTable('user'),
              archivedFilter: const CmsFilterNotEquals('archived', true));

  @override
  Future<List<JsonMap>> get(
      {CmsFunctionsSortingParams? sorting, CmsFilter filter = const CmsFilter.all(), required CmsFunctionsPagingParams paging}) {
    final fixed = archivedFilter == null ? filter : CmsFilterAnd([archivedFilter!, filter]);
    return supabaseService.query(client, table: _readView, sorting: sorting, filter: fixed, paging: paging);
  }
}
```

### Whitelist or strip fields on update

The row JSON contains every fetched key, and Hasura/Supabase `update` writes
them all back - failing on joined / aggregate / view-only keys (not columns!),
or silently clobbering server-owned ones. Strip the offenders, or - mandatory
whenever `get()` reads from a view - whitelist what is editable:

```dart
static const _allowed = {'name', 'surname', 'phone'};

@override
Future<JsonMap> update(JsonMap value, _) async {
  final filtered = JsonMap.fromEntries(
    value.entries.where((e) => e.key == table.idKey || _allowed.contains(e.key)),
  );
  return supabaseService.updateById(client, table: table, object: filtered);
}
```

Post-update side-effects (privileged columns behind a backend action) also
belong in the delegate, not the UI. In a `CmsHasuraDelegate` subclass:

```dart
@override
Future<JsonMap> update(JsonMap value, JsonMap oldValue) async {
  final payload = {...value}..remove('orders_aggregate');     // joined field, not a column
  final result = await super.update(payload, oldValue);
  // CmsHasuraService keeps its CmsGraphQLService private - use the singleton.
  await CmsGraphQL.instance.service.mutate(client, name: 'setUserRole', arguments: {
    'id': (value['id'] as String).toValueNode(),
    'role': (value['role'] as String).toValueNode(),
  });
  return result;
}
```

### Derived fields on state transitions (using oldValue)

`update`'s second parameter is the unmodified pre-edit row - diff it against the
patch to detect that a flag *actually* flipped before touching derived fields:

```dart
@override
Future<JsonMap> update(JsonMap value, JsonMap oldValue) {
  final wasFeatured = oldValue['isFeatured'] as bool? ?? false;
  final isFeatured = value['isFeatured'] as bool? ?? wasFeatured;
  // Only touch the derived field when the toggle actually changes -
  // recomputing on every save would silently extend the active window.
  if (isFeatured == wasFeatured) return super.update(value, oldValue);
  return super.update(
    {...value, 'featuredUntil': isFeatured ? nextWindowEnd().toIso8601String() : null},
    oldValue,
  );
}
```

### Natural keys and cascading deletes (Firestore)

Three things the stock Firebase delegate cannot do: semantic doc ids (its
`create` always uses `collection.add`), subcollection cleanup on delete, and
field removal (use `FieldValue.delete()` as the value in an `update` payload):

```dart
class ScheduleDelegate extends AppFirestoreDelegate {
  const ScheduleDelegate() : super('schedules', idKey: 'date');

  CollectionReference<JsonMap> get _ref => FirebaseFirestore.instance.collection(collection);

  @override
  Future<JsonMap> create(JsonMap value) async {
    // CmsDateEntry serializes DateTime.toString(); trim to YYYY-MM-DD for the id.
    final id = (value['date'] as String?)?.substring(0, 10);
    if (id == null) throw const CmsDelegateException('Date is required');
    final payload = {...value, 'date': id};
    await _ref.doc(id).set(payload);                          // doc(id).set, not add()
    return payload;
  }

  @override
  Future<void> delete(JsonMap value) async {
    final id = value[idKey]! as String;
    final children = await _ref.doc(id).collection('entries').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in children.docs) batch.delete(doc.reference);  // cascade: stock delete orphans these
    batch.delete(_ref.doc(id));
    await batch.commit();
  }
}
```

## Custom delegate (unsupported backend)

```dart
class MyApiDelegate implements CmsDelegate {
  final MyApiClient api;
  MyApiDelegate(this.api);

  @override
  String get idKey => 'id';

  @override
  Future<List<JsonMap>> get({
    CmsFunctionsSortingParams? sorting,
    CmsFilter filter = const CmsFilter.all(),
    required CmsFunctionsPagingParams paging,
  }) async {
    final res = await api.list(
      offset: paging.offset, limit: paging.limit,
      sort: sorting?.fieldKey, desc: sorting?.sortDesc ?? false,
      filter: _filterToQuery(filter),                                   // translate to your backend's filter format
    );
    return res.map((e) => e.toJson()).toList();
  }

  @override
  Future<JsonMap> create(JsonMap value)             => api.create(value).then((e) => e.toJson());
  @override
  Future<JsonMap> update(JsonMap value, JsonMap _)  => api.update(value[idKey] as String, value).then((e) => e.toJson());
  @override
  Future<void>    delete(JsonMap value)             => api.delete(value[idKey] as String);
}
```

The hardest part is usually translating `CmsFilter` into your backend's filter
syntax - see [filters.md](filters.md) for the full algebra and the
"Implementing a custom delegate" section. For a GraphQL API, build on
`CmsGraphQLService` instead of raw documents (see "GraphQL without Hasura").
When the backend can't express part of the algebra, degrade **loudly** (throw
`UnsupportedError`) or post-filter in memory - never silently drop a filter.

## Error handling

Throw `CmsDelegateException(String message)` (exported from
`package:utopia_cms/utopia_cms.dart`) from any delegate method to display that
message in the edit/create overlay - the overlay's submit state maps it via
`mapError`. Any **other** exception type is rethrown and shows **no message** in
the overlay - it only reaches your app-level error handler. So map backend
errors yourself:

```dart
@override
Future<JsonMap> create(JsonMap value) async {
  if (!(value['email'] as String? ?? '').contains('@')) {
    throw const CmsDelegateException('Enter a valid email address.');   // pre-validate before the network call
  }
  try {
    return await userService.createUser(value);                         // RPC / edge function
  } on MyBackendException catch (e) {
    // Prefer the server's message; fall back to a static one.
    throw CmsDelegateException(e.details?['message'] as String? ?? 'Failed to create user.');
  }
}
```

## Rules

- **No CRUD service class for admin code.** If you have `lib/services/xxx_service.dart` doing CRUD against the same table that an admin page renders, fold it into a delegate.
- **Extend prebuilt delegates** for business logic. Implement `CmsDelegate` directly only when no prebuilt fits.
- **Override only what changes.** Don't override `get` just to copy the parent's logic.
- **`idKey` matters.** It identifies rows in the table's internal state and the update/delete RPC path. Default `'id'`; override for collections where the primary key is different (`uid`, `userId`, etc.).
- **Return the authoritative saved row** from `create / update`. After a successful save the table resets paging and refetches by itself - never refetch manually. The returned map is *not* swapped into the table; it is passed to `addOnSavedCallback` callbacks (management sections saving relationships, media). In-place row swap exists only for `CmsTableAction` results with `shouldUpdateTable: true` - see [actions.md](actions.md).
- **Use `CmsDelegateException` for user-facing errors.** Any other exception is rethrown and shows no message in the overlay - it only reaches your app-level error handler.
- **Soft delete = `archivedFilter` parameter** on the Supabase / Hasura delegates (typed `CmsFilterNotEquals?`). `CmsFirebaseDelegate` has no such parameter - override `delete()` to set a flag via `update()` and filter archived rows in your `get()` override.
- **Delegates are stateless value objects.** Inline construction in `build()` is fine; memoize the GraphQL *client*, not the delegate.

## Pitfalls

1. **Forgetting to AND the archived filter.** If you override `get` on a delegate that has `archivedFilter`, remember to AND it back in (or call `super.get`).
2. **Mutating `value` in update.** Treat the input as immutable; build a new map (`{...value}`). Row maps can be shared with table state.
3. **Returning a partial row from `create`/`update`.** The table itself recovers (it refetches after every save), but `addOnSavedCallback` callbacks receive exactly what you return - a missing `id` breaks management sections that save relationships against the new row. Return the row as persisted.
4. **Confusing `update(value, oldValue)`.** `oldValue` is the unmodified pre-edit row. Most delegates ignore it; use it for transition detection (see "Derived fields on state transitions").
5. **Hasura/Supabase update writes every fetched key.** Joined/aggregate/view-only fields in the row JSON are not columns - strip or whitelist before `super.update` (see "Whitelist or strip fields on update").

## See also

- [filters.md](filters.md) - `CmsFilter` algebra used by `get`
- [table-page.md](table-page.md) - how the table consumes the delegate
- [management-sections.md](management-sections.md) - `addOnSavedCallback` consumers of your `create`/`update` result
- [anti-patterns.md](anti-patterns.md) - what a hand-rolled service looks like
