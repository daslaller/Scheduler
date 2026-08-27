import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northline_schedule/controller.dart';
import 'package:northline_schedule/main.dart';
import 'package:northline_schedule/models.dart';

void main() {
  test('formatHour matches mockup labels', () {
    expect(formatHour(8), '8a');
    expect(formatHour(13.75), '1:45p');
    expect(formatHour(16.5), '4:30p');
    expect(formatHour(12), '12p');
    expect(formatHour(0), '12a');
  });

  test('Monday 24 August 2026 is the default bench day', () {
    final d = DateTime(2026, 8, 24);
    expect(kDayNames[d.weekday % 7], 'Monday');
    expect(kMonNames[7], 'August');
  });

  test('clock nudge keeps a 30-minute minimum shift', () {
    final c = SchedulerController();
    final before = c.clockOf(0);
    expect(before.inHour, 13);
    expect(before.outHour, 19);
    c.nudge(0, inSide: false, delta: -0.5);
    expect(c.clockOf(0).outHour, 18.5);
    c.nudge(0, inSide: true, delta: 20);
    expect(c.clockOf(0).outHour - c.clockOf(0).inHour, greaterThanOrEqualTo(0.5));
  });

  test('day meta marks weekday crews as at least three technicians', () {
    final wed = dayMeta(7, 5);
    expect(wed.crewN, greaterThanOrEqualTo(3));
  });

  test('default clocked hours sum across the bench', () {
    final c = SchedulerController();
    expect(c.totalHours, 42.5);
    expect(c.capacity, 59.5);
    expect(c.overtimeHours, 0.5);
  });

  testWidgets('workbench renders the workshop title and KPIs', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NorthlineApp());
    await tester.pump();
    expect(find.textContaining('Northline Device Repair'), findsOneWidget);
    expect(find.text('Monday 24 August'), findsOneWidget);
    expect(find.text('Clocked hours'), findsOneWidget);
    expect(find.text('Alex Kim (you)'), findsOneWidget);
    expect(find.text('BENCH COVERAGE'), findsOneWidget);
  });
}
