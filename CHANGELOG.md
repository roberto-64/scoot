# Changelog

Newest first. Dates are 2 and 3 November 2026.

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
