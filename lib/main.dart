import 'package:flutter/material.dart';

import 'controller.dart';
import 'rx_scheduler.dart';
import 'theme.dart';
import 'toast.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RxSchedulerDemoApp());
}

/// Standalone demo host. RepairX should own [RxSchedulerController]
/// at the app (or session) level instead of this widget — see INTEGRATION.md.
class RxSchedulerDemoApp extends StatefulWidget {
  const RxSchedulerDemoApp({super.key});

  @override
  State<RxSchedulerDemoApp> createState() => _RxSchedulerDemoAppState();
}

class _RxSchedulerDemoAppState extends State<RxSchedulerDemoApp> {
  late final RxSchedulerController controller;

  @override
  void initState() {
    super.initState();
    controller = RxSchedulerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepairX Scheduler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Wb.page,
        colorScheme: const ColorScheme.light(
          primary: Wb.primary,
          onPrimary: Wb.onPrimary,
          surface: Wb.cream,
          onSurface: Wb.ink,
          error: Wb.accent,
        ),
        fontFamily: Wb.sans,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Wb.ink,
          contentTextStyle: Wb.ui(size: 13, color: Wb.onPrimary),
        ),
      ),
      builder: (context, child) {
        return RxToastHost(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: RxScheduler(controller: controller),
    );
  }
}
