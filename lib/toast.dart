import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

enum RxToastKind { info, success, warning, danger }

class RxToastMessage {
  const RxToastMessage({
    required this.title,
    this.detail,
    this.kind = RxToastKind.info,
    this.duration = const Duration(milliseconds: 3200),
  });

  final String title;
  final String? detail;
  final RxToastKind kind;
  final Duration duration;
}

/// Implemented by [RxSchedulerController]. Any object with a toast stream
/// can be passed to [RxToastHost].
abstract class RxToastSource {
  Stream<RxToastMessage> get toasts;
}

/// Overlay toasts that sit on a host overlay **above** the navigator, so they
/// still show when the scheduler, a technician sheet, or another route is in
/// the foreground.
///
/// Wrap the `MaterialApp.builder` child once at the RepairX root:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => RxToastHost(
///     controller: scheduler,
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
/// ```
class RxToastHost extends StatefulWidget {
  const RxToastHost({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;

  /// When set, toasts emitted by the controller appear automatically.
  final RxToastSource? controller;

  @override
  State<RxToastHost> createState() => _RxToastHostState();
}

class _RxToastHostState extends State<RxToastHost> {
  static final List<_RxToastHostState> _hosts = [];
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  late final OverlayEntry _rootEntry;
  StreamSubscription<RxToastMessage>? _sub;
  final List<Timer> _timers = [];

  static _RxToastHostState? get current => _hosts.isEmpty ? null : _hosts.last;

  @override
  void initState() {
    super.initState();
    _hosts.add(this);
    _rootEntry = OverlayEntry(
      maintainState: true,
      builder: (context) => Positioned.fill(child: widget.child),
    );
    _listen(widget.controller);
  }

  @override
  void didUpdateWidget(covariant RxToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _rootEntry.markNeedsBuild();
    }
    if (oldWidget.controller != widget.controller) {
      _sub?.cancel();
      _listen(widget.controller);
    }
  }

  void _listen(RxToastSource? ctrl) {
    if (ctrl == null) return;
    _sub = ctrl.toasts.listen(present);
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _hosts.remove(this);
    super.dispose();
  }

  void present(RxToastMessage message) {
    void insert() {
      final overlay = _overlayKey.currentState;
      if (overlay == null || !mounted) return;
      late OverlayEntry entry;
      late Timer timer;
      void remove() {
        timer.cancel();
        _timers.remove(timer);
        if (entry.mounted) entry.remove();
      }

      entry = OverlayEntry(
        builder: (ctx) => _ToastCard(
          message: message,
          onDismiss: remove,
        ),
      );
      overlay.insert(entry);
      timer = Timer(message.duration, remove);
      _timers.add(timer);
    }

    if (_overlayKey.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => insert());
    } else {
      insert();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: _overlayKey,
      initialEntries: [_rootEntry],
    );
  }
}

/// Fire a toast from anywhere. Requires an [RxToastHost] above in the tree.
/// Prefer [RxSchedulerController.showToast] so the same stream drives the host.
abstract final class RxToast {
  static void show(
    String title, {
    String? detail,
    RxToastKind kind = RxToastKind.info,
  }) {
    final host = _RxToastHostState.current;
    if (host == null || !host.mounted) return;
    host.present(RxToastMessage(title: title, detail: detail, kind: kind));
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, required this.onDismiss});
  final RxToastMessage message;
  final VoidCallback onDismiss;

  Color get _tone => switch (message.kind) {
        RxToastKind.info => Wb.primary,
        RxToastKind.success => Wb.forest,
        RxToastKind.warning => Wb.gold,
        RxToastKind.danger => Wb.accent,
      };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      top: media.padding.top + 16,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: onDismiss,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Wb.ink,
                  borderRadius: BorderRadius.circular(Wb.rLg),
                  boxShadow: Wb.overlayShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _tone,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.title,
                            style: Wb.ui(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Wb.onPrimary,
                            ),
                          ),
                          if (message.detail != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              message.detail!,
                              style: Wb.ui(
                                size: 12,
                                color: const Color(0xFFCBD5E1),
                                height: 1.35,
                              ),
                            ),
                          ],
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
    );
  }
}
