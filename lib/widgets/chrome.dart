import 'package:flutter/material.dart';

import '../theme.dart';

class HoverTap extends StatefulWidget {
  const HoverTap({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hover) builder;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  @override
  State<HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<HoverTap> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? SystemMouseCursors.basic : widget.cursor,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, hover),
      ),
    );
  }
}

class WbCircleBtn extends StatelessWidget {
  const WbCircleBtn({
    super.key,
    this.glyph,
    this.icon,
    required this.onTap,
    this.size = 33,
  }) : assert(glyph != null || icon != null);

  /// A character the app's own font actually has. ⚠️ Inter has no
  /// block-elements or dingbat coverage and Flutter does not substitute, so a
  /// `✕` or a `＋` here renders as a **tofu box** — pass [icon] for anything
  /// outside plain text.
  final String? glyph;
  final IconData? icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return HoverTap(
      onTap: onTap,
      builder: (_, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hover ? Wb.wash : Wb.cream,
          border: Border.all(color: hover ? Wb.line2 : Wb.line),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: size > 32 ? 16 : 15,
                color: hover ? Wb.ink : Wb.muted3,
              )
            : Text(
                glyph!,
                style: TextStyle(
                  fontFamily: Wb.sans,
                  fontSize: size > 32 ? 14 : 13,
                  height: 1,
                  color: hover ? Wb.ink : Wb.muted3,
                ),
              ),
      ),
    );
  }
}

class WbPill extends StatelessWidget {
  const WbPill({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.peach = false,
    this.leading,
    this.height = 34,
    this.hPad = 14,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled, peach, expand;
  final Widget? leading;
  final double height, hPad;

  @override
  Widget build(BuildContext context) {
    return HoverTap(
      onTap: onTap,
      builder: (_, hover) {
        Color bg;
        Color fg;
        Color bd;
        if (filled) {
          bg = hover ? Wb.primaryDark : Wb.primary;
          fg = Wb.onPrimary;
          bd = bg;
        } else if (peach) {
          bg = hover ? Wb.peachHover : Wb.peach;
          fg = Wb.peachText;
          bd = Wb.peachBorder;
        } else {
          bg = hover ? Wb.wash : Wb.cream;
          fg = Wb.ink;
          bd = hover ? Wb.line2 : Wb.line;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Wb.rMd),
            border: Border.all(color: bd, width: filled ? 0 : 1),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: Wb.sans,
                    fontSize: 14,
                    color: fg,
                    height: 1,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: 7),
              ],
              if (expand)
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Wb.ui(
                      size: 12.5,
                      weight: filled || peach ? FontWeight.w600 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  style: Wb.ui(
                    size: 12.5,
                    weight: filled || peach ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class WbAvatar extends StatelessWidget {
  const WbAvatar({
    super.key,
    required this.initial,
    required this.tint,
    this.size = 31,
    this.radius,
  });
  final String initial;
  final Color tint;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0x1C / 255),
        border: Border.all(color: tint.withValues(alpha: 0x4D / 255)),
        borderRadius: BorderRadius.circular(radius ?? size / 2),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: Wb.sans,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: tint,
          height: 1,
        ),
      ),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Wb.wash,
        borderRadius: BorderRadius.circular(Wb.rMd),
        border: Border.all(color: Wb.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            HoverTap(
              onTap: () => onChanged(i),
              builder: (_, hover) {
                final on = i == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: on ? Wb.cream : Colors.transparent,
                    borderRadius: BorderRadius.circular(Wb.rSm),
                    boxShadow: on ? Wb.cardShadow : null,
                  ),
                  child: Text(
                    labels[i],
                    style: Wb.ui(
                      size: 13,
                      weight: on ? FontWeight.w600 : FontWeight.w500,
                      color: on ? Wb.ink : Wb.tabOff,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Wb.ui(size: 11.5, color: Wb.muted3)),
      ],
    );
  }
}

class StepperChip extends StatelessWidget {
  const StepperChip({
    super.key,
    required this.onMinus,
    required this.onPlus,
    required this.label,
    this.danger = false,
  });
  final VoidCallback onMinus, onPlus;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sq(onMinus, '–'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            label,
            style: Wb.code(size: 13, color: danger ? Wb.accent : Wb.ink),
          ),
        ),
        // `＋` (fullwidth) is tofu in Inter; the ASCII one is not.
        _sq(onPlus, '+'),
      ],
    );
  }

  Widget _sq(VoidCallback onTap, String g) {
    return HoverTap(
      onTap: onTap,
      builder: (_, hover) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hover ? Wb.cream2 : Wb.cream,
          borderRadius: BorderRadius.circular(Wb.rSm),
          border: Border.all(color: hover ? Wb.line2 : Wb.line),
        ),
        child: Text(
          g,
          style: const TextStyle(
            fontFamily: Wb.sans,
            fontSize: 14,
            height: 1,
            color: Wb.muted3,
          ),
        ),
      ),
    );
  }
}
