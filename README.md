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
- **Clocked time** — drag either end of a shift, or − / ＋ for 30 minutes
- **Clock in / Clock out** — technician sheet, or `controller.clockIn` / `clockOut`
- **Repairs** — appointed jobs on the same time axis
- **Now line** — live when you pass `now: DateTime.now`
- **Bench coverage** — dashed line is the 4-tech walk-in SLA
- **Month overlay** — Hours / Crew / Approval lenses
- **Overlay toasts** — `RxToastHost` above the navigator

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

## Design

Workbench calendar layout, restyled with **Rail** (RepairX) light tokens:
Inter, blue-on-slate, hairline cards. Purple is reserved for AI and is not
used on this screen (overtime uses error red).
