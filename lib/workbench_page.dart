import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/chrome.dart';
import 'widgets/month_overlay.dart';
import 'widgets/tech_sheet.dart';
import 'widgets/timeline.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key, required this.ctrl});
  final SchedulerController ctrl;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  SchedulerController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    ctrl.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = ctrl.date;
    final title = '${kDayNames[date.weekday % 7]} ${ctrl.day} ${kMonNames[ctrl.month]}';

    return Scaffold(
      backgroundColor: Wb.page,
      body: Stack(
        children: [
          Positioned.fill(
            child: SelectionArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 1180 ? 1180.0 : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 38),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(ctrl: ctrl, title: title),
                            const SizedBox(height: 20),
                            _KpiStrip(ctrl: ctrl),
                            const SizedBox(height: 18),
                            BenchTimeline(ctrl: ctrl),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (ctrl.sheetIndex != null)
            Positioned.fill(child: TechSheet(ctrl: ctrl)),
          if (ctrl.monthOpen) MonthOverlay(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ctrl, required this.title});
  final SchedulerController ctrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Wb.line)),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x1C2563EB),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '✦',
                  style: TextStyle(fontSize: 15, color: Wb.primary, height: 1),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctrl.workshopName,
                    style: Wb.kicker(size: 10.5, tracking: 0.16),
                  ),
                  const SizedBox(height: 3),
                  Text(title, style: Wb.display(38)),
                ],
              ),
            ],
          ),
          const SizedBox(width: 22),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WbCircleBtn(glyph: '←', onTap: ctrl.prevDay),
                const SizedBox(width: 7),
                WbPill(label: 'Today', onTap: ctrl.today, height: 33, hPad: 13),
                const SizedBox(width: 7),
                WbCircleBtn(glyph: '→', onTap: ctrl.nextDay),
                const SizedBox(width: 10),
                Text(
                  'Week 35 · ${ctrl.clockedCount} technicians clocked in',
                  style: Wb.ui(size: 11.5, color: Wb.muted2),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 9,
              children: [
                WbPill(
                  label: 'Copy last week',
                  leading: const Text('⧉'),
                  onTap: ctrl.copyWeek,
                ),
                WbPill(
                  label: 'Month overlay',
                  peach: true,
                  leading: const Text('▦'),
                  onTap: ctrl.openMonth,
                ),
                WbPill(
                  label: ctrl.approved ? '4 sheets approved' : 'Approve 4 sheets',
                  filled: true,
                  leading: const Text('✓'),
                  onTap: ctrl.approve,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.ctrl});
  final SchedulerController ctrl;

  @override
  Widget build(BuildContext context) {
    final stats = ctrl.stats;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Wb.rXl),
      child: Container(
        decoration: BoxDecoration(
          color: Wb.cream,
          border: Border.all(color: Wb.line),
          boxShadow: Wb.cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < stats.length; i++)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Wb.cream,
                      border: i == 0 ? null : const Border(left: BorderSide(color: Wb.line)),
                    ),
                    padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
                    child: _Kpi(stat: stats[i], bar: ctrl.statBarWidth(stats[i])),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.stat, required this.bar});
  final StatTile stat;
  final double bar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: stat.dot, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 7),
            Text(stat.label, style: Wb.kicker(size: 10, tracking: 0.15)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(stat.value, style: Wb.display(32, color: stat.valueColor)),
            if (stat.unit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(stat.unit, style: Wb.ui(size: 12, color: Wb.muted2)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: bar,
                    backgroundColor: Wb.wash,
                    color: stat.bar,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(stat.sub, style: Wb.ui(size: 11, color: Wb.muted2)),
          ],
        ),
      ],
    );
  }
}
