# Nestling design system

Nestling is used one-handed, half asleep, often in a dark room. The design
system exists so that every screen is quiet, predictable and fast to read.
It follows Material Design 3. All tokens live in `lib/src/ui/theme.dart`;
nothing else in the app should introduce a colour, font size, radius or
shadow of its own.

## Principles

1. **Data first, decoration last.** Show the number ("Last feed 27m ago ·
   Left") as text. Don't wrap it in a decorated card, gradient or badge.
2. **Light and calm.** Screens read as warm off-white with a little colour.
   Hierarchy comes from type, spacing and tonal surfaces first.
3. **Sky and mint.** The shipped palette is Sky: a soft sky-blue accent for
   primary actions, mint for selection and the Today summary. Red is reserved
   for errors; no pink.
4. **Kinds are small, gentle colour.** Feed, sleep, nappy and habit colours
   tint icons, chart series and, at very low chroma, the quick-log tiles.
   They never fill a whole screen.
5. **Plain Material.** Use Google's own patterns (Fit, Clock, Settings):
   ListTiles grouped in cards, section headers, dividers only where they
   help. Avoid the "generated" look: no icon-in-a-tinted-circle on every
   row, no tinted container per section, no stacks of chips and badges, no
   filler copy.
6. **3 a.m. ergonomics.** Primary actions sit within thumb reach, targets are
   at least 48dp (quick-log buttons are 72dp, Save is 56dp), one tap saves
   where possible, and every save offers Undo.

## Colour

Built in `NestPalette` for three modes: **light**, **night light** (a darker
light theme used from 6 pm to 6 am when enabled) and **dark**. Roles map
directly onto Material 3 `ColorScheme`. The surface roles and accent are set
to explicit values; containers and kind colours come from HCT tonal palettes
(`material_color_utilities`), so contrast is set by tone, not by eye.

### Roles

> These tables list the Slate palette that shipped first. Sky now ships; its
> key values are under [Palette candidates](#palette-candidates), and every
> role is derived at the same tones, so the contrast figures hold for Sky too.

| Role | Light | Night light | Dark | Use |
|---|---|---|---|---|
| surface (page background) | `#F8F9FA` | `#D5D9DD` | `#0F1113` | Scaffold |
| card | `#FFFFFF` | `#E0E3E6` | `#16191C` | Cards, sheets, grouped lists |
| surfaceContainerLow | `#F4F5F7` | `#D9DCE0` | `#16191C` | Desktop sidebar |
| surfaceContainer | `#F1F3F5` | `#D0D4D8` | `#1E2226` | Navigation bar, menus |
| surfaceContainerHigh | `#EBEDF0` | `#CACED3` | `#262A2F` | Quick-log buttons, dialogs, search field |
| surfaceContainerHighest | `#E4E7EA` | `#C3C8CD` | `#30353A` | Input fills (at 50%) |
| onSurface | `#1A1D21` | `#15181B` | `#E8EAED` | Primary text |
| onSurfaceVariant | `#5B6168` | `#454B52` | `#A9B0B7` | Secondary text, icons |
| outline | `#79808A` | `#656C74` | `#899098` | Text field and outlined button borders (3:1) |
| outlineVariant | `#D0D5DA` | `#B4BAC0` | `#3A4046` | Dividers, card hairlines |
| primary | `#2F6F73` | `#285F63` | `#8CC5C7` | Primary actions, focus, selection |
| onPrimary | `#FFFFFF` | `#FFFFFF` | `#002B2D` | Text on primary |
| primaryContainer / secondaryContainer | `#DDEBEC` | `#C1CFCF` | `#384545` | Selected chips, nav indicator, selected tiles |
| onPrimaryContainer / onSecondaryContainer | `#002B2D` | `#002022` | `#AEEEF2` | Text on the above |
| error | `#B3261E` | `#9C2019` | `#F2B8B5` | Errors and Delete only |
| onError | `#FFFFFF` | `#FFFFFF` | `#601410` | |
| errorContainer | `#F9DEDC` | `#E9CBC8` | `#8C1D18` | Swipe-to-delete background |
| onErrorContainer | `#410E0B` | `#410E0B` | `#F9DEDC` | |
| inverseSurface | `#2E3236` | `#2E3236` | `#E8EAED` | Snackbars, tooltips |
| onInverseSurface | `#F1F3F5` | `#E8EAED` | `#1A1D21` | |
| inversePrimary | `#8CC5C7` | `#8CC5C7` | `#2F6F73` | Snackbar action |

In light themes, cards carry a 1dp `outlineVariant` hairline so white still
separates from the near-white page. In dark mode the tonal step is enough.

### Kind colours

Every kind has the same tone (light T45, night light T34, dark T75) and a
low chroma (22-26), so no kind is louder than another. Hues are spread
around the wheel and kept away from red and pink. The icon shape always
carries the meaning too, so colour is never the only cue.

| Kind | Light | Night light | Dark | Hue |
|---|---|---|---|---|
| feed | `#516D8A` | `#36526E` | `#9FBCDC` | calm blue |
| pump | `#4B7079` | `#30555E` | `#99BFC9` | cyan-blue, next to feed |
| sleep | `#6A678A` | `#4F4C6E` | `#B9B4DC` | slate violet |
| nappy | `#567157` | `#3C563D` | `#A3C0A2` | sage |
| pee | `#756B36` | `#5A501E` | `#C7B97D` | mustard |
| poo | `#826550` | `#654A38` | `#D5B29A` | brown |
| pill (habits) | `#856536` | `#684B1E` | `#DAB27C` | ochre |
| warn (status) | `#8C6309` | `#6B4A00` | `#E4B056` | amber |
| success (status) | `#517353` | `#37573A` | `#9EC29D` | green |

Each kind also has a near-neutral `container` (chroma 6) for the rare small
marker. It is never used as a card or section background.

`test/design_tokens_test.dart` enforces, for all three modes:

- WCAG AA (4.5:1) for onSurface, onSurfaceVariant, primary and error on
  surface, card, surfaceContainer and surfaceContainerHigh.
- WCAG AA for every kind colour on the same four surfaces.
- WCAG AA for every on-/container pair, and 3:1 for outline.
- All kinds share one tone and stay low-chroma.
- Nothing outside the error roles is red or pink.

### Using colour in code

```dart
final scheme = Theme.of(context).colorScheme;   // or context.colors
final feed = context.nest.feed;                  // KindColors
Icon(Icons.alarm, color: scheme.onSurfaceVariant);
Glyphs.feed(24, feed.color);
```

`Baby.*` is a compatibility facade from before Material 3. Every getter
returns one of the roles above (for example `Baby.muted` is
`onSurfaceVariant`). New code should use `ColorScheme` and `context.nest`.

## Typography

The face is the **platform system font**: Roboto on Android and Segoe UI on
Windows. Both are well hinted at small sizes, cover Afrikaans diacritics and
typographic punctuation (the bundled Figtree lacked the non-breaking
hyphen), feel native on each platform and add nothing to the download.

The scale is the Material 3 type scale with two adjustments: `titleLarge`
and `titleMedium` use Medium weight, for a firmer hierarchy without bold.

| Role | Size/line | Weight | Used for |
|---|---|---|---|
| displayLarge | 57/64 | 400 | Feed timer |
| displaySmall | 36/44 | 400 | "27m ago" on Today |
| headlineMedium | 28/36 | 400 | Setup questions |
| headlineSmall | 24/32 | 400 | Sheet and dialog titles |
| titleLarge | 22/28 | 500 | App bar titles |
| titleMedium | 16/24 | 500 | Section headers, button labels in tiles |
| titleSmall | 14/20 | 500 | Field group labels ("How long") |
| bodyLarge | 16/24 | 400 | List titles, body copy |
| bodyMedium | 14/20 | 400 | List subtitles, secondary copy |
| labelLarge | 14/20 | 500 | Buttons, chips, times in lists |
| labelMedium / Small | 12, 11 | 500 | Navigation labels, badges |

Numbers that update or line up (times, durations, counts) use tabular
figures. Never set `fontSize` or `fontWeight` by hand when a role fits;
`FontWeight.w800` is not part of the system.

## Spacing and layout

A 4dp grid with named steps in `Space`: xs 4, sm 8, md 12, lg 16, xl 24,
xxl 32. Phone pages have 16dp side margins; wide windows have 24dp.

- Phone (< 840dp): app bar, content, NavigationBar.
- Wide (>= 840dp): a navigation rail (80dp) that becomes a 260dp navigation
  drawer from 1200dp, a 64dp top bar, content capped at 1240dp. Today uses
  two columns, History puts filters in a side panel, and sheets open as
  centred dialogs.
- Content is laid out edge-to-edge. Lists pad for the bottom system inset.

## Shape

`Corners`: xs 4 (snackbars, tooltips, menus), sm 8 (chips), md 12 (inputs,
list tiles, desktop controls), lg 16 (cards, quick-log buttons, option
tiles), xl 28 (bottom sheets, dialogs, search field). Buttons and
navigation indicators are fully rounded (stadium).

## Elevation and surfaces

Material 3 tonal elevation, no shadows on content. Depth comes from the
surface container ladder (lowest, low, container, high, highest). Only
FABs and dialogs keep a small elevation (3). `Baby.shadow` is empty and
`BoxShadow` should not be used.

## Iconography

Material Symbols, Rounded, filled for kind glyphs (`Glyphs.*` in
`common.dart`) and Material Icons Rounded for UI controls. The one
exception is the painted poo glyph, which has no Material equivalent.
Sizes are 24dp in lists and controls, 20dp in dense rows and 28-40dp only
in large choice tiles. Icons sit bare in rows; don't put a tinted circle
behind every icon.

## Components

| Need | Use |
|---|---|
| Group of rows | `ListCard` (card + 56dp inset dividers) of `ListTile` / `EntryTile` |
| Section heading | `SectionTitle` (titleMedium, 24dp above, 8dp below) |
| Quick log | `ActionTile`: neutral tonal button, kind-coloured icon, label and live hint, at least 72dp |
| Log or edit an entry | Modal bottom sheet via `showSheet` (dialog on desktop) with `SheetHeader`, content and `SheetActions` (full-width Save, 56dp; 48dp in desktop dialogs) |
| 2-4 exclusive choices | `OptionTile` row or `SegmentedButton` |
| Single-select filter | `ChoiceChip` in one horizontally scrolling row |
| On/off | `SwitchListTile` |
| Confirm an action | `AlertDialog`: TextButton cancel first, FilledButton confirm last |
| Confirm a destructive action | The same, with `dangerButtonStyle` on the confirm (error colour) |
| Delete inside a sheet or editor | `DeleteTextButton` (error text button with a bin), at the start of `SheetActions` |
| Two equal actions in a card | `ButtonPair` (equal widths; stacks full width at large text) |
| Feedback after save | Floating snackbar with Undo |
| Empty, no results, error | `EmptyState` (bare icon, title, one line, optional action) |
| Main add action on a tab | Extended FAB on phones; top bar button on desktop |

## Buttons

All button heights come from `Controls` in `theme.dart`, set in the
component themes rather than per screen:

- Filled, Tonal, Outlined, Text and Segmented buttons are **48dp** on phones
  and **40dp** on desktop. Text buttons share that height, so Cancel lines up
  with Save in dialogs. Button styles use standard density, so the compact
  desktop density does not shave them to 32dp.
- The action row of a sheet (`SheetActions`) is the one exception: **56dp**
  on phones, 48dp in desktop dialogs. The primary is always full width; a
  secondary action (Start timer) gets an equal half, and Delete sits at the
  start as a text button. Setup's Continue and the pump's Start/Pause use
  the same row.
- Labels are `labelLarge` (14/20 Medium) on every button, chip and segment;
  icons in buttons are 18dp.
- Importance maps to one style: the main action is Filled, an alternative of
  similar weight is Outlined, low-emphasis or inline actions are Text.
  Tonal is for a secondary in-step action that sits above a separate Filled
  primary (camera wizard).
- Disabled buttons keep 55% content and a 10% fill (instead of 38%/12%), so
  a disabled Save is still readable on a white sheet.
- Destructive confirmations use the error colour, never the accent.
- Extended FABs are phone only; desktop puts the same action in the top bar.
  Lists under a FAB pad 96dp at the bottom.

## Palette candidates

`NestPalette` can be built in several variants (`NestVariant`). **Sky ships** (chosen by the owner on
5 November 2026); `current` (Slate), Tide and Marigold remain as alternatives, each described by a
`_Spec` (HCT hues and chromas, plus where it allows a little colour: tinted
quick-log tiles, a tinted Today summary, or sunny filled buttons). Every
candidate passes `test/design_tokens_test.dart`. `NestPalette.shipped`
chooses the palette; `NestPalette.debugVariant` overrides it in previews.

**Blush** is the one palette people can pick themselves (Settings → Theme →
Colours, stored per device as `palette`). It brings back the earlier rose
theme, close to the Momcozy pump app, rebuilt on the same tones, so it passes
every contrast check. It is the only exception to "no red or pink outside
errors", because people choose it. `NestPalette.choices` lists the palettes
offered. When the palette, light/dark or night light changes, the app
cross-fades from a snapshot of the old colours (`_snapshotBefore` in
`main.dart`). The cross-fade is skipped when the phone asks for reduced motion.
To compare them:

```
flutter test --run-skipped --tags preview test/ui_preview_test.dart --plain-name palette
python tool/palette_compare.py
```

## Motion

`Motion.short` 150ms for state changes, `Motion.medium` 250ms for content
swaps (`AnimatedSwitcher` on live numbers), `Motion.long` 400ms for page-level
transitions. Easing is `easeOutCubic` on enter and emphasized on moves. When
the system asks for reduced motion (`MediaQuery.disableAnimations`),
press-scale, looping guides and setup page slides are switched off.
Predictive back works because pages use standard routes and sheets use
`PopScope` only when there are unsaved edits.

Shared movements live in `lib/src/ui/motion_kit.dart`, so every screen
moves the same way. Use them rather than writing one-off animations:

- **Pages** (`NestPageTransitionsBuilder`, set in the theme): the new page
  fades in and glides a short way from the side, while the old page drifts
  back and dims.
- **Tabs** (`FadeIndexedStack`): the new tab fades and rises into place.
  Hidden tabs keep their state, pause their tickers, and do not rebuild
  until they are shown again (`ActiveGate`).
- **Entrances** (`Reveal`): fade and rise on first build. Use
  `Reveal.stagger(i)` for a list. Key list rows by id, so only new rows
  animate.
- **Show and hide** (`Collapse`): the space grows or shrinks while the
  content fades, so nothing below jumps. The timer card, the first-log
  guide, the routine preview and the baby picker use it.
- **Counters** (`RollingText`): changed digits roll into place. It is used
  for the feed timer, where only the digits rebuild each second.
- **Sheets:** the content resizes smoothly (`AnimatedSize`) when options
  reveal more fields.

All of these use only transforms and `FadeTransition` (never `Opacity` per
frame), and all are skipped under reduced motion.

## States

- **Interaction:** Material state layers (8% hover, 10% press, focus ring in
  primary). There are no custom splash colours.
- **Selected:** secondaryContainer fill plus `onSecondaryContainer` content,
  and a 2dp primary outline on option tiles.
- **Disabled:** Material defaults (38% content). Save stays disabled until an
  edit changes something.
- **Loading:** a small circular progress indicator in place of the control
  that started it, as in the toolbar refresh.
- **Empty and errors:** `EmptyState`, which says what happened and offers one
  way forward. Errors use `error` text, never a red card.

## Accessibility

- Contrast is enforced by test (see Colour).
- Touch targets are at least 48dp, with padded tap targets on phones.
- Text scales to 200%: rows use `Expanded`, `Flexible` or `Wrap` instead of
  fixed widths, and button pairs stack vertically when their labels would
  squeeze.
- Headings are marked with `Semantics(header: true)`, selection state is
  exposed on option tiles and choice cards, and icon buttons always have
  tooltips. Every string goes through `tr`/`LText`, so it is translated into
  Afrikaans.
