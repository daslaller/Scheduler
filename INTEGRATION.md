# Integrating rx_scheduler into RepairX

This repo is a Flutter **package** (`rx_scheduler`) plus a standalone demo app.
RepairX should depend on it and host one shared controller — not copy widgets.

## 1. Depend on the package

In RepairX `pubspec.yaml`:

```yaml
dependencies:
  rx_scheduler:
    git:
      url: https://github.com/daslaller/Scheduler.git
      ref: main
```

Import only the barrel:

```dart
import 'package:rx_scheduler/scheduler.dart';
```

Do not import `package:rx_scheduler/main.dart`. That file is the demo host.

## 2. Own one controller

Create **one** `RxSchedulerController` at the RepairX session / workshop
level. Pass it into the calendar, POS, ticket screens, and the toast host.
Clock in on the till then updates the bench, and clock out on the bench
then updates the till — same object, same streams.

```dart
final scheduler = RxSchedulerController(
  technicians: repairxTechnicians, // see §4
  now: DateTime.now,               // live clock; omit only for the demo freeze
  initialDate: DateTime.now(),
  workshopName: 'RepairX — Workshop 01',
  seedOnTheClock: false,           // POS / RepairX owns punches
);
```

Dispose it with the session:

```dart
@override
void dispose() {
  scheduler.dispose();
  super.dispose();
}
```

`RxScheduler` does **not** dispose the controller.

## 3. Overlay toasts (required for notifications)

Toasts are **not** `SnackBar`s. They insert into a host overlay **above** the
navigator, so they still appear when:

- the scheduler is the current route
- a technician sheet or month overlay is open
- another RepairX route (POS, ticket) is in the foreground

Wire this once on `MaterialApp`:

```dart
MaterialApp(
  builder: (context, child) => RxToastHost(
    controller: scheduler,
    child: child ?? const SizedBox.shrink(),
  ),
  home: const RepairXShell(),
);
```

Then, from **any** screen that holds the controller:

```dart
scheduler.clockIn(currentUserId);
scheduler.clockOut(currentUserId);

// Optional: same overlay, no punch
scheduler.showToast('Ticket #1842 on bench', kind: RxToastKind.info);
```

`clockIn` / `clockOut` emit a toast unless you pass `silent: true`.

Toasts tap-to-dismiss and auto-clear after ~3 seconds.

If you omit `RxToastHost`, punches still update the calendar; notifications
are simply not shown.

## 4. Technician ids

Clock in/out keys off `Technician.id`. Map RepairX user / staff ids 1:1.

```dart
Technician(
  id: staff.uid,          // must match the id you pass to clockIn / clockOut
  name: staff.displayName,
  role: staff.roleLabel,
  initial: staff.initials,
  cert: staff.certLabel,
  tint: staff.avatarColor,
  clockIn: 9,             // planned shift start (24h fractional, 9.5 = 9:30)
  clockOut: 17,           // planned shift end
  breakAt: 12,            // 0 = no break marker
)
```

`kDemoTechnicians` uses `ak`, `pr`, `rm`, `tl`, `bh`, `nc`, `tb`.

Hours are fractional 24h values (`13.75` = 1:45pm). `hourFromDateTime` and
`formatHour` are exported.

## 5. Drop the calendar in

```dart
RxScheduler(controller: scheduler)
```

That is a widget, not an app. RepairX keeps its own `MaterialApp`, routes,
and chrome.

From a descendant of `RxScheduler` you can also:

```dart
final ctrl = RxSchedulerScope.of(context);
ctrl.clockOut(techId);
```

Other routes should take the controller as a constructor argument (or via
your existing RepairX locator). `RxSchedulerScope` only exists under the
calendar widget.

## 6. Clock in / clock out from POS, tickets, kiosk

```dart
final result = scheduler.clockIn(staffId);          // now()
final result = scheduler.clockOut(staffId, at: DateTime.now());
```

| Call | When it succeeds | When it fails (toast) |
| --- | --- | --- |
| `clockIn(id)` | `id` is known and **not** punched in | unknown id, or already on the clock |
| `clockOut(id)` | `id` is known and **is** punched in | unknown id, or not on the clock |

Both return `ClockResult`:

```dart
if (result.ok) {
  // result.event!.hours  — inHour / outHour / paid
} else {
  // result.message already toasted unless silent: true
}
```

Query state:

```dart
scheduler.isOnTheClock(staffId);
scheduler.hoursFor(staffId);       // ClockHours? for the open day
scheduler.onTheClockIds;           // Set<String>
scheduler.technicianById(staffId);
```

`seedOnTheClock: false` (recommended in RepairX) starts everyone **off** the
clock. Planned `clockIn` / `clockOut` on `Technician` still draw the shift
bars; punches are only the live API.

`seedOnTheClock: true` (demo default) marks anyone whose planned window
contains `now()` as already punched in.

Pass `silent: true` when RepairX will show its own UI for the result.

## 7. Listen for punches (sync timesheets / backend)

```dart
late final StreamSubscription<ClockEvent> _punches;

@override
void initState() {
  super.initState();
  _punches = scheduler.clockEvents.listen((event) {
    switch (event.action) {
      case ClockAction.clockIn:
        repairxTimesheets.openShift(
          staffId: event.technicianId,
          at: event.at,
        );
      case ClockAction.clockOut:
        repairxTimesheets.closeShift(
          staffId: event.technicianId,
          at: event.at,
          hours: event.hours.paid,
          overtime: event.overtime,
        );
    }
  });
}

@override
void dispose() {
  _punches.cancel();
  super.dispose();
}
```

`ClockEvent` fields: `technicianId`, `technicianName`, `action`, `at`, `hours`.

The calendar `Listenable` (`addListener`) fires on punches as well, so the
bench rebuilds without this subscription. Use `clockEvents` for **side
effects** (API writes), not for painting.

## 8. Suggested RepairX wiring

```dart
class RepairXSession {
  RepairXSession(List<Technician> crew)
      : scheduler = RxSchedulerController(
          technicians: crew,
          now: DateTime.now,
          workshopName: 'RepairX — Workshop 01',
          seedOnTheClock: false,
        );

  final RxSchedulerController scheduler;

  void dispose() => scheduler.dispose();
}

// Root
MaterialApp(
  builder: (context, child) => RxToastHost(
    controller: session.scheduler,
    child: child ?? const SizedBox.shrink(),
  ),
);

// Calendar route
RxScheduler(controller: session.scheduler)

// POS / ticket
FilledButton(
  onPressed: () => session.scheduler.clockIn(currentStaffId),
  child: const Text('Clock in'),
)
FilledButton(
  onPressed: () => session.scheduler.clockOut(currentStaffId),
  child: const Text('Clock out'),
)
```

## 9. Public API (barrel)

| Symbol | Role |
| --- | --- |
| `RxScheduler` | Bench calendar widget |
| `RxSchedulerScope` | Inherited handle under the calendar |
| `RxSchedulerController` | Shared state + `clockIn` / `clockOut` / `showToast` |
| `Technician` | Crew member (`id` is the punch key) |
| `ClockResult` / `ClockEvent` / `ClockAction` | Punch results and stream |
| `ClockHours` | `inHour`, `outHour`, `paid`, `overtime` |
| `RxToastHost` / `RxToast` / `RxToastKind` | Overlay notifications |
| `kDemoTechnicians` | Demo crew if you omit `technicians:` |

`SchedulerController` is a typedef for `RxSchedulerController`.

## 10. Demo app in this repo

```bash
flutter pub get
flutter run -d chrome
```

The demo freezes “now” at **1:45p, Monday 24 August 2026** so the mockup
data lines up. RepairX must pass `now: DateTime.now`.
