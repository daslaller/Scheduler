import 'package:flutter/material.dart';

import 'controller.dart';
import 'workbench_page.dart';

/// Inherited handle so other routes can call [RxSchedulerController.clockIn]
/// without plumbing the controller through every widget.
class RxSchedulerScope extends InheritedNotifier<RxSchedulerController> {
  const RxSchedulerScope({
    super.key,
    required RxSchedulerController controller,
    required super.child,
  }) : super(notifier: controller);

  static RxSchedulerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RxSchedulerScope>();
    assert(scope != null, 'RxSchedulerScope not found. Wrap the tree with RxScheduler or RxSchedulerScope.');
    return scope!.notifier!;
  }

  static RxSchedulerController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RxSchedulerScope>()?.notifier;
  }
}

/// The bench calendar as a drop-in widget. Does not create a [MaterialApp] —
/// RepairX should host that, with [RxToastHost] in `builder`.
class RxScheduler extends StatelessWidget {
  const RxScheduler({
    super.key,
    required this.controller,
  });

  final RxSchedulerController controller;

  static RxSchedulerController of(BuildContext context) => RxSchedulerScope.of(context);

  static RxSchedulerController? maybeOf(BuildContext context) =>
      RxSchedulerScope.maybeOf(context);

  @override
  Widget build(BuildContext context) {
    return RxSchedulerScope(
      controller: controller,
      child: WorkbenchPage(ctrl: controller),
    );
  }
}
