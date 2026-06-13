---
title: Theming with CmsThemeData
impact: MEDIUM
tags: theme, colors, typography
---

# Skill: Theming

`CmsThemeData` is the single source of truth for the CMS look-and-feel. Define it
once at the app root, provide it to the widget tree, and pass into `CmsWidget`.
Every prebuilt CMS widget consumes the same theme via Provider.

## Quick Pattern

### ❌ Anti-pattern

Hard-coded colors inside individual pages (`Container(color: AppColors.background)`),
one `CmsThemeData` per page, or text styles without an explicit color (CMS widgets
null-assert `style.color!`).

### ✅ utopia_cms way

```dart
// lib/app/common/constant/cms_theme_data.dart - map your design tokens to the CMS theme
final cmsThemeData = CmsThemeData(
  colors: CmsThemeColors(
    primary:  AppColors.primary,    // primary + accent = the 2-stop button/menu gradient;
    accent:   AppColors.primary,    // equal values flatten it (accent also tints row hover)
    field:    AppColors.backgroundSecondary,
    canvas:   AppColors.background,
    disabled: AppColors.textSecondary,
    text:     AppColors.textPrimary,
    error:    AppColors.error,
  ),
  textStyles: CmsThemeTextStyles(
    // Every style needs an explicit non-null color: CMS widgets dereference
    // style.color! (e.g. table-header sort icons, as of v0.2.3). Styles whose
    // color comes from the Material theme (typical GoogleFonts setup) crash.
    header:  AppText.headline.copyWith(color: AppColors.textPrimary),
    title:   AppText.title.copyWith(color: AppColors.textPrimary),
    label:   AppText.body.copyWith(color: AppColors.textPrimary),
    text:    AppText.body.copyWith(color: AppColors.textPrimary),
    caption: AppText.body.copyWith(fontSize: 10, color: AppColors.textSecondary),
    button:  AppText.button.copyWith(color: Colors.white),
  ),
  borderRadius: const BorderRadius.all(Radius.circular(8)),
  fieldContentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  pageTopPadding: 16.0,
  menuShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
  menuRadius: const BorderRadius.all(Radius.circular(8)),
  shortButtonWidth: 120,
);

// App.dart
return Provider<CmsThemeData>.value(
  value: cmsThemeData,
  child: MaterialApp.router(...),
);

// Main screen
final theme = Provider.of<CmsThemeData>(context);
return CmsWidget(theme: theme, items: [...]);
```

## Structure

`CmsThemeData` groups its fields into `CmsThemeColors` and `CmsThemeTextStyles`:

### `CmsThemeColors`

- `primary` / `accent` - the two stops of the gradient behind `CmsButton` and the
  menu (`primary` bottom-left, `accent` top-right). Setting both to the same color
  deliberately flattens the gradient. `primary` also drives cursors and the date
  picker; `accent` doubles as the table-row hover highlight and the table-header
  underline - equal primary/accent values also calm the hover.
- `field` - input field background.
- `canvas` - page background.
- `disabled` - disabled text / icons, and the disabled-button fill.
- `text` - primary text.
- `error` - error states.

### `CmsThemeTextStyles`

- `header` - large headings (top of pages).
- `title` - section titles.
- `label` - field labels.
- `text` - body text in previews and forms.
- `caption` - small auxiliary text.
- `button` - button label text.

**Every style must carry a non-null `color`.** CMS widgets dereference
`style.color!` (the table-header sort icons do, as of v0.2.3), so a style whose
color is painted by the Material theme crashes at runtime. When mapping a design
system, `copyWith(color: ...)` each of the six styles.

## Custom panels - using the theme

When you build a non-table admin page (dashboard, bulk import) inside the
`CmsWidget` shell, consume the same theme to stay consistent. Use the prebuilt
UI primitives:

- **`CmsHeader`** - page-top header matching the table-page header.
- **`CmsButton`** - themed gradient button.
- **`CmsTextField`** - themed text field.
- **`CmsSwitch`** - themed switch.
- **`CmsLoader`** - themed spinner.
- **`CmsMockLoadingBox`** - placeholder skeleton box.
- **`CmsFieldWrapper`** - wraps a custom input with the standard chrome (filled background, radius, padding).

### `CmsHeader`

```dart
const CmsHeader({required String text, bool navigateBack = false})
```

`text` renders in `textStyles.header`. `navigateBack: true` prepends a clickable
"Back" row that pops the navigator - the intended back affordance for sub-pages.

### `CmsButton`

```dart
const CmsButton({
  required Widget child,            // usually Text(...)
  required void Function() onTap,
  bool isEnabled = true,            // false: greyed out, taps blocked
  bool loading = false,             // swaps child for a spinner - async-submit affordance
  bool dense = false,               // 44px tall instead of 60px
  double maxWidth = 300,
  List<Color>? colors,              // overrides the primary/accent gradient
})
```

### `CmsTextField`

The building block for custom entries, custom filter entries, and custom pages:

```dart
const CmsTextField({
  required String value,
  required void Function(String?) onChanged,  // emits null (not '') when emptied!
  TextInputType? keyboardType,
  bool obscureText = false,         // password masking
  bool readOnly = false,
  FocusNode? focusNode,
  Widget? label,
  Widget? error,                    // renders above the field, caption style + error color
  Widget? hint,
  Widget? prefix,
  Widget? suffix,
  List<TextInputFormatter>? formatters,
  int lines = 1,
  int? maxLength,
  void Function()? onTap,           // only fires while editable (readOnly: false)
})
```

- `onChanged` emits **`null`** when the field is emptied - this is why empty entry
  values arrive as `null` in the row map and why "required" checks compare against null.
- Tap-to-open fields (pickers, selectors): set `readOnly: true` and wrap the field
  in your own `GestureDetector` - `readOnly` makes the field ignore pointer events,
  so the built-in `onTap` won't fire. This is exactly how `CmsDatePicker` is built.

**Known limitation (v0.2.3):** `prefix`, `hint`, `lines` and `maxLength` are
accepted but not wired to the underlying `TextField`; only `label`, `error` and
`suffix` actually render, and input is single-line.

### Example: custom dashboard page

```dart
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CmsHeader(text: 'Dashboard'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: MetricCard(label: 'Users', value: '1,234')),
            const SizedBox(width: 8),
            Expanded(child: MetricCard(label: 'Sales', value: '\$45,678')),
          ],
        ),
        const SizedBox(height: 16),
        CmsButton(
          child: const Text('Export CSV'),
          onTap: () { /* start export */ },
          // loading: exporting, isEnabled: !exporting  - for async submits
        ),
      ],
    );
  }
}
```

### Custom widgets inside the shell

When a page hand-rolls raw Material fields (a config form, a section editor),
derive their `InputDecoration` from the provided `CmsThemeData` so they match
`CmsFieldWrapper`'s look: filled `colors.field`, theme `borderRadius`, no border.
One shared helper, not per-widget styling:

```dart
InputDecoration cmsFilledFieldDecoration(BuildContext context, {String? labelText}) {
  final theme = Provider.of<CmsThemeData>(context);
  final border = OutlineInputBorder(borderRadius: theme.borderRadius, borderSide: BorderSide.none);
  return InputDecoration(
    labelText: labelText,
    filled: true,
    fillColor: theme.colors.field,
    border: border, enabledBorder: border, focusedBorder: border,
    isDense: true,
  );
}
```

Without this, the default Material `OutlineInputBorder` draws a pale outline that
clashes with a dark canvas - the field instantly reads as "foreign". Note the CMS
context extensions (`context.colors`, `context.textStyles`) are internal as of
v0.2.3; app code uses `Provider.of<CmsThemeData>`.

## Login screen outside the shell

Auth screens live outside `CmsWidget`, but the exported widgets (`CmsTextField`,
`CmsButton`, `CmsLoader`, `CmsFieldWrapper`) work standalone, so the login matches
the panel with zero extra styling (the root `Provider<CmsThemeData>` covers them):

```dart
final emailState = useState('');
final passwordState = useState('');
final obscuredState = useState(true);

CmsTextField(
  label: const Text('E-mail'),
  value: emailState.value,
  onChanged: (it) => emailState.value = it ?? '',
),
CmsTextField(
  label: const Text('Password'),
  value: passwordState.value,
  onChanged: (it) => passwordState.value = it ?? '',
  obscureText: obscuredState.value,
  suffix: IconButton(
    icon: Icon(obscuredState.value ? Icons.visibility : Icons.visibility_off),
    onPressed: obscuredState.toggle,
  ),
),
CmsButton(
  child: const Text('Sign in'),
  onTap: submit,
  loading: submitInProgress,   // pair with useSubmitState from utopia_hooks
)
```

`CmsDropdownField` is internal (not exported) as of v0.2.3 - dropdowns outside
CMS entries need your own widget.

## Rules

- **One `CmsThemeData` per admin app.** Defined in a single constants file, exposed via Provider at root.
- **Pass it to `CmsWidget(theme: ...)`** explicitly - the default is the framework's neutral theme, which is rarely what you want.
- **Every text style carries an explicit non-null color** - CMS widgets bang `style.color!`.
- **Custom pages inside the shell consume the same theme** via Provider - use the CMS UI primitives, not raw Flutter widgets, so the look stays coherent.
- **Don't override theme per page.** If a specific column needs an emphasis (e.g. red for "Rejected"), do it inside `CmsEntry.previewBuilder` or in a custom entry.
- **Light/dark mode** isn't built in. If you need it, switch the whole `cmsThemeData` value based on a setting; rebuild the subtree.

**Known limitation (v0.2.3):** framework chrome strings ("Create", "Delete",
"Manage", "Back") are hardcoded English - there is no l10n hook. The theme
controls look, not copy.

## Pitfalls

1. **Forgetting to provide the theme.** `CmsWidget` falls back to `CmsThemeData.defaultTheme` - a workable but generic look.
2. **Text styles without explicit colors.** A null `style.color` crashes CMS widgets at runtime (the sort icons null-assert it), and the crash only appears when that widget renders - e.g. on the first sortable table.
3. **Mixing `Theme.of(context)` (Material) and `CmsThemeColors` (CMS).** They are *separate* themes. The Material one applies to non-CMS widgets you mount inside the shell; the CMS one applies inside the framework's widgets.
4. **Per-page theme variants.** Don't - admin UI consistency is a feature.
5. **Color tokens not mapping cleanly to your design system.** Map your design tokens once in the central `cmsThemeData` file; reference those tokens, not the `CmsThemeColors` values, in custom pages.

## See also

- [shell-cms-widget.md](shell-cms-widget.md) - where the theme is passed in
- [table-page.md](table-page.md) - table page styling is controlled here
