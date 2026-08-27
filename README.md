# Northline Schedule

Flutter recreation of the **Workbench Scheduler** from the Schedule Calendar UI mockup — a repair-shop bench calendar for Northline Device Repair, Workshop 02.

The screen is a working day planner, not a static picture: technicians, clocked shifts, appointed repairs, coverage, timesheets, and a month overlay all follow the mockup’s data and interactions.

## What’s in the app

- **Day bench** — Monday 24 August 2026 by default, with previous / next / Today
- **KPI strip** — clocked hours, utilisation, overtime, billable labour
- **Clocked time** — drag either end of a shift, or use − / ＋ to add or drop 30 minutes
- **Repairs** — appointed jobs on the same time axis, shaded by the technician’s clocked band
- **Now line** at 1:45p
- **Bench coverage** chart (dashed line = 4-tech walk-in SLA)
- **Technician sheet** — clock in/out steppers, week load, appointed work
- **Month overlay** — Hours / Crew / Approval lenses, opened as a **modal**
  (the route owns Escape, the back button and the scrim)
- **My schedule** — one technician's week, a row per day, reusing the same
  month overlay projected onto that person

## Run locally

Flutter 3.47+ with the web renderer:

```bash
flutter pub get
flutter run -d chrome
```

Or serve web on a fixed port:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 45241
```

Then open `http://localhost:45241`.

```bash
flutter test
flutter analyze
```

## The honesty rules

Four things the board refuses to do, each because getting it wrong costs
somebody money rather than looks:

- **Settled and still-running hours are never added together.** A single
  "clocked hours" figure is what a four-column timesheet prints, and it is how
  a forgotten Friday punch reaches payroll as a number that grew all weekend.
- **A shift somebody is standing in is not a fix.** Both are open; only
  elapsed time separates them (`ClockHours.live`, sixteen hours). Counting
  today's live clock-in as a problem is how the alarm stops being read.
- **Only a punch may widen the day.** An open run's end is a cap, not a punch,
  and a run that entered from yesterday does not pull the axis into the small
  hours — either one squashes every real shift to a third of its width.
- **No handle on an open shift.** Dragging it would invent the missing
  clock-out. Closing one is a deliberate act, not a nudge.

Screens are photographed rather than described:

```bash
flutter test test/screens_screenshot_test.dart   # build/shots/*.png
```

## Mockup

The zip contains five design-system looks (Workbench, Workbench dark, Anchor, Atelier, Shift). This app implements the Workbench calendar layout, restyled with **Rail** (RepairX) light tokens: Inter, blue-on-slate, hairline cards.
