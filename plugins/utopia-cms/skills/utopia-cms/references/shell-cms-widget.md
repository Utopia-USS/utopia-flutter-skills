---
title: Shell with CmsWidget and CmsWidgetItem
impact: CRITICAL
tags: shell, navigation, menu
---

# Skill: Admin Shell

`CmsWidget` is the **whole admin shell** - left/side menu, selected page state,
themed background, and the slot that swaps page content via a fade-indexed-stack.
Use one per admin app; everything else hangs off it.

## Quick Pattern

### ❌ Anti-pattern

```dart
// Separate route per admin table
MaterialApp(
  routes: {
    '/users':    (_) => AdminScaffold(body: UsersScreenView(...)),
    '/products': (_) => AdminScaffold(body: ProductsScreenView(...)),
  },
)
// → uses Navigator.pushNamedAndRemoveUntil to switch
```

### ✅ utopia_cms way

```dart
// app_routing.dart - the URL owns the selected page
GoRoute(
  path: '/admin/:pageId',
  pageBuilder: (_, state) => MaterialPage(
    key: const ValueKey('admin'),   // stable key: page switches must NOT remount the shell
    child: MainScreen(pageId: state.pathParameters['pageId'] ?? 'users'),
  ),
)

// main_screen.dart
class MainScreen extends HookWidget {
  final String pageId;
  const MainScreen({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final authService = useInjected<AuthService>();
    final theme = Provider.of<CmsThemeData>(context);

    return CmsWidget(
      theme: theme,
      // URL -> menu (route param) and menu -> URL (context.go), in one binding
      selectedPageId: MutableValue.computed(() => pageId, (id) => context.go('/admin/$id')),
      items: [
        CmsWidgetItem.page(id: 'users',    icon: Icon(Icons.people),          title: Text('Users'),    content: UsersPage()),
        CmsWidgetItem.page(id: 'products', icon: Icon(Icons.shopping_basket), title: Text('Products'), content: ProductsPage()),
        CmsWidgetItem.custom(flex: 1),                                  // spacer pushes the action to the bottom
        CmsWidgetItem.action(
          icon: Icon(Icons.logout),
          title: Text('Sign out'),
          onPressed: () async {
            await authService.signOut();
            if (context.mounted) context.go('/sign-in');
          },
        ),
      ],
    );
  }
}
```

No outer `Scaffold` - `CmsWidget` builds its own (canvas background included).

## API

### `CmsWidget`

```dart
CmsWidget({
  required List<CmsWidgetItem> items,
  CmsThemeData? theme,                          // falls back to CmsThemeData.defaultTheme
  MutableValue<String>? selectedPageId,         // omit to let the widget own state
  CmsWidgetMenuParams menuParams = const CmsWidgetMenuParams(),
})
```

- **`selectedPageId`** - pass `MutableValue.computed(() => pageId, onPageChanged)`
  to bind to your router, or a `useState<String>('...')` directly for local state
  (its return type implements `MutableValue`), or `null` to auto-select the first page.
- **`menuParams`** - menu type / expand behavior / background colors (see below).

### `CmsWidgetItem` (sealed union)

```dart
CmsWidgetItem.page({
  required String id,
  required Widget icon,
  required Widget title,
  required Widget content,         // your page (HookWidget → CmsTablePage in 80% of cases)
})

CmsWidgetItem.action({
  required Widget icon,
  required Widget title,
  required void Function() onPressed,
})

CmsWidgetItem.custom({
  int? flex,                       // spacer; use flex: 1 to push subsequent items to the bottom
  Widget child = const SizedBox(),
})
```

### `CmsWidgetMenuParams`

```dart
CmsWidgetMenuParams({
  CmsMenuType type = CmsMenuType.floating,              // floating | standard
  CmsMenuBehavior behavior = CmsMenuBehavior.flexible,  // flexible | collapsed | expanded
  List<Color>? backgroundColors,                        // menu gradient stops
})
```

- **`type`** - `CmsMenuType.floating` (default): rounded card inset from the
  window edges, drawn with the theme's `menuShadow` / `menuRadius`.
  `CmsMenuType.standard`: full-height rail flush to the window edge, no rounding.
- **`behavior`** - `CmsMenuBehavior.flexible` (default): icons-only rail (70px)
  that expands to 200px on hover, but only when the viewport is wider than
  `CmsWidget.contentWidth * 1.3` (780px). `CmsMenuBehavior.collapsed`: always
  icons-only. `CmsMenuBehavior.expanded`: always expanded - the answer to
  "keep the sidebar open".
- **`backgroundColors`** - menu background gradient; defaults to the theme's
  `[primary, accent]`. For a flat fill pass the same color twice, e.g.
  `[Color(0xff2B2926), Color(0xff2B2926)]`.

## Integration with `go_router`

`CmsWidget` does **not** own the URL. Make the route param the single source of
truth and bind it both ways with `MutableValue.computed`:

```dart
GoRoute(
  path: '/admin/:pageId',
  pageBuilder: (_, state) => MaterialPage(
    key: const ValueKey('admin'),   // stable page identity - load-bearing, see below
    child: MainScreen(pageId: state.pathParameters['pageId'] ?? 'users'),
  ),
)

// MainScreen.build
selectedPageId: MutableValue.computed(
  () => pageId,                       // URL -> menu (covers browser back/forward)
  (id) => context.go('/admin/$id'),   // menu -> URL
)
```

**The stable `ValueKey` on `MaterialPage` is load-bearing.** Without it, every
`context.go` creates a new page identity, the whole shell remounts, and all hook
state inside it (table rows, filters, scroll positions) is lost on every menu
click. With the const key the same `MainScreen` element survives URL changes and
only `pageId` updates.

Avoid the one-way variant (`useState(pageId)` plus an effect that calls
`context.go` when it changes): menu clicks update the URL, but browser
back/forward updates only the route param, not the state, so the menu sticks on
the old page. `MutableValue.computed` reads the route param directly - both
directions stay in sync.

With an old-style `Navigator`:

```dart
selectedPageId: MutableValue.computed(
  () => pageId,
  (newId) => navigator.pushReplacementNamed('/admin/$newId'),
)
```

## Rules

- **Exactly one `CmsWidget` per admin app.** Multiple `CmsWidget`s mean you've reinvented routing.
- **Every admin page is a `CmsWidgetItem.page`.** A page can be a `CmsTablePage` (the common case) or any custom `HookWidget` (dashboard, bulk import, etc.).
- **Pages receive only data dependencies** (the client / services their delegate needs). The shell owns page switching - never thread navigation callbacks like `onPageChanged` into page constructors.
- **Sign-out / shortcuts = `CmsWidgetItem.action`.** Not a custom button outside the shell.
- **Use `CmsWidgetItem.custom(flex: 1)` as a spacer** to push trailing items (typically sign-out) to the bottom of the menu.
- **The theme is provided once at the root** and passed into `CmsWidget` (or set the default via Provider) - never set per page.
- **The shell screen itself is `HookWidget`**; `CmsWidget` handles the rest. Don't wrap it in a `StatefulWidget`.

## Pitfalls

1. **Custom Scaffold wrapping `CmsWidget`.** Don't put `Scaffold` *inside* a page that's already a `CmsWidgetItem.page.content` - `CmsWidget` is the Scaffold.
2. **Stale selectedPageId.** If you pass `selectedPageId` derived from a route param without a setter that navigates, taps on the menu won't update the URL. Use `MutableValue.computed(() => pageId, onPageChanged)`.
3. **Unstable page identity in the router.** A `builder:`-only `GoRoute` (or a `MaterialPage` without a const key) gives the shell a new identity on every page switch, remounting it and wiping table/filter state. Use `pageBuilder` + `MaterialPage(key: const ValueKey('admin'), ...)`.
4. **Custom drawer / nav rail.** The menu is part of `CmsWidget` - don't add a second one.

## See also

- [table-page.md](table-page.md) - what to put inside `CmsWidgetItem.page.content`
- [theme.md](theme.md) - providing `CmsThemeData` at root
- [anti-patterns.md](anti-patterns.md) - failure modes when shell is hand-rolled
