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
- **Month overlay** — Hours / Crew / Approval lenses

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

## Mockup

The zip contains five design-system looks (Workbench, Workbench dark, Anchor, Atelier, Shift). This app implements the Workbench calendar layout, restyled with **Rail** (RepairX) light tokens: Inter, blue-on-slate, hairline cards.
