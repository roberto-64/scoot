# DESIGN.md — Scooter Log

**Read this whole file before touching any UI.** Every screen is built from these rules and nothing else.
If a screen needs something that isn't defined here, add it here first, then use it.
Never hard-code a colour, size, radius, shadow or gradient in a view. Use the tokens below.

## Direction

Warm Paper. Soft, warm, bookish: cream pages, brown ink, one amber accent.
Light only. Dark mode is parked, not forgotten: do not add dark values yet.

## Font

- **Serif: New York** (system serif). SwiftUI: `.system(size:, weight: .bold, design: .serif)`. Used for headlines, big numbers, row titles.
- **Sans: SF Pro** (system). Used for labels, body, buttons, captions.
- No bundled fonts. (Source Serif and Inter from the first build are removed.)
- Figures: serif bold, lining and tabular (`.monospacedDigit()`).
- Labels above values ("eyebrows"): sans 13, +0.04 em tracking, `muted`, **sentence case, never uppercase**.
- Type sizes: 11, 13, 15, 17, 22, 28, 32, 40, 56. Nothing else.

## Palette: five tokens

| Token | Hex | Use |
|---|---|---|
| `bg` | `#F8F1E4` | Screen background |
| `surface` | `#FFFDF8` | Cards, chips, tab pills, inputs, text on accent |
| `ink` | `#4A2F20` | Primary text, selected states |
| `muted` | `#7A634F` | Secondary text, labels, inactive icons |
| `accent` | `#B85C10` (default) | Buttons, active tab, key figures, status text, glow |

Derived values (not extra tokens):
- `line` = `ink` at 14% opacity. Hairlines, card borders, dividers.
- `glow` = `accent` at 24% opacity.
- Text on `accent` is always `surface`.
- Chart series: `accent` at 100%, 55% and 28%. Use these, in this order, for stacked bars and split bars. No other chart colours exist.

### Accent is the one user-changeable token

Settings → "Colore principale" offers exactly these six presets. `bg`, `surface`, `ink`, `muted` never change.
Stored as a preset id in `@AppStorage("accent")`, default `amber`. Views read it from the environment, never from a hex.

| Id | Name | Hex | Button text contrast | Accent-as-text contrast |
|---|---|---|---|---|
| `amber` | Ambra | `#B85C10` | 4.5 | 4.1 |
| `terracotta` | Terracotta | `#C8452C` | 4.8 | 4.3 |
| `forest` | Bosco | `#2F7A55` | 5.1 | 4.6 |
| `sea` | Mare | `#2F6DB5` | 5.2 | 4.7 |
| `plum` | Prugna | `#8E3F7B` | 6.6 | 5.9 |
| `graphite` | Grafite | `#4F5560` | 7.4 | 6.7 |

Rules: any new preset must reach 4.5:1 for `surface` text on it. Accent as text only at 17 pt semibold or larger, or as icons and graphics.

## Spacing: 8px scale

`8, 16, 24, 32, 40, 48, 56, 64`. Every padding, gap, margin and frame size is one of these.
Screen edge padding 16. Gap between sections 24 to 32. Tap targets 40 minimum, 48 preferred.
Hairlines are 1 pt. No 4, 12, 20 or other off-scale values.

## Radius: one

**24.** Cards, buttons, chips, inputs, icon squares, swatches, toggles, tab pills, sheets.
SwiftUI clamps to half the shorter side, so 48-high items read as full pills. Do not invent other radii.

**One exception: month bars (Home and Stats) use 4.** They are columns, not pills, so every bar keeps the same small radius whatever its height. Legend swatches use 3.

## Effects: no gradients or shadows unless listed here

Only these five exist. Everything else is flat.

1. **Header glow.** One radial gradient, `glow` fading to transparent, from the top-left, at most 300 pt tall, behind the top of root tab screens (Home, Garage, Fuel, Profile). Not on sheets or forms. The one other place is the shareable recap image (a picture, not a screen).
2. **Frosted tab pill.** The tab capsule: `surface` at 55% over a background blur, 1 pt border of `surface` at 70%.
3. **Card shadow.** y 8, blur 24, `ink` at 12%. Allowed on cards, chips, icon squares and the primary button. Nowhere else.
4. **Bar shadow.** A stronger two-layer shadow for the floating menu bar only (tab capsule and + button): y 14, blur 36, `ink` at 30%, plus y 3, blur 8, `ink` at 18%.
5. **Toggle knob shadow.** A soft shadow under the toggle knob only: y 2, blur 6, `ink` at 25%.

One more fade, not a gradient fill: a month bar whose yearly part (insurance, road tax, inspection) would pass the chart height is cut at the chart top and the yearly part fades to transparent there. No edge, no caption.

## Layout rules

- **Home:** date, greeting (serif 32), status line in `accent`, monthly spend (serif 56) with six month bars (press and hold a bar, then drag sideways: the number and title follow the held month, the held bar turns `ink`; lifting the finger returns to the current month), vehicle card (tap opens the vehicle page), recent activity.
- **New-entry sheet:** 32 pt of space above the title and 32 pt between the title row and the tiles, so the title clears the sheet's drag handle and rounded corners.
- **Entries (all four types):** tap an entry in any list to open the same form, pre-filled; the form opens as a sheet with a close cross, "Salva modifiche" at the bottom and an "Elimina registrazione" button (ink text, trash icon) that asks for confirmation. Press-and-hold shows "Elimina", also with confirmation. Swipe left on a row to show a full-height `accent` block with a `surface` trash icon; tapping it asks for confirmation, then deletes. The swipe behaves like WhatsApp's: the row follows the finger, the page cannot scroll while a row is dragged sideways, a flick opens or closes it, pulling past the end stretches with resistance, it settles with a bounce, the trash icon pops in and a haptic tick marks the point where it will stay open. Only one row is open at a time; scrolling the page or tapping elsewhere slides an open row back.
- **Going back:** on any screen opened from another, swipe from left to right anywhere to go back (the built-in edge swipe also works). Charts you drag across to read values, and a row that is swiped open, are excluded.
- **Monthly recap:** a bottom sheet at the large detent (same drag handle, `Radius.base` corners and `bg` background as the new-entry sheet), opened by itself once on the first launch of a new month, for the month that just ended, and from Settings > Riepiloghi mensili for any past month. It scrolls; "Condividi" (primary button) and "Chiudi" stay pinned at the bottom under a soft fade. Content: month and year (eyebrow), "Il tuo [mese] con [veicolo]" (serif 40), km (serif 72), km per week (bars with the km inside each bar in `surface`, best week in full `accent`, the others at 78%), a two-by-two grid (Speso, Carburante in L, Consumo medio, Rifornimenti), "Rispetto a [mese]" as capsule pills (km, euros, km/L; signs only, no good/bad colours) with the percentages under them, the cost split, and a consumption chart when the month has at least two points. Behind everything the app's scooter is drawn about 470 pt wide at 4% `ink`, fixed while the content scrolls. The shared image has the same ingredients in a 360 pt wide vertical card (saved at 3x).
- **Vehicle:** back, make and model, quoted nickname (serif 32), year and fuel, odometer, cost per month, average consumption, deadline chips, history grouped by month.
- **Forms (fill-up, maintenance, vehicle):** back button and title, underlined fields with serif numbers, calculated cost, one `accent` button pinned at the bottom. No tab bar on forms.
- **Fill-up form:** quantity, price per litre, calculated cost, odometer, date. No full/partial switch. One optional toggle, "Spia della riserva accesa", sits under the odometer (same toggle as Settings, label with a small muted line). One entry per stop, with the total litres. Consumption is then measured from one marked fill-up to the next marked one: litres = the first marked fill-up plus those in between, not the closing one; until a stretch exists the 400 km window is used. Stats and Fuel say which method is shown.
- **Missing-data alarm:** same centred card over a dimmed screen as the tank pop-up. Accent icon square (exclamation), serif 22 title "I tuoi dati sembrano spariti", muted 15 text, a row with the newest automatic backup (date · entries), full-width "Ripristina questo backup", then text buttons "Scegli un altro file" (accent, semibold) and "Non ora" (muted). No red.
- **Segmented controls:** the selected pill (surface fill, 1 pt line) slides between options with the tab bar's spring (`matchedGeometryEffect`); it does not fade.
- **Fill-up odometer field:** empty on open, last reading shown faded as the hint; tapping completes the leading digits shared with the guessed next reading (`OdometerGuess`). Warning text waits for a full-length number.
- **Automatic backup rows (Settings > Backup dei dati):** toggle "Backup automatico" with a 13 pt muted line, and when on a "Cartella" row ("Sul mio iPhone › Scoot › Backup automatici", plus "Ultimo:" date) with an accent chevron that opens Files there. Below: "Promemoria per esportare" (17 pt) with a three-way segmented control Mai / 7 giorni / 30 giorni and an eyebrow explanation.
- **Last two tanks pop-up:** a centred card over a dimmed screen (not a sheet), shown once on the first open after a fill-up. `surface`, 24 pt radius, 1 pt `line`, close square top right. Eyebrow "Ultimi due pieni", km/L in serif 56, "± n, stima" in eyebrow, then three rows (last fill-up, previous, total) with km and litres, and a full-width "Ok" button. No explanatory note.
- **Consumption figures** are estimates: distance from first to last reading over litres added after the first, shown with a margin ("41,8 km/L ± 4%, stima"). Charts use a rolling average over at least 400 km. Never show per-fill km/L as a headline.
- **Garage:** title and add button, one card per vehicle with odometer and three deadline cells (RCA, Bollo, Revisione), then "In arrivo". The whole upper part of the vehicle card opens the vehicle page; the deadline cells have their own taps.
- **"In arrivo" (Garage):** only items due within 30 days from today, plus anything already overdue. A job that depends only on distance appears once it is estimated to fall inside the window (this needs about two weeks of odometer entries) or when its distance has passed. Maintenance whose interval comes from the official Piaggio schedule carries a small **PIAGGIO** tag next to its name. When nothing is due the section says so in one line.
- **Maintenance:** a picker sheet with search, recents, expandable categories and multi-select, then an entry form with one card per job. Each job card has price, quantity and its own next-service rule (km, months, both or never). Defaults carry a source tag ("Piaggio" for official values, none for typical ones). Car-only jobs are hidden unless the switch is on.
- **Deadline setup:** a sheet per deadline with a calculated, editable due date and an alerts row. Renewing moves the old date into a renewal history and calculates the next one.
- **Settings** (Profile, top-right gear): colour, language (Italiano / English), alerts, Face ID, export.
- **Tab bar:** four icon tabs in one frosted capsule, selected tab filled with `accent`, plus a separate **+** button, filled with `accent` with a `surface` plus, that opens the new-entry sheet. Labels are not shown. Each tab's tap area is its whole quarter of the bar and the full 56 pt height, not just the icon. The Garage header has its own accent-filled **+** (add vehicle); the two are never the same style.
- **Bottom buffer:** every screen that scrolls under the floating bar (the four tabs and every screen opened from them) ends with 72 pt of empty space so the last item stops above the bar.
- **Cards:** `surface`, 1 pt `line` border, card shadow. **Buttons:** 48 to 56 high, `accent`, label in `surface`, semibold 17.

## Month bars and legend

- Bars follow everyday spending; the yearly part is stacked above in `accent` at 55% (full `accent` while that month is held on Home). Everyday part: `ink` for the shown month, `line` for the others on Home; `accent` on Stats.
- Home chart is 88 pt high with 8 pt above it; Stats 96 pt. No caption under the chart.
- Holding a month on Home shows a legend under the bars: 10 pt square (3 pt corners, `ink` for everyday, `accent` for yearly), category in 13 pt `muted`, amount in 13 pt semibold `ink`, flowing over at most two lines. Anything that does not fit is added up under "Altre voci", so the legend always equals the number shown. The 40 pt it needs (plus 16 pt above) is always reserved.

## Home card, km chart, yearly summary (build 8)

- The vehicle card sits 24 pt under the month bars. Holding a month slides it down with `Motion.spring` by the legend's height (one row 34 pt, two rows 56 pt); the legend fades in at the same time. Nothing else on the page moves.
- Km chart (Stats): same bars as the spending chart (4 pt radius, 96 pt cap), `accent`, readout line above ("5–11 ott · 262 km"), the others dim to 35% while one is held. Average and best use the usual two-column grid. Weekly labels are the Monday's day number only.
- Yearly summary: big serif km total, six-cell grid, month-by-month bars (yearly part lighter), one-line note. Subtitle "2026 · dal 2 novembre" only.

## Search, photos, PDF (build 8)

- Search field in Storico: 48 pt high, `surface`, 24 pt radius, 1 pt `line`, card shadow, magnifier left, clear button right. Chips below: 40 pt high, 24 pt radius, selected = `accent` fill with `surface` text. Matches are marked with `accent` at 22% behind the text. Result count and total in eyebrow style.
- Photo tiles in forms: 88 x 112 pt with a **12 pt radius** (exception to the single 24 pt radius, same reason as the month bars: small shapes), 1 pt `line`, card shadow. "Aggiungi" tile: dashed `accent` outline at 55%. Full-screen viewer: dark brown background (#1D130D) with cream controls; the only dark surface in the app.
- Sales PDF: A4, white paper, `ink` and `muted` text, hairline rules, no accent colour, no nickname, no photos.

## Status and destructive states

There is no red and no other status colour. State is shown by shape and word as well as fill:

| State | Look | Label |
|---|---|---|
| Not set | dashed `muted` outline | `+ Imposta` |
| OK (more than 30 days) | `accent` outline, check icon | `OK` |
| Soon (30 days or fewer) | `accent` fill, `surface` text | `12 gg` |
| Overdue | `ink` fill, `surface` text | `Scaduta` |

- Destructive actions (remove, delete): `ink` text with a trash icon, always behind a confirmation. The swipe-to-delete block is the one place `accent` marks a delete; it still asks for confirmation. A 16 pt gap of bare background separates the sliding row from the block.
  The divider lines on both sides of an open row stop at the same gap (the line under it is shortened while it is open).
- **Home status line:** "Il tuo garage è in regola" when nothing is overdue or due within 30 days. Otherwise it counts overdue and coming-up items separately ("2 scadute · 1 in arrivo"); anything overdue uses `ink` text and a filled exclamation icon, coming-up only uses `accent`.
- **New-entry sheet** (the + button) is only as tall as its content, and grows to full height when a form is opened inside it.
- Deadline alerts go out at 9:00. Revisione: 60, 30, 7 and 1 days before, so there is time to book. RCA and Bollo: 30, 7 and 1 days before.
- Lists of upcoming items (Garage, "In arrivo") are always sorted by due date, deadlines and service items together.

## Icons

- Interface icons are SF Symbols, template-rendered in `ink`, `muted` or `accent`. Nothing else.
- The Garage tab uses a front-view car icon (matching the one in OdoKeep: mirrors, two headlight dots, wheel stubs) at the same 1.8 pt line weight as the other tab icons, in all states. It is shipped as a vector template asset (`car-front.pdf`, source `car-front.svg`), because the SF Symbol `car` is a side view and does not match. Source shape: the open-source Lucide `car-front` icon (ISC licence).
- The custom scooter (`scooter.svg`, a solid silhouette traced from the approved icon, shipped as a vector template asset) appears only on vehicle cards and the first-launch card. It is not used in the tab bar: simplified and outline versions were tried and rejected.
- Custom icons take `accent` or `ink` like any icon and are never given a colour of their own. The SF Symbol `scooter` is never used.

## Empty states

Every empty screen says what is missing in one sentence, why it matters, and offers one primary action. Never show a blank chart or a bare zero without a hint.
- **First launch:** greeting without a name, one card "Aggiungi il tuo primo veicolo" with a single accent button, and a quiet "Ho già un backup: importa" link.
- **Vehicle, no entries:** a "Per iniziare" checklist of three steps (add vehicle, first fill-up, set deadlines). Steps are tappable, done steps are struck through, and the card disappears when all are done. Monthly spend shows muted `0,00 €` with a hint.
- **Not enough data for a chart:** a dashed `line` outline card with a faint dashed line, a title saying what unlocks it, and how many entries are missing. Figures that cannot be computed show a muted `—`.

## Motion and haptics

Playful, springs only. Everyday spring: response 0.32, damping 0.68. Pop spring (new entries, save, toggle knob): response 0.4, damping 0.52. Swipe settle spring: response 0.36, damping 0.6. Press-down spring: response 0.26, damping 0.55.
- Taps: buttons and cards squash to 94% and bounce back; list rows to 98%.
- Toggles: the knob stretches while pressed and bounces into place.
- Lists: a new entry pops in (scale from 92%), a deleted one slides out to the left.
- Tabs: the highlight pill bounces to the new tab. The screen content change (changed in build 10 at the user's request) is (build 13) a "cascade from below": the new screen appears at once (0.16 s) and its blocks, top first, rise 54 pt with a springy bounce (response 0.5, damping 0.5, 0.055 s apart). Screens keep their normal look; only the entrance moves. All four screens stay alive in the background, so each tab remembers its scroll position and any page that was open.
- Save: the Save button gives a small pop (105%) just before the screen closes.
- Numbers roll when they change. Sheets slide natively.
One haptic per action: selection tick on tabs, success on save, warning on invalid odometer.
Respect Reduce Motion and the Settings switch for animations and haptics.

## Language

Italian is the default, English is switchable. Every user-facing string lives in the string catalogue in both languages. No hard-coded text in views.

## Before shipping any screen

- [ ] Only the five tokens (plus derived `line` and `glow`) appear.
- [ ] Every spacing value is on the 8px scale.
- [ ] Every corner is radius 24.
- [ ] No gradient or shadow outside the five listed above.
- [ ] Fonts are New York and SF Pro only.
- [ ] Changing the accent in Settings recolours every accent element on this screen.
- [ ] Both languages tested.
