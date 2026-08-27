import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import 'chrome.dart';

class TechSheet extends StatelessWidget {
  const TechSheet({super.key, required this.ctrl});
  final SchedulerController ctrl;

  @override
  Widget build(BuildContext context) {
    final i = ctrl.sheetIndex;
    if (i == null) return const SizedBox.shrink();
    final w = workers[i];
    final clock = ctrl.clockOf(i);
    final jobs = ctrl.jobsOf(i);
    final week = ctrl.weekLoad(i);
    final weekTotal = week.fold<double>(0, (a, b) => a + b);
    final appointed = jobs.fold<double>(0, (a, j) => a + j.duration);
    final expectedEnd = jobs.isEmpty
        ? clock.outHour
        : jobs.map((j) => j.end).reduce((a, b) => a > b ? a : b);
    final delta = appointed - clock.paid;
    final date = ctrl.date;
    final showClock = ctrl.sheetTab == SheetTab.clock;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: ctrl.closeSheet,
            child: Container(color: Wb.scrim),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          bottom: 16,
          width: 394,
          child: Material(
            color: Wb.cream,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Wb.rXl),
              side: const BorderSide(color: Wb.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: Wb.overlayShadow,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 21, 24, 19),
                    decoration: const BoxDecoration(
                      color: Wb.cream2,
                      border: Border(bottom: BorderSide(color: Wb.line2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WbAvatar(initial: w.initial, tint: w.tint, size: 46, radius: 13),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.name, style: Wb.display(26)),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${w.role} · ${w.cert}',
                                    style: Wb.kicker(size: 10, tracking: 0.12),
                                  ),
                                ],
                              ),
                            ),
                            WbCircleBtn(glyph: '✕', onTap: ctrl.closeSheet, size: 30),
                          ],
                        ),
                        const SizedBox(height: 17),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            color: Wb.line2,
                            child: Row(
                              children: [
                                _MiniStat(label: 'Today', value: '${clock.paid.toStringAsFixed(1)}h'),
                                _MiniStat(label: 'Week', value: '${weekTotal.toStringAsFixed(1)}h'),
                                _MiniStat(
                                  label: 'Overtime',
                                  value: '${(clock.overtime ? clock.paid - 8 : 0).toStringAsFixed(1)}h',
                                  warn: clock.overtime,
                                ),
                                _MiniStat(label: 'Breaks', value: clock.hasBreak ? '30m' : '—'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 19, 24, 19),
                      children: [
                        SegmentedTabs(
                          labels: const ['Clocked time', 'Appointed work'],
                          index: showClock ? 0 : 1,
                          onChanged: (v) =>
                              ctrl.setSheetTab(v == 0 ? SheetTab.clock : SheetTab.work),
                        ),
                        const SizedBox(height: 16),
                        if (showClock) ...[
                          Text(
                            '${kDayNames[date.weekday % 7]} ${ctrl.day} ${kMonNames[ctrl.month]}',
                            style: Wb.kicker(size: 10, tracking: 0.13),
                          ),
                          const SizedBox(height: 12),
                          _ClockStepper(
                            label: 'Clock in',
                            value: formatHour(clock.inHour),
                            onMinus: () => ctrl.nudge(i, inSide: true, delta: -0.5),
                            onPlus: () => ctrl.nudge(i, inSide: true, delta: 0.5),
                          ),
                          const SizedBox(height: 9),
                          _ClockStepper(
                            label: 'Clock out',
                            value: formatHour(clock.outHour),
                            onMinus: () => ctrl.nudge(i, inSide: false, delta: -0.5),
                            onPlus: () => ctrl.nudge(i, inSide: false, delta: 0.5),
                          ),
                          const SizedBox(height: 18),
                          Text('Week load', style: Wb.kicker(size: 10, tracking: 0.13)),
                          const SizedBox(height: 12),
                          _WeekBars(values: week, highlight: 4),
                        ] else ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: delta > 0.25 ? Wb.accentSoft : Wb.cream2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: delta > 0.25 ? Wb.accentBorder2 : Wb.line2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expected finish ${formatHour(expectedEnd)}',
                                        style: Wb.ui(size: 13, weight: FontWeight.w600, tracking: -0.065),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${appointed.toStringAsFixed(1)}h of appointed work against ${clock.paid.toStringAsFixed(1)}h clocked',
                                        style: Wb.ui(size: 11, color: Wb.muted2, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}h',
                                      style: Wb.code(
                                        size: 20,
                                        color: delta > 0.25
                                            ? Wb.accent
                                            : delta < -0.25
                                                ? Wb.toneSuccessFg
                                                : Wb.ink,
                                      ),
                                    ),
                                    Text('vs clocked', style: Wb.kicker(size: 9, tracking: 0.1)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          for (var j = 0; j < jobs.length; j++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _JobRow(job: jobs[j], index: j, past: jobs[j].end > clock.outHour + 0.01),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                    decoration: const BoxDecoration(
                      color: Wb.cream2,
                      border: Border(top: BorderSide(color: Wb.line2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: WbPill(
                            label: 'Approve timesheet',
                            filled: true,
                            expand: true,
                            onTap: ctrl.approve,
                          ),
                        ),
                        const SizedBox(width: 9),
                        WbPill(label: 'Reassign', onTap: () {}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.warn = false});
  final String label, value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: warn ? Wb.accentSoft : Wb.cream,
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Wb.kicker(size: 9, tracking: 0.11)),
            const SizedBox(height: 3),
            Text(value, style: Wb.code(size: 17, color: warn ? Wb.accent : Wb.ink)),
          ],
        ),
      ),
    );
  }
}

class _ClockStepper extends StatelessWidget {
  const _ClockStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final String label, value;
  final VoidCallback onMinus, onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Wb.cream2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Wb.line2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Wb.kicker(size: 10, tracking: 0.11)),
                const SizedBox(height: 3),
                Text(value, style: Wb.code(size: 19)),
              ],
            ),
          ),
          _sq(onMinus, '−'),
          const SizedBox(width: 8),
          _sq(onPlus, '+'),
        ],
      ),
    );
  }

  Widget _sq(VoidCallback onTap, String g) {
    return HoverTap(
      onTap: onTap,
      builder: (_, hover) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Wb.cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hover ? Wb.ink : Wb.line),
        ),
        child: Text(g, style: Wb.ui(size: 14, color: Wb.body)),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.index, required this.past});
  final RepairJob job;
  final int index;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(job.kind);
    final st = past
        ? 'Past clock-out'
        : index == 0
            ? 'Approved'
            : index == 1
                ? 'Submitted'
                : 'Draft';
    final bg = past
        ? Wb.accentSoft
        : st == 'Approved'
            ? Wb.toneSuccessBg
            : st == 'Submitted'
                ? Wb.toneInfoBg
                : Wb.toneNeutralBg;
    final fg = past
        ? Wb.accentDark
        : st == 'Approved'
            ? Wb.toneSuccessFg
            : st == 'Submitted'
                ? Wb.toneInfoFg
                : Wb.toneNeutralFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Wb.cream2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Wb.line2),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(color: t.rail, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: Wb.ui(size: 13, weight: FontWeight.w600, tracking: -0.065)),
                const SizedBox(height: 4),
                Text(
                  '${formatHour(job.start)}–${formatHour(job.end)} · ${job.duration.toStringAsFixed(1)}h · \$${(job.duration * job.rate).round()}',
                  style: Wb.code(size: 10.5, weight: FontWeight.w500, color: Wb.muted2),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
            child: Text(
              st,
              style: TextStyle(
                fontFamily: Wb.sans,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.81,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.values, required this.highlight});
  final List<double> values;
  final int highlight;
  static const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Wb.cream2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Wb.line2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < 7; k++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.5),
                child: Column(
                  children: [
                    Text(
                      values[k] == 0 ? '—' : values[k].toStringAsFixed(1),
                      style: Wb.code(size: 9.5, weight: FontWeight.w500, color: Wb.muted2),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: values[k] <= 0 ? 0.08 : (values[k] / 10).clamp(0.08, 1),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: values[k] > 8
                                  ? Wb.accent
                                  : values[k] > 0
                                      ? Wb.coverageGreen
                                      : Wb.line2,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                                bottom: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[k],
                      style: Wb.code(
                        size: 9.5,
                        color: k == highlight ? Wb.accent : Wb.muted2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
