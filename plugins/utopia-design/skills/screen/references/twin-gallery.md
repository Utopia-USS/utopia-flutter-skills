# The HTML Twin as a Design Input

## What this covers

The packaged HTML twin (`twin/` in the resolved `utopia_ui` package) as both a design
input in its own right and a visual reference while mapping a design element to a
manifest id. The structural contract documented here matches the shipped files; for a
specific component's actual rendered appearance, the shipped files themselves are the
truth - see "Reading specimen specifics" at the end of this doc.

Consumer note: the shipped package twin always renders the DEFAULT theme (its HTML
links its own `tokens.css` via relative hrefs); to see a consumer rebrand, pair these
shell files with the project's regenerated `tokens.css` per **utopia-design:sync**'s
[regeneration.md](../../sync/references/regeneration.md) ("Viewing a
consumer twin") rather than repeating the steps here.

## Status note: shipped

The real twin files ship in the `utopia_ui` package: `components.html` covers all 37
manifest ids (29 styled specimens, 8 "no visual twin" note entries), `gallery.html`
(composed from `gallery.src.html`) carries 14 sections,
`components.css` is `var(--utopia-*)`-only, and `validate_twin` passes with zero
findings. The structural contract below matches the shipped files exactly - and the
files themselves, read from the resolved package root, are always the final truth for
any specific specimen's markup or CSS.

## The bundle

The bundle contract (`protocol/SPEC.md` 4.1/4.4; matches the shipped files):

> twin/ bundle: tokens.css + tokens.tailwind.css (both GENERATED - never edit),
> components.css (hand-authored, token-driven), components.html (hand-authored),
> gallery.src.html (hand-authored source), gallery.html (COMPOSED from the two - never
> edit), DESIGN.md, fonts/ (Sora + OFL). Static HTML/CSS + minimal vanilla JS, no build
> step - files open directly in a browser.

For this skill's purposes: `tokens.css` / `tokens.tailwind.css` and `DESIGN.md`'s front
matter are **utopia-design:sync**'s regenerated output, never a structure source (there
are no components in a token document); `components.css` and `components.html` /
`gallery.html` are the parts this skill actually reads. Nothing in the bundle requires a
build step - if a twin needs viewing, open the file directly.

## `components.html` structure

The contract (matches the shipped files):

> components.html: one `<section data-utopia-id="<manifest id>">` per manifest
> component, in manifest order; inside, specimen roots ALSO carry data-utopia-id (e.g.
> `<button class="utopia-button" data-utopia-id="button">`). Components without a visual
> twin carry an explicit "no visual twin: <reason>" note element with the same
> data-utopia-id (so id coverage is 100% both directions - validate_twin enforces).

The section wrapper and every specimen root inside it carry the same id, so a styled
component usually has several `data-utopia-id` occurrences (`button` has six or more
specimens). They always carry the *same* id - this is what lets
`validate_twin` check coverage in both directions (SPEC.md 4.4): every manifest id has a
twin section, and every twin section's id resolves to a real manifest component.

"In manifest order" is a real, checkable ordering - read it from the resolved
manifest's `components[]` rather than from a frozen list here (`packageVersion 0.1.0`
has 37 components).

## No-visual-twin note entries

Not every manifest component renders visible chrome of its own. SPEC.md 4.4 names
`multi-widget` as exactly this case - `UtopiaMultiWidget` "builds multiple nested
widgets from a flat list, innermost last": a pure composition helper with no rendered
surface to specimen. Components like this still get a `components.html` section (same
`data-utopia-id`, so coverage stays 100% both directions), but the section holds a
"no visual twin: <reason>" note instead of a styled specimen - `multi-widget` would read
something like "no visual twin: pure composition helper, renders no chrome of its own."
**Never assume a section has a styled specimen** - always check for the note-entry case
before treating a twin section as a rendering reference.

## CSS naming

The contract (matches the shipped files):

> CSS class naming: `.utopia-<id>`, modifiers `.utopia-<id>--<variant>` (e.g.
> --dense), state classes `.is-<state>` mirroring the manifest's `states[]` (e.g.
> `.is-loading`, `.is-disabled`, `.is-selected`). All visual values via
> var(--utopia-*) per SPEC 4.2 naming.

`validate_twin` warns when a component's manifest `states[]` and the `.is-*` classes its
specimens use diverge.

`--utopia-*` custom property naming itself (the token-path-to-CSS-var derivation, the
typography composite expansion, the `textStyle-colors` fold) is fully specified in
`protocol/SPEC.md` section 4.2 - not re-derived here; that section is the single source
of truth for it. What matters for this skill: a specimen's classes tell you its variant
and state (`.utopia-button--dense`, `.is-loading`), and every value inside
`components.css` traces to a `var(--utopia-*)` reference, never a raw literal (the
literals linter in `validate_twin`, SPEC.md 4.5, enforces this on the authoring side -
not this skill's concern to run, just to know it exists when reading `components.css`).

## `gallery.html`

The contract (matches the shipped files):

> gallery.html mirrors the example components page, same order: theme-lab,
> foundations, colors, typography, surfaces, buttons, selection, fields, chips-text,
> loading, table, dialogs, sidebar, principles (14 sections); each section comments
> which example file it mirrors (`example/lib/sections/*`, plus
> `example/lib/widgets/theme_lab.dart` for the theme lab).

`gallery.html` is generated: `generate_twin` composes it from `gallery.src.html`,
replacing each `<!-- utopia-specimen: <id> -->` marker with the matching
`components.html` subtree (SPEC.md 4.1). Never edit it - edit `gallery.src.html` or
`components.html` instead.

Use `gallery.html` when the reference point is "how does the example app arrange these
components together" rather than "what does one component's specimen look like in
isolation" (that's `components.html`'s job).

## Tier-1 specimens

The components with styled specimens today: `button`, `card`, `check-row`, `checkbox`,
`chip`, `chip-list`, `confirm-dialog`, `date-picker`, `dialog`, `divider`,
`dropdown-field`, `ghost-button`, `header`, `labeled-field`, `loader`, `loading-box`,
`radio`, `remove-icon-button`, `search-field`, `sidebar`, `slider`, `switch`,
`switch-field`, `table` (with `table-empty` and `table-search-panel` composed in),
`text-field`, `three-bounce`, `title` - 29 ids. The other 8 are note entries:
`collapsible`, `copyable-text`, `field-wrapper`, `form-layout`, `gradient-background`,
`multi-widget`, `overlay-anchor`, `page-wrapper`.

## The rule

Reference the twin by `data-utopia-id`, and never assume a component has a styled
specimen - always check for the note-entry case first. Today that check has a concrete
answer: the 8 note-entry ids are `collapsible`, `copyable-text`, `field-wrapper`,
`form-layout`, `gradient-background`, `multi-widget`, `overlay-anchor`, `page-wrapper`;
everything else has a styled specimen. For those 8 the twin tells you the id exists and
why it has no specimen - the manifest entry, not the twin, is your
construction reference.

## Reading specimen specifics (shipped files are the truth)

For anything about a specific specimen - its exact markup, class list, or CSS - read the
shipped files directly from the resolved package root (`<utopia_ui root>/twin/`, same
resolution as [component-mapping.md](component-mapping.md) uses for the manifest). This
doc deliberately does not inline specimen markup: the files are versioned with the
package and would drift out of any copy here. Screenshot-based visual comparison between
the twin and the Flutter example app is the library's own release gate, not this
skill's concern.

## See also

- [design-inputs.md](design-inputs.md) - the twin gallery's place among other design
  input types
- [component-mapping.md](component-mapping.md) - what a twin-derived element resolves
  to once its `data-utopia-id` is known
- **utopia-design:sync** - regenerates `tokens.css` / `tokens.tailwind.css` / the
  `DESIGN.md` front matter inside the same bundle; not this skill's concern
