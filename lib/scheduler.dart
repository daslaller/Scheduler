/// Drop-in RepairX scheduler.
///
/// ```dart
/// import 'package:rx_scheduler/scheduler.dart';
/// ```
///
/// See INTEGRATION.md for clock in/out and overlay toasts.
library;

export 'controller.dart' show RxSchedulerController, SchedulerController;
export 'models.dart'
    show
        Technician,
        Worker,
        ClockHours,
        ClockAction,
        ClockEvent,
        ClockResult,
        RxScheduleHistory,
        DayMeta,
        dayMetaFrom,
        RepairJob,
        JobKind,
        TimelineView,
        SheetTab,
        MonthMode,
        ApprovalStatus,
        kDemoTechnicians,
        workers,
        formatHour,
        hourFromDateTime;
export 'toast.dart' show RxToast, RxToastHost, RxToastKind, RxToastMessage, RxToastSource;
export 'rx_scheduler.dart' show RxScheduler, RxSchedulerScope;
