import 'package:flutter/material.dart';

import '../controller.dart';
import '../models.dart';
import '../theme.dart';
import 'chrome.dart';

class BenchTimeline extends StatelessWidget {
  const BenchTimeline({super.key, required this.ctrl});
  final SchedulerController ctrl;

  @override
  Widget build(BuildContext context) {
    final isClock = ctrl.view == TimelineView.clock;
    // Derived from what is on the board, not hardcoded — see [DayWindow].
    final window = ctrl.window;
    return Container(
      decoration: BoxDecoration(
        color: Wb.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Wb.line),
        boxShadow: Wb.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Toolbar(ctrl: ctrl, isClock: isClock),
          _Ruler(window: window),
          _Rows(ctrl: ctrl, isClock: isClock, window: window),
          _Coverage(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.ctrl, required this.isClock});
  final SchedulerController ctrl;
  final bool isClock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: Wb.cream2,
        border: Border(bottom: BorderSide(color: Wb.line2)),
      ),
      child: Row(
        children: [
          SegmentedTabs(
            labels: const ['Clocked time', 'Repairs'],
            index: isClock ? 0 : 1,
            onChanged: (i) => ctrl.setView(
              i == 0 ? TimelineView.clock : TimelineView.repairs,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isClock
                  ? 'Drag either end of a shift, or use − / ＋ to take off or add 30 minutes'
                  : 'Appointed repair work · drag to reassign · shaded band is the technician’s clocked shift',
              style: Wb.ui(size: 11.5, color: Wb.muted2, height: 1.35),
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 13,
            runSpacing: 6,
            children: [
              if (isClock) ...[
                const LegendDot(color: Wb.shiftHandle, label: 'On the clock'),
                const LegendDot(color: Wb.accent, label: 'Over 8h'),
              ] else
                for (final k in JobKind.values)
                  LegendDot(color: toneOf(k).rail, label: toneOf(k).label),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.window});
  final DayWindow window;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Wb.pad, 10, Wb.pad, 0),
      child: Row(
        children: [
          const SizedBox(width: Wb.headWidth),
          Expanded(
            child: SizedBox(
              height: 22,
              child: LayoutBuilder(
                builder: (context, box) {
                  final hours = <int>[];
                  for (
                    var h = window.start.ceil();
                    h < window.end.floor();
                    h++
                  ) {
                    hours.add(h);
                  }
                  return Stack(
                    children: [
                      for (var k = 0; k < hours.length; k++)
                        Positioned(
                          left:
                              window.pctOf(hours[k].toDouble()) * box.maxWidth,
                          top: 0,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              border: Border(left: BorderSide(color: Wb.line2)),
                            ),
                            child: k.isEven
                                ? Text(
                                    formatHour(hours[k].toDouble()),
                                    style: Wb.code(
                                      size: 10,
                                      weight: FontWeight.w500,
                                      color: Wb.muted,
                                      tracking: 0.06,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({
    required this.ctrl,
    required this.isClock,
    required this.window,
  });
  final SchedulerController ctrl;
  final bool isClock;
  final DayWindow window;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Wb.pad, 0, Wb.pad, 12),
      child: LayoutBuilder(
        builder: (context, box) {
          final trackW = box.maxWidth - Wb.headWidth;
          return Stack(
            children: [
              Column(
                children: [
                  for (var i = 0; i < ctrl.technicians.length; i++)
                    _TechRow(
                      ctrl: ctrl,
                      index: i,
                      isClock: isClock,
                      trackWidth: trackW,
                      window: window,
                    ),
                ],
              ),
              // Both: main's live clock, and the derived window it is placed
              // against.
              _NowLine(window: window, nowHour: ctrl.nowHour),
            ],
          );
        },
      ),
    );
  }
}

class _NowLine extends StatefulWidget {
  const _NowLine({required this.window, required this.nowHour});
  final DayWindow window;
  final double nowHour;
  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          // ⚠️ Placed against the **derived** window, not the hardcoded day:
          // `hourToPct` divides by the fixed 07:30–19:00 span, so on a board
          // whose axis was derived the line lands somewhere else entirely.
          final x = Wb.headWidth +
              widget.window.pctOf(widget.nowHour) *
                  (box.maxWidth - Wb.headWidth);
          return IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: x,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Wb.primary, Color(0x1F2563EB)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x - 23,
                  top: -11,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Wb.primary,
                      borderRadius: BorderRadius.circular(Wb.rXs),
                    ),
                    child: Text(
                      formatHour(widget.nowHour),
                      style: Wb.code(
                        size: 9,
                        color: Wb.onPrimary,
                        tracking: 0.03,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: x - 3.5,
                  top: 0,
                  child: FadeTransition(
                    opacity: Tween(begin: 1.0, end: 0.35).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Wb.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TechRow extends StatelessWidget {
  const _TechRow({
    required this.ctrl,
    required this.index,
    required this.isClock,
    required this.trackWidth,
    required this.window,
  });
  final SchedulerController ctrl;
  final int index;
  final bool isClock;
  final double trackWidth;
  final DayWindow window;

  @override
  Widget build(BuildContext context) {
    final w = ctrl.technicians[index];
    final clock = ctrl.clockOf(index);
    final jobs = ctrl.jobsOf(index);
    final appointed = jobs.fold<double>(0, (a, j) => a + j.duration);
    final overflow = jobs.fold<double>(
      0,
      (a, j) => a + (j.end > clock.outHour ? j.end - clock.outHour : 0),
    );

    return SizedBox(
      height: Wb.rowH,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Wb.hair)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HoverTap(
              onTap: () => ctrl.openSheet(index),
              builder: (_, hover) => AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: Wb.headWidth,
                padding: const EdgeInsets.fromLTRB(4, 9, 14, 9),
                color: hover ? Wb.cream2 : Colors.transparent,
                child: Row(
                  children: [
                    WbAvatar(initial: w.initial, tint: w.tint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            w.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Wb.ui(
                              size: 13,
                              weight: FontWeight.w600,
                              tracking: -0.065,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            w.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Wb.kicker(size: 9.5, tracking: 0.09),
                          ),
                        ],
                      ),
                    ),
                    // Read-only over a real log — see `nudge`. A stepper that
                    // refuses is worse than none: it is the same dead control,
                    // still inviting the tap.
                    if (isClock && ctrl.hasHistory)
                      ReadOnlyChip(
                        label: '${clock.paid.toStringAsFixed(1)}h',
                        danger: clock.forgotten,
                      )
                    else if (isClock)
                      StepperChip(
                        onMinus: () =>
                            ctrl.nudge(index, inSide: false, delta: -0.5),
                        onPlus: () =>
                            ctrl.nudge(index, inSide: false, delta: 0.5),
                        label: '${clock.paid.toStringAsFixed(1)}h',
                        danger: clock.overtime,
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${jobs.length} ${jobs.length == 1 ? 'repair' : 'repairs'} · ${appointed.toStringAsFixed(1)}h',
                            style: Wb.code(
                              size: 12,
                              color: Wb.body,
                              tracking: -0.01,
                            ),
                          ),
                          if (overflow > 0)
                            Text(
                              '+${overflow.toStringAsFixed(1)}h past clock-out',
                              style: Wb.code(size: 10, color: Wb.accent),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: trackWidth,
              height: Wb.rowH,
              child: CustomPaint(
                painter: _HourGridPainter(window: window),
                child: isClock
                    ? _ShiftTrack(
                        ctrl: ctrl,
                        index: index,
                        clock: clock,
                        width: trackWidth,
                        window: window,
                      )
                    : _JobTrack(
                        ctrl: ctrl,
                        index: index,
                        clock: clock,
                        jobs: jobs,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourGridPainter extends CustomPainter {
  const _HourGridPainter({required this.window});
  final DayWindow window;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Wb.hair
      ..strokeWidth = 1;
    for (var h = window.start.ceil(); h <= window.end.floor(); h++) {
      // Snapped: an hour line at a fractional x is drawn at half weight
      // across two columns, which reads as blur. See `crispLine`.
      final x = crispLine(window.pctOf(h.toDouble()) * size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_HourGridPainter old) => old.window.start != window.start;
}

class _ShiftTrack extends StatelessWidget {
  const _ShiftTrack({
    required this.ctrl,
    required this.index,
    required this.clock,
    required this.width,
    required this.window,
  });
  final SchedulerController ctrl;
  final int index;
  final ClockHours clock;
  final double width;
  final DayWindow window;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Clamped: a shift that began before the drawn day — the shape a
    // forgotten overnight punch takes — starts off the left edge, and the
    // card clips it there rather than letting it lay out negative.
    final left = window.pctOf(clock.inHour).clamp(0.0, 1.0);
    final w = (window.pctOf(clock.outHour).clamp(0.0, 1.0) - left).clamp(
      0.0,
      1.0,
    );
    final over = clock.overtime;
    return Stack(
      children: [
        Positioned(
          left: left * width,
          width: w * width,
          top: 9,
          bottom: 9,
          child: _ShiftBar(
            readOnly: ctrl.hasHistory,
            clock: clock,
            overtime: over,
            onDragIn: (d) => ctrl.nudge(index, inSide: true, delta: d),
            onDragOut: (d) => ctrl.nudge(index, inSide: false, delta: d),
            onTap: () => ctrl.openSheet(index),
          ),
        ),
      ],
    );
  }
}

class _ShiftBar extends StatefulWidget {
  const _ShiftBar({
    required this.clock,
    required this.overtime,
    required this.readOnly,
    required this.onDragIn,
    required this.onDragOut,
    required this.onTap,
  });
  final ClockHours clock;
  final bool overtime;

  /// The host supplied a real punch log, so the bar **states** hours rather
  /// than editing them — see `SchedulerController.nudge`.
  final bool readOnly;
  final ValueChanged<double> onDragIn, onDragOut;
  final VoidCallback onTap;

  @override
  State<_ShiftBar> createState() => _ShiftBarState();
}

class _ShiftBarState extends State<_ShiftBar> {
  bool hover = false;
  double _accIn = 0;
  double _accOut = 0;

  void _apply(bool inSide, double dx, double barWidth) {
    final hours = dx / barWidth * widget.clock.paid;
    if (inSide) {
      _accIn += hours;
      while (_accIn.abs() >= 0.5) {
        final step = _accIn > 0 ? 0.5 : -0.5;
        _accIn -= step;
        widget.onDragIn(step);
      }
    } else {
      _accOut += hours;
      while (_accOut.abs() >= 0.5) {
        final step = _accOut > 0 ? 0.5 : -0.5;
        _accOut -= step;
        widget.onDragOut(step);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final over = widget.overtime;
    final clock = widget.clock;
    // ⚠️ **Three states, three marks — not three tints of one.**
    //
    //   settled  → solid, the shop's own colour
    //   live     → solid, and it *shines*: something is happening in it
    //   forgotten→ dotted, ending in nothing: committed, not yet real
    //
    // Hue cannot carry this on its own. A green bar and an amber bar are the
    // same object seen twice; a dotted edge is the same mark in any palette,
    // and it is the only one that survives a bar running the full width where
    // its torn end is clipped to the frame.
    final live = clock.live;
    final forgotten = clock.forgotten;
    final fg = forgotten ? Wb.accentDark : Wb.shiftFg;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: forgotten
                ? Wb.accentSoft
                : over
                ? Wb.accentSoft
                : Wb.shiftBg,
            borderRadius: BorderRadius.circular(9),
            border: forgotten
                // Dotted: nobody has said where this ends.
                ? null
                : Border.all(color: over ? Wb.accentBorder : Wb.shiftBd),
            boxShadow: hover
                ? const [
                    BoxShadow(
                      color: Color(0x1F1D1C1A),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          foregroundDecoration: forgotten
              ? const _DottedEdge(dotColor: Wb.accentHandle)
              : null,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forgotten
                          ? (clock.entersDay
                                ? 'from yesterday → no clock-out'
                                : '${formatHour(clock.inHour)} → no clock-out')
                          : live
                          ? '${formatHour(clock.inHour)} → on shift'
                          : '${formatHour(clock.inHour)} – ${formatHour(clock.outHour)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Wb.code(
                        size: 12,
                        color: over ? Wb.accentDark : fg,
                        tracking: -0.01,
                      ),
                    ),
                    Text(
                      // ⚠️ An open run's hours are **elapsed**, never
                      // "worked": from the punch stream a running shift and a
                      // forgotten one are the same event, and only a person
                      // can tell them apart.
                      '${clock.paid.toStringAsFixed(1)}h '
                      '${clock.open ? 'elapsed' : 'on the clock'}'
                      '${clock.hasBreak ? ' · ${(clock.breakHours * 60).round()}m break' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Wb.ui(
                        size: 9.5,
                        weight: FontWeight.w500,
                        color: (over ? Wb.accentDark : fg).withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // The spine stays — it marks where the shift starts. What goes
              // over a real log is its ability to drag; see `nudge`.
              _Handle(
                left: true,
                color: over ? Wb.accentHandle : Wb.shiftHandle,
                onDrag: widget.readOnly ? null : (dx, w) => _apply(true, dx, w),
              ),
              // ⚠️ **No trailing handle on an open shift.** Dragging it would
              // invent the missing clock-out — a fact about somebody's pay
              // that nobody stated. Closing one is its own deliberate act.
              if (!clock.open)
                _Handle(
                  left: false,
                  color: over ? Wb.accentHandle : Wb.shiftHandle,
                  onDrag:
                      widget.readOnly ? null : (dx, w) => _apply(false, dx, w),
                ),
              if (clock.hasBreak) _BreakMarks(
                  clock: clock,
                  // The hash follows the bar it is drawn on — the scheduler's
                  // own rule, and the reason it is a parameter at all.
                  tone: over ? Wb.accentHandle : Wb.breakHash,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.left,
    required this.color,
    required this.onDrag,
  });
  final bool left;
  final Color color;

  /// Null over a real punch log: the spine still marks where the shift starts,
  /// but it is not a grip — there is nothing here a drag could legitimately
  /// change. It stops taking the resize cursor and the pointer with it.
  final void Function(double dx, double width)? onDrag;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: 14,
      child: MouseRegion(
        cursor: onDrag == null
            ? MouseCursor.defer
            : SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: onDrag == null
              ? HitTestBehavior.translucent
              : HitTestBehavior.opaque,
          onHorizontalDragUpdate: onDrag == null
              ? null
              : (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  final w = box?.parent is RenderBox
                      ? (box!.parent as RenderBox).size.width
                      : 120.0;
                  onDrag!(d.delta.dx, w);
                },
          child: Align(
            alignment: left ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The break, hatched across the **full height** of the bar.
///
/// ⚠️ It was two 10px notches at the bar's top and bottom edges, in a tone a
/// shade off the fill — so at a glance a shift with a break was
/// indistinguishable from one without, and the subline was the only thing that
/// said so. A break is a stretch of the shift that does not count, so it is
/// marked across the whole stretch.
///
/// Hatched rather than knocked through: a hole in a 300px bar reads as *two
/// shifts*, and this is one. Rules at 45°, 6px apart — at 4px they moiré
/// against the hour grid showing through behind them.
class _BreakMarks extends StatelessWidget {
  const _BreakMarks({required this.clock, required this.tone});
  final ClockHours clock;

  /// The hash colour — `Wb.breakHash`, solid. ⚠️ Not the bar's foreground at
  /// 40%: a thin dark rule at low alpha is a shade of the fill, and a field of
  /// them is a shaded patch. A hash is its own light line drawn *on* the fill.
  final Color tone;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: CustomPaint(painter: _HashPainter(clock, tone)),
    ),
  );
}

class _HashPainter extends CustomPainter {
  _HashPainter(this.clock, this.tone);
  final ClockHours clock;
  final Color tone;

  /// ⚠️ **The break is a SHEARED box, not a rectangle** — its left and right
  /// edges run parallel to the rules themselves, so every stripe gets its own
  /// start and end.
  ///
  /// Clipped to a plain `Rect` — which is what this was — every rule is
  /// guillotined on the same vertical column, and a hard vertical edge across
  /// a field of diagonals reads as *a box with texture in it* rather than as
  /// hatching. That single edge is the whole difference between the mark the
  /// owner approved and the one that shipped; the rules were identical.
  ///
  /// ⚠️ **Sheared about its middle, keeping the break's full width at every
  /// height.** Anchoring the corners instead — the break's start at the
  /// bottom-left, its end at the top-right — costs one bar-height of width,
  /// and a 30-minute break on a 34px bar is only 42px wide to begin with: it
  /// collapsed to a single rule. Centred, the mark is always exactly as wide
  /// as the break, and only its ends are slanted.
  @override
  void paint(Canvas canvas, Size size) {
    final (at, width) = clock.breakBand;
    if (width <= 0) return;
    final h = size.height;
    final x0 = at * size.width;
    final x1 = x0 + width * size.width;
    final lean = h / 2;

    canvas.save();
    canvas.clipPath(
      Path()
        ..moveTo(x0 - lean, h)
        ..lineTo(x0 + lean, 0)
        ..lineTo(x1 + lean, 0)
        ..lineTo(x1 - lean, h)
        ..close(),
    );
    // The approved painter's own numbers: a solid light rule, not a thin dark
    // one at 40% — translucent and a pixel closer together they fuse into a
    // shaded slab instead of reading as separate strokes.
    final p = Paint()
      ..color = tone
      ..strokeWidth = 1.4;
    for (var x = x0 - h - lean; x < x1 + lean; x += 7) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HashPainter old) =>
      old.tone != tone ||
      old.clock.breakAt != clock.breakAt ||
      old.clock.breakHours != clock.breakHours;
}

class _JobTrack extends StatelessWidget {
  const _JobTrack({
    required this.ctrl,
    required this.index,
    required this.clock,
    required this.jobs,
  });
  final SchedulerController ctrl;
  final int index;
  final ClockHours clock;
  final List<RepairJob> jobs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        return Stack(
          children: [
            Positioned(
              left: hourToPct(clock.inHour) * box.maxWidth,
              width: (clock.paid / kDaySpan) * box.maxWidth,
              top: 5,
              bottom: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: Wb.wash,
                  borderRadius: BorderRadius.circular(Wb.rLg),
                  border: Border.all(color: Wb.line),
                ),
              ),
            ),
            for (final j in jobs)
              Positioned(
                left: hourToPct(j.start) * box.maxWidth,
                width: (j.duration / kDaySpan) * box.maxWidth,
                top: 5,
                bottom: 5,
                child: _JobChip(
                  job: j,
                  past: j.end > clock.outHour + 0.01,
                  onTap: () => ctrl.openSheet(index, tab: SheetTab.work),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JobChip extends StatefulWidget {
  const _JobChip({required this.job, required this.past, required this.onTap});
  final RepairJob job;
  final bool past;
  final VoidCallback onTap;

  @override
  State<_JobChip> createState() => _JobChipState();
}

class _JobChipState extends State<_JobChip> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final t = toneOf(widget.job.kind);
    final past = widget.past;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: hover
              ? Matrix4.translationValues(0, -1, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: past ? Wb.accentSoft : t.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: past ? Wb.accentBorder2 : t.bd),
            boxShadow: hover
                ? const [
                    BoxShadow(
                      color: Color(0x211D1C1A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(color: past ? Wb.accent : t.rail),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 7, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Wb.ui(
                        size: 12,
                        weight: FontWeight.w600,
                        tracking: -0.06,
                        color: past ? Wb.accentDark : t.fg,
                      ),
                    ),
                    Text(
                      '${formatHour(widget.job.start)}–${formatHour(widget.job.end)} · ${widget.job.duration.toStringAsFixed(1)}h · \$${widget.job.rate.toStringAsFixed(0)}/h',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Wb.code(
                        size: 9.5,
                        weight: FontWeight.w500,
                        color: (past ? Wb.accentDark : t.fg).withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Coverage extends StatelessWidget {
  const _Coverage({required this.ctrl});
  final SchedulerController ctrl;

  @override
  Widget build(BuildContext context) {
    final busy = ctrl.coverageBusy();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
      decoration: const BoxDecoration(
        color: Wb.cream2,
        border: Border(top: BorderSide(color: Wb.line2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: Wb.headWidth,
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BENCH COVERAGE',
                    style: TextStyle(
                      fontFamily: Wb.sans,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: Wb.muted,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dashed line = 4 technicians minimum for the walk-in SLA',
                    style: TextStyle(
                      fontFamily: Wb.sans,
                      fontSize: 11.5,
                      color: Wb.muted2,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 58,
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32,
                    child: DashedLine(color: Wb.dashed),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final n in busy)
                        Expanded(
                          // ⚠️ **A gap, or the bars are one shape.** Butted
                          // together at `Expanded` width the rounded tops meet
                          // and the strip reads as a single skyline, so
                          // half-hours stop being countable — which is the
                          // whole question it is asked.
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: (n / ctrl.technicians.length * 32)
                                    .clamp(n == 0 ? 0 : 4, 58),
                                decoration: BoxDecoration(
                                  color: n < 4
                                      ? Wb.coverageRed
                                      : Wb.coverageGreen,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                    bottom: Radius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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

class DashedLine extends StatelessWidget {
  const DashedLine({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(color),
      size: const Size(double.infinity, 1),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dash).clamp(0, size.width), 0),
        p,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A dotted border, for a run whose end nobody has stated.
class _DottedEdge extends BoxDecoration {
  const _DottedEdge({required this.dotColor}) : super();

  final Color dotColor;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedEdgePainter(dotColor);
}

class _DottedEdgePainter extends BoxPainter {
  _DottedEdgePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size;
    if (size == null) return;
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(9),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 7;
      }
    }
  }
}
