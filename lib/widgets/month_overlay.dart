import 'dart:ui';

import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import 'chrome.dart';

/// Open the month overlay **as a modal**.
///
/// Owner, 2026-08-27: *"Month overlay is a modal."* It was a `Positioned.fill`
/// layer inside the day page, which meant the page had to hold a `monthOpen`
/// flag, every screen that wanted a month had to host the layer itself, and
/// Escape and the back button did nothing. A route owns all three, and it is
/// what lets the **self view reuse the admin month unchanged** — the second
/// half of the same instruction.
Future<void> showMonthOverlay(
  BuildContext context, {
  required SchedulerController ctrl,

  /// Null draws the whole bench; a worker index draws just that person, which
  /// is the only difference between the admin month and the self month.
  int? onlyWorker,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Wb.scrim,
    builder: (_) => MonthOverlay(ctrl: ctrl, onlyWorker: onlyWorker),
  );
}

class MonthOverlay extends StatelessWidget {
  const MonthOverlay({super.key, required this.ctrl, this.onlyWorker});
  final SchedulerController ctrl;

  /// See [showMonthOverlay].
  final int? onlyWorker;

  @override
  Widget build(BuildContext context) {
    final dim = ctrl.lastDay;
    // main's roster is `ctrl.technicians`, not the const `workers`; the
    // projection rides on top of it unchanged.
    final metas = {
      for (var d = 1; d <= dim; d++)
        d: () {
          final m =
              dayMeta(ctrl.month, d, technicianCount: ctrl.technicians.length);
          return onlyWorker == null ? m : onlyTech(m, onlyWorker!);
        }(),
    };
    final all = metas.values.toList();
    final monthHours = all.fold<double>(0, (a, m) => a + m.hours);
    final monthOt = all.fold<double>(0, (a, m) => a + m.ot);
    final openDays = all.where((m) => m.crewN > 0).length;
    final approvedDays = all
        .where((m) => m.status == ApprovalStatus.approved)
        .length;
    final mode = ctrl.monthMode;
    final offset = monthStartOffset(ctrl.month);
    final weekCount = ((offset + dim) / 7).ceil();
    final cap = (onlyWorker == null ? ctrl.technicians.length : 1) * 8.5;
    // One person's own busiest day, so their bars are read against themselves
    // rather than against the shop's biggest worker.
    final myPeak = all.fold<double>(0, (a, m) => m.hours > a ? m.hours : a);

    String hint;
    switch (mode) {
      case MonthMode.hours:
        hint = onlyWorker == null
            ? 'Bar cluster = hours per technician · click a day to load its bench'
            : 'One bar a day · click a day to load its bench';
      case MonthMode.crew:
        hint = 'Bar cluster scaled to each technician’s load · click a day to load its bench';
      case MonthMode.status:
        hint = 'Dot and label show the timesheet approval state for the day';
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Align(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1240,
                  maxHeight: 900,
                ),
                child: Material(
                  color: Wb.cream,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Wb.rXl),
                    side: const BorderSide(color: Wb.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
                        decoration: const BoxDecoration(
                          color: Wb.cream2,
                          border: Border(bottom: BorderSide(color: Wb.line2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  onlyWorker == null
                                      ? 'Month overlay'
                                      : '${workers[onlyWorker!].name} · month',
                                  style: Wb.kicker(size: 10, tracking: 0.16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${kMonNames[ctrl.month]} 2026',
                                  style: Wb.display(36),
                                ),
                              ],
                            ),
                            const SizedBox(width: 18),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  WbCircleBtn(
                                    glyph: '←',
                                    onTap: ctrl.prevMonth,
                                    size: 31,
                                  ),
                                  const SizedBox(width: 7),
                                  WbCircleBtn(
                                    glyph: '→',
                                    onTap: ctrl.nextMonth,
                                    size: 31,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SegmentedTabs(
                                    labels: const ['Hours', 'Crew', 'Approval'],
                                    index: mode.index,
                                    onChanged: (i) =>
                                        ctrl.setMonthMode(MonthMode.values[i]),
                                  ),
                                  const SizedBox(width: 9),
                                  WbCircleBtn(
                                    icon: Icons.close,
                                    onTap: () => Navigator.of(context).pop(),
                                    size: 32,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: Wb.line2,
                        child: Row(
                          children: [
                            _MonthStat(
                              label: 'Month hours',
                              value: '${monthHours.toStringAsFixed(0)}h',
                              sub: onlyWorker == null
                                  ? 'across $openDays open days'
                                  : 'across $openDays days you worked',
                            ),
                            _MonthStat(
                              label: 'Overtime',
                              value: '${monthOt.toStringAsFixed(1)}h',
                              sub: 'flagged for review',
                              valueColor: Wb.accent,
                            ),
                            _MonthStat(
                              label: 'Approved',
                              value: '$approvedDays/$openDays',
                              sub: 'days signed off',
                            ),
                            // ⚠️ "Avg. bench 1.0 technicians per day" is a
                            // true sentence and a useless one when the month
                            // is one person's. The slot carries the figure
                            // that *is* about them.
                            if (onlyWorker == null)
                              _MonthStat(
                                label: 'Avg. bench',
                                value:
                                    (monthHours /
                                            (openDays == 0 ? 1 : openDays) /
                                            8)
                                        .toStringAsFixed(1),
                                sub: 'technicians per day',
                              )
                            else
                              _MonthStat(
                                label: 'Longest day',
                                value: '${myPeak.toStringAsFixed(1)}h',
                                sub: 'the most in one go',
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(26, 18, 26, 26),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    hint,
                                    style: Wb.ui(size: 11.5, color: Wb.muted2),
                                  ),
                                ),
                                const LegendDot(
                                  color: Wb.forest,
                                  label: 'Approved',
                                ),
                                const SizedBox(width: 13),
                                const LegendDot(
                                  color: Wb.purple,
                                  label: 'Submitted',
                                ),
                                const SizedBox(width: 13),
                                const LegendDot(color: Wb.gold, label: 'Draft'),
                                const SizedBox(width: 13),
                                const LegendDot(
                                  color: Wb.accent,
                                  label: 'Overtime',
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                for (final d in kDowNames)
                                  Expanded(
                                    child: Text(
                                      d,
                                      textAlign: TextAlign.center,
                                      style: Wb.kicker(
                                        size: 9.5,
                                        tracking: 0.14,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width: 92,
                                  child: Text(
                                    'Week',
                                    textAlign: TextAlign.right,
                                    style: Wb.kicker(size: 9.5, tracking: 0.14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            for (var r = 0; r < weekCount; r++)
                              _WeekRow(
                                ctrl: ctrl,
                                onlyWorker: onlyWorker,
                                peak: myPeak,
                                row: r,
                                offset: offset,
                                dim: dim,
                                metas: metas,
                                cap: cap,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });
  final String label, value, sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Wb.cream,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Wb.kicker(size: 9.5, tracking: 0.14)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: Wb.display(32, color: valueColor)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(sub, style: Wb.ui(size: 11.5, color: Wb.muted2)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.ctrl,
    required this.onlyWorker,
    required this.peak,
    required this.row,
    required this.offset,
    required this.dim,
    required this.metas,
    required this.cap,
  });
  final SchedulerController ctrl;
  final int? onlyWorker;
  final double peak;
  final int row, offset, dim;
  final Map<int, DayMeta> metas;
  final double cap;

  @override
  Widget build(BuildContext context) {
    var wkHours = 0.0;
    final cells = <Widget>[];
    for (var c = 0; c < 7; c++) {
      final dn = row * 7 + c - offset + 1;
      if (dn < 1 || dn > dim) {
        cells.add(const Expanded(child: _EmptyDay()));
        continue;
      }
      final m = metas[dn]!;
      wkHours += m.hours;
      cells.add(
        Expanded(
          child: _DayCell(
            ctrl: ctrl,
            meta: m,
            selected: dn == ctrl.day,
            onlyWorker: onlyWorker,
            peak: peak,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...cells,
            const SizedBox(width: 7),
            SizedBox(
              width: 85,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Wb.cream2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Wb.line2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      wkHours == 0 ? '—' : '${wkHours.toStringAsFixed(0)}h',
                      style: Wb.code(size: 15),
                    ),
                    Text(
                      'Week ${31 + row}',
                      style: Wb.kicker(size: 9, tracking: 0.1),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: (wkHours / (cap * 5)).clamp(0, 1),
                          backgroundColor: Wb.track,
                          color: wkHours > cap * 5 * 0.95
                              ? Wb.accent
                              : Wb.forest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      constraints: const BoxConstraints(minHeight: 104),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Wb.line2, style: BorderStyle.solid),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.ctrl,
    required this.meta,
    required this.selected,
    required this.onlyWorker,
    required this.peak,
  });
  final SchedulerController ctrl;
  final DayMeta meta;
  final bool selected;
  final int? onlyWorker;
  final double peak;

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final heavy = m.ot > 1.5;
    final mode = ctrl.monthMode;
    final hoursLabel = mode == MonthMode.crew
        ? (m.crewN > 0 ? '${m.crewN} tech' : '')
        : (m.hours > 0 ? '${m.hours.toStringAsFixed(0)}h' : '');
    final foot = mode == MonthMode.status
        ? statusLabel(m.status)
        : m.crewN == 0
        ? 'Closed'
        : onlyWorker != null
        // "1 on" about yourself is a fact you already know; what the
        // day is worth to you is the hours.
        ? '${m.hours.toStringAsFixed(1)}h on the clock'
        : '${m.crewN} on';
    final tone = mode == MonthMode.status
        ? (m.crewN > 0 ? statusColor(m.status) : Wb.line)
        : (heavy ? Wb.accent : Wb.forest);

    return HoverTap(
      onTap: m.day > 0 ? () => ctrl.pickDay(m.day) : null,
      builder: (_, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        constraints: const BoxConstraints(minHeight: 104),
        transform: hover
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: selected
              ? Wb.peach
              : m.crewN > 0
              ? Wb.cream
              : Wb.emptyDay,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hover
                ? Wb.ink
                : selected
                ? Wb.peachSel
                : heavy
                ? Wb.peachHeavy
                : Wb.line2,
          ),
          boxShadow: hover
              ? const [
                  BoxShadow(
                    color: Color(0x1A1D1C1A),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${m.day}',
                  style: Wb.display(
                    19,
                    color: selected
                        ? Wb.peachText
                        : m.crewN > 0
                        ? Wb.ink
                        : Wb.closed,
                  ),
                ),
                const Spacer(),
                Text(
                  hoursLabel,
                  style: Wb.code(
                    size: 10.5,
                    tracking: -0.01,
                    color: heavy
                        ? Wb.accent
                        : m.crewN > 0
                        ? Wb.muted2
                        : Wb.closed2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: mode == MonthMode.crew ? 20 : 14,
              child: Opacity(
                opacity: m.crewN > 0 ? 1 : 0,
                // ⚠️ **One bar has to carry its own length.** With a single
                // slot the bar fills the cell whatever the day was worth, so
                // only its colour moved — and a month of full-width bars says
                // nothing about which days were long. Widthed against this
                // person's own busiest day, the remainder left as track.
                child: onlyWorker != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: peak <= 0
                              ? 0
                              : (m.hours / peak).clamp(0.08, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: m.ot > 0
                                  ? Wb.accent
                                  : ctrl.technicians[onlyWorker!].tint
                                      .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var x = 0; x < m.perTech.length; x++)
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 2),
                                height: mode == MonthMode.crew
                                    ? (m.perTech[x] / 10 * 18).clamp(2.0, 20.0)
                                    : (m.perTech[x] / 10 * 12).clamp(2.0, 14.0),
                                decoration: BoxDecoration(
                                  color: m.perTech[x] > 8
                                      ? Wb.accent
                                      : m.perTech[x] > 0
                                          ? ctrl.technicians[x].tint.withValues(
                                              alpha: mode == MonthMode.crew
                                                  ? 0.8
                                                  : 0.4,
                                            )
                                          : Wb.hair,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: Stack(
                children: [
                  for (
                    var x = 0;
                    x < (onlyWorker == null ? m.crewN.clamp(0, 5) : 0);
                    x++
                  )
                    Positioned(
                      left: x * 14.0,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ctrl.technicians[x].tint
                              .withValues(alpha: 0.15),
                          border: Border.all(
                            color: selected ? Wb.peach : Wb.cream,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          ctrl.technicians[x].initial[0],
                          style: TextStyle(
                            fontFamily: Wb.sans,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: ctrl.technicians[x].tint,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  if (m.crewN > 5)
                    Positioned(
                      left: 5 * 14.0,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Wb.hair,
                        ),
                        child: Text(
                          '+${m.crewN - 5}',
                          style: Wb.ui(
                            size: 8,
                            weight: FontWeight.w700,
                            color: Wb.muted2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    foot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Wb.sans,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.63,
                      color: m.crewN > 0 ? Wb.muted2 : Wb.closed2,
                    ),
                  ),
                ),
                if (m.ot > 0)
                  Text(
                    '+${m.ot.toStringAsFixed(1)}',
                    style: Wb.code(size: 9, color: Wb.accent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
