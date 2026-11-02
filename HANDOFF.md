# HANDOFF.md — Scoot

Read this file first, then read `DESIGN.md` in full before touching any UI.
Snapshot taken at the end of the first account's session. **Nothing has ever been compiled or run.**

---

## 1. Project goal

A private iOS app (display name "Scoot") to manage vehicles. It is for one person in Italy, for personal use, installed by sideloading. It is not for the App Store.

What it does:
- **Fuel:** log fill-ups (litres, price per litre, odometer, date) and estimate consumption in km/L.
- **Maintenance:** log jobs (date, price, what was done, workshop). Each job carries its own "next service" rule (km, months, both, or never), as in the app OdoKeep.
- **Italian deadlines:** RCA insurance, Bollo, Revisione, with alerts.
- **Statistics:** totals, cost per month, cost per km, charts, split by category, yearly estimate.
- **Profile:** activity summary, vehicles, backup/export.
- Supports several vehicles. The user's own vehicle is a Piaggio Liberty 125 (nickname "Filippo", first registered January 2023, about 33,600 km, petrol 95, air-cooled, probably rear drum brake).

Defaults: km, litres, euros. **UI language Italian by default, English switchable** in Settings. No accounts, no plate number, no VIN, no email. All data stays on the phone.

The user took design inspiration from the app **OdoKeep** (layout, record types, statistics) and from **Daylio** (serif + sans pairing), and from **LastHop** (warm paper look and system fonts).

---

## 2. Key decisions and why

### Platform and delivery
- **Native SwiftUI + SwiftData, iOS 17+, fully local.** No backend, no accounts, no analytics.
  *Rejected:* a backend, accounts, iCloud/CloudKit sync (free-account sideloading cannot use iCloud, and the user wants privacy).
- **The user has no Mac.** Builds run on a GitHub Actions macOS runner. XcodeGen generates the Xcode project from `project.yml`, and the workflow produces an **unsigned .ipa**.
- **Install with Signulous** (paid signing service the user already uses; app does not expire every 7 days).
  *Rejected:* Sideloadly and AltStore (not needed).
  *Risk:* certificates can be revoked, and the app may need reinstalling, so data can be lost. Hence the in-app backup (JSON/CSV export, import, 30-day reminder).
- The GitHub repo is meant to be **public** (free macOS build minutes). It must contain no personal data or secrets.
- Claude cannot compile Swift in its sandbox. Every build is therefore checked by the GitHub Actions run, and the user pastes back error lines from the `build-log` artifact.

### Design (locked in `DESIGN.md`)
- **Direction chosen: "Warm Paper".** Cream background, brown ink, one amber accent. Light only; **dark mode is parked** (do not add it).
  *Rejected directions:* "Midnight Editorial" (dark serif) and "Instrument Panel" (dark, mono).
- **Fonts: Apple system fonts only** (New York serif for headlines and figures, SF Pro for everything else). *Rejected:* bundled fonts (build 1 used Source Serif 4 and Inter, now removed), monospace fonts.
- Five colour tokens, an 8px spacing scale, one corner radius (24), and "no gradients or shadows unless listed". Exactly three effects are allowed: header glow, frosted tab pills, one soft card shadow.
- The accent is the only user-changeable colour (six presets in Settings). Presets were checked for contrast.
- **No red or other status colours.** Overdue is shown with a dark ink-filled chip and the word "Scaduta". Destructive actions use ink text with a trash icon and a confirmation.
- **Icons:** the Garage tab uses a **front-view car** icon copied from OdoKeep (Lucide `car-front`, shipped as a vector asset). The user's own **solid scooter silhouette** (traced from an icon they supplied) appears only on vehicle cards and the first-launch card. *Rejected:* outline and simplified scooter versions in the tab bar ("looks bad"), the SF Symbol `scooter`. The add button is a **+** (it was a pencil; the user changed it).
- **Chart colours** are tints of the accent only (100%, 55%, 28%).

### Product and statistics
- **Fill-up form has no full/partial switch and no optional extra taps.** The user never fills to the brim (the tank does not read full consistently). One entry per stop, with the total litres. An optional "spia accesa" tap was offered and **rejected**.
- **Consumption is an estimate:** distance from first to last reading divided by litres added after the first. Charts use a rolling window of at least 400 km. Figures are shown with a margin, for example "41,8 km/L ± 4%, stima". The margin is a tank-level uncertainty setting, default 0.5 L. Never show per-fill km/L as a headline figure.
- **Cost per month** counts calendar months from the first entry, both ends included (March to October = 8), like OdoKeep.
- **Spending split is by cost, not by number of records.** A toggle can spread yearly costs (insurance, bollo) across the months they cover; it is off by default.
- **Annual estimate** = latest yearly costs + average monthly variable spending × 12; shown only after 3 months of data.
- **Maintenance:** a catalogue of about 75 jobs in 16 categories, adapted to a scooter (CVT belt, rollers and so on). Car-only jobs and parts that do not apply (coolant on an air-cooled bike, rear shoes versus discs) are hidden unless a switch is on. The picker supports search, recents, multi-select and custom jobs.
- **Default next-service rules** come from Piaggio's own interval sheets for the Liberty 125–150 iGet. They are shown with a "Piaggio" tag; unverified ones carry "Da verificare" or no tag (see section 7).
- **Deadlines (Italy):**
  - Revisione: first due 4 years after first registration, then every 2 years, at the end of the month. For a January 2023 registration the first is due **31 January 2027**.
  - Bollo: due by the end of the month after the expiry month (a January registration gives **28 February 2027**).
  - RCA: yearly, with a 15-day grace period that applies only to annual policies and is shown as information only.
  - Alerts at 9:00: Revisione at 60, 30, 7 and 1 days before; RCA, Bollo and service items at 30, 7 and 1.
- **Privacy:** no plate, VIN, account or email anywhere. The vehicle sheet states this.
- **Skipped on purpose:** sharing a car with other users, multi-currency, a backend, receipt photos, widgets and Siri, the fuel-price map, a PDF service history for buyers. The last three are possible later; the price map would need internet.

---

## 3. Tech stack and architecture

- Swift 5 mode, SwiftUI, **SwiftData**, **Swift Charts**, UserNotifications, LocalAuthentication.
- **XcodeGen** (`project.yml`), **GitHub Actions** (`macos-15`, `xcodebuild`, unsigned .ipa).
- Deployment target **iOS 17.0**, bundle id `com.personal.scooterlog`, iPhone only, portrait, light.
- No third-party packages. No bundled fonts.

### Folder structure (source of truth is the tree in section 11)

```
ScooterLog/
  App/            (EMPTY: ScooterLogApp.swift still to be written)
  Design/         Theme.swift          tokens, fonts, effects, reusable components
  Models/         Models.swift         SwiftData models
                  Catalog.swift        maintenance jobs and categories, default rules
  Services/       Format.swift         number/date formatting helpers
                  Loc.swift            string lookup outside SwiftUI Text
                  Stats.swift          totals, months, split, consumption, annual estimate
                  Upcoming.swift       upcoming deadlines and service items
                  Notifier.swift       local notification scheduling
                  Backup.swift         JSON/CSV export, import, ShareSheet
  Views/          RootView, HomeView, GarageView, VehicleDetailView, VehicleFormView,
                  EntryForms (fuel, expense, odometer), MaintenanceViews, FuelView,
                  StatsView, Charts, Shared
  Resources/      Assets.xcassets (AppIcon, AccentColor, Scooter, CarFront)
```

### How the pieces connect
- **Data:** models are `Vehicle` (owns everything), `FuelEntry`, `MaintenanceEntry` with `MaintenanceJob`, `ExpenseEntry` (also used for paid RCA/bollo/revisione costs), `OdometerReading`, `Deadline`. Next-service countdowns are **derived** from the latest job per job key; there is no separate rule model.
- **Navigation:** `RootView` switches four tabs (Home, Garage, Fuel, Profile) and shows the floating bar. The **+** button opens `NewEntrySheet`, whose tiles push the entry forms.
- **Refresh signal:** after any save or delete, code calls `DataSignal.fire()`. `RootView` listens and reschedules notifications.
- **Accent:** read from `@AppStorage("accent")` in the app entry, injected as the environment value `appAccent`. Views never hard-code the accent.
- **Language:** `@AppStorage("language")` ("it" or "en") sets the environment `locale`. **Italian text is the localisation key**: views write `Text("Attività recente")`, and the string catalogue (`Localizable.xcstrings`, still to be generated) holds the **English** translations. `Loc.tr(key, lang)` does lookups outside `Text`.
- **AppStorage keys in use:** `language`, `accent`, `userName`, `selectedVehicle`, `hideChecklist`, `statRange`, `statVehicle`, `spreadAnnual`, `tankMargin`, `alerts`, `animations`, `haptics`, `lastBackup`, `faceID`.
- **Assets:** `Scooter` and `CarFront` are PDF vector template images. Source vectors are in `design-assets/`.

---

## 4. design.md (actually named `DESIGN.md`)

**`DESIGN.md` at the project root is the single source of truth for every design element.** The user calls it "design.md"; the file name is uppercase, so keep that exact name.

It covers: direction (Warm Paper, light only), fonts (New York + SF Pro, allowed sizes 11, 13, 15, 17, 22, 28, 32, 40, 56), the five colour tokens (`bg` #F8F1E4, `surface` #FFFDF8, `ink` #4A2F20, `muted` #7A634F, `accent` #B85C10 default) with derived values (line, glow, chart tints), the six accent presets with contrast ratios, the 8px spacing scale, the single radius 24, the three allowed effects, deadline status chips, layout rules for every screen, icon rules, empty-state rules, motion and haptics, language, and a pre-ship checklist.

**It must be followed exactly. Do not change it, and do not deviate from it in code, without the user's explicit approval.** If a screen needs something it does not define, propose the addition to the user first.

`docs/design-preview.html` is the last interactive mockup of all screens (open it in a browser). It is a reference, `DESIGN.md` wins on any conflict.

---

## 5. Status, file by file

**Never compiled, never run, never tested on a device.** Every Swift file below is "written, brace-balanced", not "known to build". Expect compile errors on the first CI run.

### Done (written)
| File | Notes |
|---|---|
| `project.yml` | XcodeGen config, Face ID usage text, light mode, asset names |
| `.github/workflows/build.yml` | builds an unsigned .ipa, uploads `ScooterLog-ipa` and `build-log` artifacts |
| `DESIGN.md` | final, approved |
| `Design/Theme.swift` | tokens, accent presets and environment key, fonts, motion/haptics, effects, buttons, fields, segmented control, toggle, status chip |
| `Models/Models.swift`, `Models/Catalog.swift` | models and the maintenance catalogue |
| `Services/Format, Loc, Stats, Upcoming, Notifier, Backup.swift` | logic layer |
| `Views/RootView, HomeView, GarageView, VehicleDetailView, VehicleFormView` | |
| `Views/EntryForms, MaintenanceViews, FuelView, StatsView, Charts, Shared` | `MaintenanceViews.swift` was the last file written, and it is **complete** |
| `Resources/Assets.xcassets` | AppIcon (1024 px, scooter on cream), AccentColor, Scooter, CarFront |

**Syntax check (tree-sitter, `tools/syntax_check.py`) on all 20 Swift files: 0 syntax errors, all braces balanced.** This proves nothing about types or compilation. Secrets scan: clean.

### Missing (referenced by existing code, not yet written)
**The project cannot build until all of these exist.**
1. `App/ScooterLogApp.swift`: the `@main` entry. It must set the model container for all seven models, inject `locale` from `language` and `appAccent` from `accent`, force `.preferredColorScheme(.light)`, and show the Face ID lock overlay.
2. `Views/DeadlineSheet.swift`: `DeadlineSheet(vehicle:kind:)`, used by Home, Garage and the vehicle page. RCA, Bollo and Revisione setup, per the rules in section 2 and the mockup in `docs/design-preview.html` ("Scadenza" screen).
3. `Views/ProfileView.swift`: Profile (gear at top right opens Settings), activity stats with a year chip, split bar, vehicles list, backup card.
4. `Views/SettingsView.swift`: accent picker, language, alerts toggle, Face ID toggle, animations and haptics toggles, tank-margin setting, export (JSON and CSV through `ShareSheet`, which sets `lastBackup`), import, version.
5. A `backupImporter(isPresented:)` view modifier: file importer, confirmation, then `BackupService.restore`. Used by `HomeView`.
6. `LockView` (Face ID overlay using LocalAuthentication).
7. `Resources/Localizable.xcstrings`: English translations for **every** Italian string key in the code. Generate it by scanning the Swift files for `Text("...")`, `LocalizedStringKey`, `Button("...")`, `Label("...")`, `Picker`, `.alert` and `.confirmationDialog` strings, then adding English values. Keys with interpolation use the Swift format: `Ciao, %@`, `Spesa di %@`, `Ultimo: %@`, `%lld scadenze in arrivo`, `%lld di 3`, `Ultima lettura: %@ km`, `Aggiungi %lld interventi`, `Totale %@`, `≈ %@`, `%@ di costi annuali + %@ di spese variabili (media mensile × 12)`. Strings used via `Loc.tr` include `o`, `gg`, `Scaduta`, `Prossima:`, `, quale arriva prima`, `Scade oggi`, `Scade domani`, `Scade tra %ld giorni`, `Backup dei dati`, and the backup reminder text.
8. Model names to register in `.modelContainer(for:)`: `Vehicle, FuelEntry, MaintenanceEntry, MaintenanceJob, ExpenseEntry, OdometerReading, Deadline`.

### Not started
- Unit tests, a test target, CI screenshots.
- Editing an existing entry (only delete by long-press exists; the design says "tap a row to edit").
- Learned tank margin (only the manual setting exists).
- Comparison with the previous period on the stats screen (removed from scope).
- Widgets, Siri shortcuts, PDF service history, fuel-price map.

---

## 6. Next steps (exact order)

**Status, 2 Nov 2026: steps 1 to 3 are done.** The six missing files are written (`ScooterLogApp.swift`, `LockView`, `BackupImporter`, `DeadlineSheet`, `SettingsView`, `ProfileView`) and `Resources/Localizable.xcstrings` exists (244 English entries). A bracket-balance check passes on all 26 Swift files. `tools/syntax_check.py` could not be run (the sandbox could not reach the Python package site), so it is still to be run. **Nothing has been compiled.** Next: step 4.

**Round 2, 2 Nov 2026 (after the first successful GitHub build and install).** The first build compiled and installed. Changes made from the owner's testing notes (all approved by the owner; DESIGN.md updated to match): (1) iOS-style toggle with knob shadow (`SwitchControl` in `Theme.swift`); (2) tap any entry to edit it, with delete and confirmation, for fill-ups, maintenance, expenses and odometer readings (`EntryEditSheet`, `editing:` parameter on each form); (3) swipe left on a row for an accent trash block with confirmation (`SwipeToDelete` in `Shared.swift`); (4) Home vehicle card opens the vehicle page; (5) Garage vehicle card tappable anywhere, plus `contentShape` fixes on other full-width rows; (6) stronger menu-bar shadow (`BarShadow`); (7) Garage "In arrivo" limited to 30 days with a PIAGGIO tag (`Upcoming.dueSoon`, `UpcomingItem.isPiaggio`); (8) 32 pt space above the new-entry title; (9) bouncier motion (`Motion.spring/bounce/press`; `Motion.fade` keeps the original tab content fade); (10) swipe from left to right anywhere to go back (`SwipeBack.swift`, uses internal UIKit names looked up defensively, charts and open swipe rows excluded); (11) the + button in the bar is filled with the accent. The workflow now uses `macos-15-intel` because the arm64 macOS runners were unavailable. **None of this has been compiled or run yet.** Likely first places to look if the build fails: `SwipeBack.swift`, `SwipeToDelete`, `SwitchControl`, the `editing:` forms.

**Versioning:** from round 3 on, every upload bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` and adds an entry to `CHANGELOG.md` (version 1.1, build 2 is the first). 

**Round 3, 2 Nov 2026.** Round 2 built and ran correctly on the owner's phone. Changes (owner-approved): (12) swipe-to-delete rewritten to follow WhatsApp's swipe-to-archive: new `SwipeRow.swift` (`SwipeBridge` adds a pan recogniser to the page's UIScrollView, locks scrolling while a row is dragged sideways, closes an open row on scroll or on a tap elsewhere, one open row at a time) and a springier `SwipeToDelete` (flick, rubber band, `Motion.snap`, icon pop, haptic tick); (13) a 72 pt bottom buffer on the vehicle page, Stats and Settings; (14) tab bar touch targets enlarged to each tab's full quarter and 56 pt height. Not compiled or run yet. If the swipe does nothing, the likely cause is that the row's scroll view was not found in the view hierarchy (`SwipeBridgeView.attach`).
Small changes made outside those files: the backup-reminder text in `Notifier.swift` now uses a typographic apostrophe (matches the catalogue); `LineField` in `Theme.swift` now translates its placeholder and unit text. Decision: no insurer-name field on deadlines.

1. Write the missing files in this order: `ScooterLogApp.swift`, `LockView`, `backupImporter`, `DeadlineSheet`, `SettingsView`, `ProfileView`.
2. Generate `Localizable.xcstrings` by scanning the code, and list any Italian string without an English entry.
3. Run the syntax checker (`tools/syntax_check.py`) on every Swift file, and check that braces balance.
4. Zip the project, and have the user upload it to a public GitHub repo (Actions will build it). First delete or replace the files of any earlier repo.
5. The user downloads the `ScooterLog-ipa` artifact, uploads it to Signulous and installs it. If the build is red: the user sends the red error lines from the `build-log` artifact, and Claude fixes them. Repeat until it is green.
6. Test on the phone: notifications, Face ID, export/import, accent change, language switch, a real fill-up and a real maintenance entry.
7. Only then consider the deferred features.

---

## 7. Known bugs and open questions

### Known risks (unverified, because nothing has been compiled)
- Possible compile errors, most likely in: `FormScaffold` (`@ViewBuilder let content`), `Segmented<T>` generics, `.navigationDestination(item:)`, `.chartXSelection`, the `UINavigationController` extension in `Theme.swift`, long SwiftUI expressions, and a few SF Symbol names (a missing symbol shows blank, not a crash).
- `Notifier` plans notifications on the main thread, then hands plain values to the system. This was written carefully but is untested.
- String-catalogue keys with `%`: the stats margin text avoids a literal `%` in a localised key on purpose (it concatenates `Text(verbatim:)` with `Text("stima")`).
- Italian strings use a mix of straight (`d'avviamento`, `dall'ultimo`) and typographic (`all’ultima`) apostrophes. The catalogue keys must match the code **exactly**; normalise to typographic ones when generating the catalogue.
- Signulous re-signing: notifications and Face ID under third-party signing are untested.
- Build 1 (an earlier zip, `scooter-log-build1.zip`) was never built by the user and is **obsolete**; do not reuse it.

### Open questions for the user
- **Spark plug interval:** Piaggio's Italian sheet lists it at 10,000 / 20,000 / 30,000 km, the English one only at 20,000. The code uses 10,000 and tags it "Da verificare". Ask the user to check their libretto.
- Unverified defaults: valve clearance check (20,000 km), gear oil (30,000 km), fork oil (40,000 km / 60 months), 12V battery (48 months), tyre age alert (72 months).
- Tank capacity of the Liberty 125 was used as 6.0 L in a mockup only; confirm with the user. It is a user-entered field.
- Rear brake type on the user's 2023 scooter (drum assumed).
- Bollo rule for a January registration (applied from the general rule, not verified on ACI).
- The "Nuova registrazione" sheet (tiles for Rifornimento, Manutenzione, Spesa, Aggiorna contachilometri) was **never shown as a mockup**; it was built from the text of `DESIGN.md` and needs the user's visual approval.
- Display name decided on 2 Nov 2026: **Scoot**. Internal names (project, folders, bundle id, build artifact names) stay "ScooterLog"; DESIGN.md still carries the old title.

Sources for the Piaggio schedule (Liberty 125–150 iGet):
- Italian: https://www.piaggio.com/mediaObject/piaggio/IT/servizi/interventi-da-effettuare/IT-Piaggio-IM-Liberty/original/IT-Piaggio-IM-Liberty.pdf
- English: https://wlassets.piaggio.com/wlassets/piaggio/gb/maintenance_intervals/Gamma-Liberty-125-150/original/Gamma+Liberty+125-150.pdf

---

## 8. User preferences and working conventions

- **Plan first, then build.** The user wants to see designs (interactive previews or mockups) and approve them before code.
- **Design is locked.** Follow `DESIGN.md`; propose changes, never make them silently.
- **Short answers.** The user replies with brief confirmations ("looks good") and wants brief, scannable responses: a couple of paragraphs or short lists, no walls of text. Lead with the answer.
- **Ask at most one question at a time**, and only when a real decision is needed.
- **Verify facts; flag uncertainty.** The user asked for Italian rules and the Piaggio schedule to be looked up and sourced. Say plainly what is verified and what is a guess.
- **Italian-first product.** UI default is Italian, English switchable. Italian text is the localisation key.
- **Privacy:** no plate, VIN, email or account anywhere. Do not put personal data in code or files.
- **No red.** No gradients or shadows beyond the three allowed effects. No bundled fonts. No dark mode yet.
- **The user is on a phone most of the time and on a Windows PC only sometimes.** Give GitHub steps that work from a browser on Windows.
- **Code style:** small SwiftUI views; use tokens and `Space`/`Radius`/`AppFont`, never literals; sizes only from the allowed list; spacing only on the 8px scale; no force-unwraps where avoidable; prefer simple expressions over long ones (the compiler cannot be run here).
- **Do not start extra features.** Stay inside the agreed scope; list ideas as "later".

---

## 9. Setup and run instructions

### Normal path (no Mac): GitHub Actions
1. On a Windows PC, create a **public** GitHub repository.
2. Upload **all** files from the project folder, including the hidden-looking `.github/workflows/build.yml` and the `ScooterLog/` folder (drag the contents of the unzipped folder into the repo's "Add file → Upload files" page, then commit).
3. Open the repo's **Actions** tab. The **Build IPA** workflow starts by itself (about 5–10 minutes). It can also be started manually with "Run workflow".
4. On success, open the run, download the artifact **ScooterLog-ipa**, unzip it, and upload `ScooterLog.ipa` to **Signulous**; install on the iPhone.
5. On failure, download the artifact **build-log** (or copy the red error lines) and send it to Claude.

### With a Mac (optional)
```bash
brew install xcodegen
xcodegen generate
open ScooterLog.xcodeproj
# command line build for the simulator:
xcodebuild -project ScooterLog.xcodeproj -scheme ScooterLog \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Checks that work without a Mac
```bash
pip install tree-sitter tree-sitter-swift
python3 tools/syntax_check.py        # reports syntax errors in every .swift file
```
This checks syntax only, **not types**. Only the GitHub build proves the code compiles.

### Tests
There is no test target yet.

---

## 10. Environment variables

**None.** The app and the workflow use no API keys, tokens or secrets. (The workflow uses only GitHub's built-in permissions.) Do not add any.

---

## 11. Handoff files

See the end of the chat message for the exact tree and the download list. The single file `scooter-log-handoff.zip` contains everything.

- Build 4 first failed to compile: `SwipeRow.swift` needed `override` on `gestureRecognizerShouldBegin` (UIView already has that method). Fixed; confirm with the next GitHub build.
