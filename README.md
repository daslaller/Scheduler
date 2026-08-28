# rx_scheduler

Drop-in Flutter package for the RepairX **bench scheduler**: day calendar,
clock in / clock out from any screen, and overlay toasts that still show when
the calendar (or a sheet) is in the foreground.

RepairX integration is documented in **[INTEGRATION.md](INTEGRATION.md)**.

```dart
import 'package:rx_scheduler/scheduler.dart';
```

## Use in RepairX

```yaml
dependencies:
  rx_scheduler:
    git:
      url: https://github.com/daslaller/Scheduler.git
      ref: main
```

```dart
final scheduler = RxSchedulerController(
  technicians: crew,          // Technician.id = RepairX staff id
  now: DateTime.now,
  workshopName: 'RepairX — Workshop 01',
  seedOnTheClock: false,
);

MaterialApp(
  builder: (context, child) => RxToastHost(
    controller: scheduler,
    child: child ?? const SizedBox.shrink(),
  ),
);

// Calendar route
RxScheduler(controller: scheduler);

// POS / ticket / kiosk — same controller
scheduler.clockIn(staffId);
scheduler.clockOut(staffId);
```

## What’s on the bench

- **Day bench** — previous / next / Today
- **KPI strip** — clocked hours, utilisation, overtime, billable labour
<<<<<<< HEAD
- **Clocked time** — drag either end of a shift, or use − / ＋ to add or drop 30 minutes
- **Repairs** — appointed jobs on the same time axis, shaded by the technician’s clocked band
- **Now line** at 1:45p
- **Bench coverage** chart (dashed line = 4-tech walk-in SLA)
- **Technician sheet** — clock in/out steppers, week load, appointed work
- **Month overlay** — Hours / Crew / Approval lenses, opened as a **modal**
  (the route owns Escape, the back button and the scrim)
- **My schedule** — one technician's week, a row per day, reusing the same
  month overlay projected onto that person
=======
- **Clocked time** — drag either end of a shift, or − / ＋ for 30 minutes
- **Clock in / Clock out** — technician sheet, or `controller.clockIn` / `clockOut`
- **Repairs** — appointed jobs on the same time axis
- **Now line** — live when you pass `now: DateTime.now`
- **Bench coverage** — dashed line is the 4-tech walk-in SLA
- **Month overlay** — Hours / Crew / Approval lenses
- **Overlay toasts** — `RxToastHost` above the navigator
>>>>>>> origin/main

The demo (this app’s `main.dart`) freezes Monday 24 August 2026 at 1:45p.

## Run the demo

Flutter 3.47+ :

```bash
flutter pub get
flutter run -d chrome
```

Or serve web on a fixed port:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 45241
```

```bash
flutter test
flutter analyze
```

<<<<<<< HEAD
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
=======
## Design
>>>>>>> origin/main

Workbench calendar layout, restyled with **Rail** (RepairX) light tokens:
Inter, blue-on-slate, hairline cards. Purple is reserved for AI and is not
used on this screen (overtime uses error red).
