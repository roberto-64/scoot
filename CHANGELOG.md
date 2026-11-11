# Changelog

Newest first. Dates are 2 and 3 November 2026.

## Build 25

Version 1.4 (25).
- Every segmented switch (Mai/7/30 giorni, Consumo/Prezzo, Mese/Settimana, ...) now has a pill that slides to the chosen option, like the tab bar's pill (`matchedGeometryEffect`), instead of fading in and out.
- Fill-up form, odometer field: it no longer starts with the old reading (which had to be erased). It starts empty with the last reading as a faded hint; tapping it fills in the leading digits the next reading will share (last reading + the median of the last 5 gaps between fill-ups, `OdometerGuess`). E.g. last 33,878, usual gap 120: tap gives "33", type "998". Near a rollover only the shared digits appear (33,950 -> "3"). Fewer than two fill-ups: nothing is filled in.
- "Salva" is off while a new fill-up's odometer is below the last reading and dated after it (a half-typed number). A lower number with an earlier date (backdated entry) is still allowed. The "inferiore all'ultima lettura" warning waits until the number is as long as the last reading.

## Build 24

Version 1.4 (24).
- Settings > Backup dei dati: new "Promemoria per esportare" with Mai / 7 giorni / 30 giorni (default 30, like before build 23). It counts from the last "Esporta JSON"/"Esporta CSV". New notification text: "È ora di salvare una copia del backup su iCloud Drive." Automatic backups keep running whatever the choice.

## Build 23

Version 1.4 (23).
- Automatic backups now go into Scoot's own folder in Files: **Sul mio iPhone › Scoot › Backup automatici** (no folder to pick; picking an iCloud Drive folder never worked on the user's phone, builds 21-22). On by default. Tapping "Cartella" opens Files there.
- These backups live outside the database, so a wipe like the one of 11 Nov 2026 leaves them intact and the missing-data alarm can restore them. They do not survive deleting the app or losing the phone, so:
- The backup reminder is now weekly (was 30 days) and asks to export a copy to iCloud Drive. Automatic backups no longer count as "Ultimo backup"; Settings shows them separately ("Ultimo:" under Cartella).
- "Importa backup" and "Scegli un altro file" use the system picker in copy mode (the app gets a copy of the file, no access permission needed).

## Build 22

Version 1.4 (22).
- Automatic backup folder: tapping "Apri" in the folder picker did nothing. The Files picker is now shown directly by the system instead of inside a SwiftUI sheet (same for "Scegli un altro file" in the missing-data alarm).

## Build 21

Version 1.4 (21).
- Automatic backups: Settings > Backup dei dati > "Backup automatico". The first time it asks for a folder (pick one in iCloud Drive); from then on Scoot saves a backup there once a day when you open the app (`scoot-auto-YYYY-MM-DD.json`) and keeps the last 30. It never saves when the app is empty, so a wipe cannot push good backups out. An automatic backup also updates "Ultimo backup".
- Missing-data alarm: Scoot remembers how many entries it had when it last left the screen. If it opens empty after having data, a card over everything says "I tuoi dati sembrano spariti" and offers the newest automatic backup in one tap ("Ripristina questo backup"), another file, or "Non ora".

## Build 20

Version 1.4 (20).
- Data loss fix. The database is now `Scoot.store` in Scoot's own private folder. Until build 19 SwiftData used its default: `default.store` in the App Group folder that Signulous adds to every sideloaded app, shared with any other SwiftData app. On 11 Nov 2026 the Cycle app (same default) opened that file and converted it to its own format, dropping Scoot's tables; when Scoot opened at 16:35 it converted it back, empty. Proof in the diagnostic export: the change log names `com.personal.cycle` and three lightweight migrations, all entity counters at zero.
- The new private database starts empty: restore the last backup after installing.
- Settings shows the real version (it always said 1.0 (1): the Info.plist did not take the project version).

## Build 19

Version 1.4 (19).
- Settings > Backup: new "Esporta database (diagnostica)". It copies the raw database files exactly as they are (database, its journal files, the photos folder) plus a report (file sizes and dates, version, a few settings) into one .zip to share. Added to find out why the data disappeared on 11 Nov 2026. It does not count as a backup.
- Import backup: the file picker now lets you choose any file (a backup .json saved in iCloud Drive was greyed out). The app still checks that the contents are a real Scoot backup before replacing anything.

## Build 18

Version 1.4 (18).
- Tab bar: tapping the tab you are already on goes back one page when you are inside a sub-page (Settings, Attività, a vehicle page, Stats), and scrolls the page to the top when you are on the main page.
- Monthly recap, km per week: a week cut by the month edge that has fewer than 4 days is merged into its neighbour, so there are no one-day bars (November 2026 shows 1–8, 9–15, 16–22, 23–30).

## Build 17

Version 1.4 (17).
- New pop-up "Ultimi due pieni": the first time you open the app after a fill-up, a card over everything shows the km/L of your last two tanks ("40 km/L, ± 3, stima"), with km and litres for each tank and in total. Close it with the X, "Ok" or a tap outside. It shows once per fill-up and never right after saving (the app must go to the background first). It needs three fill-ups marked "Spia della riserva accesa", the newest being the latest fill-up.
- Fuel and Stats: the chart hint now says "Servono almeno 400 km in totale tra i rifornimenti registrati" (the old text suggested 400 km between two fill-ups).
- Price and consumption charts: a small gap between the last point and the y-axis labels.

## Build 16

Version 1.4 (16).
- Home: the "Attività recente" title now has a ">" and opens "Attività", the full history of all your vehicles. It is the same view as Garage > Filippo: search, filter chips and entries grouped by month with totals. Swipe to edit or delete works there too.
- The history block of the vehicle page was moved into one shared view (`HistoryList`), so both places always look and behave the same.

## Build 15

Version 1.4 (15).
- Fixed: the recap pop-up was wider than the screen (the big scooter behind the text stretched the layout), so the text was cut on both sides. The shared image had the same problem.
- Recaps now count only from 1 November 2026: the earlier entries were tests. No recap for earlier months, and km are no longer spread over the gap between an old reading (for example the April repair) and the first real one. The first recap pop-up is on 1 December, for November.
- Settings > Riepiloghi mensili also shows the running month, marked "in corso", so you can preview it before the month ends. It never opens by itself.
- If a month has no usable day-by-day estimate, km come from the lowest and highest odometer reading of that month.

## Build 14

Version 1.4 (14).
- Monthly recap. On the first open of a new month, a sheet slides up with the month that just ended: km, km per week (with the km inside each bar), spent, litres, average consumption, refuels, change compared with the month before, where the money went and a consumption chart. It opens once per month; if you miss the 1st it opens the next time you open the app. Nothing opens when the month has no data, over the Face ID lock, or over another sheet.
- "Condividi" makes a vertical image of the month (360 pt wide, saved at 1080 px) and opens the share sheet.
- Settings > Riepiloghi mensili: a list of every past month with data; tap one to see its full recap again.
- The scooter from the app is drawn large and almost invisible behind the text of the pop-up and of the image.

## Build 13

Version 1.3 (13).
- Switching tabs: the new screen appears right away and its blocks then bounce up from below one after the other, top block first ("cascata dal basso"). Replaces the earlier fade and pop.

## Build 12

Version 1.3 (12).
- Switching tabs is bouncier: the new screen fades in quickly and pops up from slightly smaller with a springy bounce (same bounce as the bar's highlight)

## Build 11

Version 1.3 (11).
- Fixed: the tab bar at the bottom had disappeared in build 10 (the screens were drawn on top of it)

## Build 10

Version 1.3 (10).
- Switching tabs is now a soft fade: the new screen fades in over the old one, no bounce
- The screens stay ready in the background, so there is no hiccup, and each tab remembers where you were (scroll position, open page)

## Build 9

Version 1.3 (9).
- Home: the Filippo card now slides down smoothly when you hold a month (in build 8 it jumped)

## Build 8

Version 1.3 (8). Everything below is new and has not been run on a phone yet.

Home
- The Filippo card sits right under the month bars; hold a month and it slides down smoothly to make room for the list of where the money went

Statistics
- New "Km percorsi": kilometres per month or per week (last 12 weeks), hold and drag to read, average and best
- New "Il tuo anno con Filippo" card at the bottom, opening a yearly summary (km, money, fuel, month by month, priciest month without insurance, road tax and inspection)

Quick start
- Shortcuts action "Nuovo rifornimento" opens the app on the new fill-up form (add it to Control Center, the Action Button or the lock screen from the Shortcuts app)
- Long-press the app icon: "Nuovo rifornimento"

Selling
- Settings: "Storico per la vendita" makes a PDF with make, model, kilometres, maintenance and deadlines (no nickname, no photos) and shares it

Photos
- Maintenance and expense entries can have photos (camera or library); tap to open full screen, pinch to zoom, delete
- Photos are saved in the backup (the backup file gets bigger); they are not in the PDF

Search
- Vehicle page, Storico: search box and filters (Tutto, Rifornimenti, Manutenzione, Spese, Km), result count and total, matches marked

## Build 7

Version 1.2 (7).

Month bars (Home and Stats)
- The month lights up the moment you touch the bars, like the price graph: no waiting
- Drag sideways to move between months (the page stays still); drag up or down and the page scrolls as usual

## Build 6

Version 1.2 (6), shown in Settings.

Spending by month (Home and Stats)
- Bars follow everyday spending, so insurance in July no longer makes the other months look empty
- The yearly part (insurance, road tax, inspection) sits on top in a lighter colour; when it is too tall it fades out at the top
- All bars have the same small corner radius, so tall bars are rectangles, not pills
- Home: the chart is taller and there is no caption under it
- Home: hold a month and a small list under the bars shows where the money went (category, amount); what does not fit on two lines is added up under "Altre voci". The Filippo card now sits a little lower all the time

New entry
- The "Nuova registrazione" sheet is only as tall as its four cards; it grows when you open a form

Home status line
- Overdue items are shown separately from coming-up ones ("1 scaduta · 2 in arrivo"), with the right singular
- A maintenance job that is past its km counts as overdue even before the app can estimate days

Swipe to delete
- The line under an open row now stops at the same gap as the line above it

## Build 5

Fuel
- New switch "Spia della riserva accesa" on the fill-up form (also when editing)
- Consumption is measured from one fill-up with the light on to the next one, once two are marked; until then the 400 km average is used
- Stats and Fuel say which method the graph is showing

Spending by month
- Press and hold a month bar on Home, then drag to another month: the number and title follow, and lifting your finger returns to this month
- Same on the Stats screen, with a line above the bars showing the month, the total and the yearly part

Swipe to delete
- A gap between the amount and the trash block when a row is open

Fix
- Build 4 did not compile (one missing word); fixed

## Build 4

Swipe to delete on entries
- The page no longer scrolls while a row is dragged sideways
- An open row slides back when the page is scrolled or something else is tapped
- Only one row is open at a time
- Flick to open or close, stretch past the end, bouncy settle
- The trash icon pops in, with a haptic tick at the point where the row stays open

Screens
- Bottom buffer on the vehicle page, Stats and Settings, so the last item stops above the menu bar

Menu bar
- Each tab is tappable across its whole quarter of the bar and the full 56 pt height, not only the icon

## Build 3

Entries
- Tap any entry (fill-up, maintenance, expense, odometer) to edit it
- Delete button in the edit form, with a confirmation
- Swipe left on an entry to show an accent-coloured trash block, with a confirmation before deleting
- Press and hold still offers Delete, now with a confirmation

Look
- New iOS-style toggle switches with a soft knob shadow
- Stronger shadow under the menu bar
- The + button in the menu bar is now filled with the accent colour
- More space above the title on the new-entry screen (32 pt)

Screens
- Tapping the vehicle card on Home opens the full vehicle page
- The whole upper part of the vehicle card in the Garage is tappable
- Garage "In arrivo" shows only what is due in the next 30 days, plus anything overdue
- A PIAGGIO tag marks maintenance whose interval comes from the official Piaggio schedule
- Other full-width rows are now tappable across their whole width (checklist, maintenance picker, deadline cells, summary link)

Motion
- Bouncier taps, toggles, list changes and Save button
- New entries pop in, deleted ones slide out
- The tab content fade is unchanged

Navigation
- Swipe from left to right anywhere to go back (charts are excluded)

Project
- Build workflow uses the Intel macOS runner
- DESIGN.md and HANDOFF.md updated to match
