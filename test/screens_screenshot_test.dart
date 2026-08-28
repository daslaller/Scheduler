/// The four screens, photographed.
///
/// Every mark that matters here is a painter — a dotted edge, an hour grid, a
/// bar cluster, a now line. `find.text` cannot see one, so the harness writes
/// PNGs and asserts the claims that survive a still frame.

library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rx_scheduler/theme.dart';
import 'package:rx_scheduler/widgets/month_overlay.dart';
import 'package:rx_scheduler/scheduler.dart';

final _boundary = GlobalKey();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('1 — the admin planner', (tester) async {
    final ctrl = RxSchedulerController();
    await _pump(
      tester,
      const Size(1420, 1000),
      RxScheduler(controller: ctrl),
    );
    expect(find.text('Monday 24 August'), findsOneWidget);
    // The two open shifts, told apart: one is somebody at the counter, the
    // other is a punch nobody made.
    expect(find.textContaining('no clock-out'), findsWidgets);
    expect(find.textContaining('on shift'), findsWidgets);
    // Settled and running are named apart on the strip.
    expect(find.text('On the bench'), findsOneWidget);
    expect(find.textContaining('still running'), findsOneWidget);
    await _shoot(tester, 'screen-1-admin-planner');
  });

  testWidgets('2 — the admin month, as a modal', (tester) async {
    final ctrl = RxSchedulerController();
    await _pump(
      tester,
      const Size(1420, 1000),
      RxScheduler(controller: ctrl),
    );
    await tester.tap(find.text('Month overlay'));
    // ⚠️ Never `pumpAndSettle` on this app: the now line pulses forever, so
    // settling spins to the timeout — even for a modal that has finished
    // opening. The route's own transition is 300ms; pump past it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.textContaining('hours per technician'), findsOneWidget);
    await _shoot(tester, 'screen-2-admin-month');
  });

  testWidgets('3 — the self view', (tester) async {
    final ctrl = RxSchedulerController()..showSelf(true);
    await _pump(tester, const Size(1180, 700), RxScheduler(controller: ctrl));
    expect(find.text('MY SCHEDULE'), findsOneWidget);
    expect(find.text('Alex Kim (you)'), findsOneWidget);
    // Every day in the week holds a lane, worked or not.
    expect(find.textContaining('Mon '), findsOneWidget);
    expect(find.textContaining('Sun '), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    await _shoot(tester, 'screen-3-self-view');
  });

  testWidgets('4 — the self month is the admin month, one person wide', (
    tester,
  ) async {
    final ctrl = RxSchedulerController()..showSelf(true);
    await _pump(
      tester,
      const Size(1420, 1000),
      RxScheduler(controller: ctrl),
    );
    await tester.tap(find.text('Month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Same widget, same grid, same figures — only the rows differ.
    expect(find.byType(MonthOverlay), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.textContaining('One bar a day'), findsOneWidget);
    await _shoot(tester, 'screen-4-self-month');
  });
}

Future<void> _pump(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Wb.page,
        colorScheme: const ColorScheme.light(
          primary: Wb.primary,
          onPrimary: Wb.onPrimary,
          surface: Wb.cream,
          onSurface: Wb.ink,
        ),
        fontFamily: Wb.sans,
      ),
      // ⚠️ **The boundary wraps the Navigator, not `home`.** A dialog lives
      // in the Navigator's Overlay, *above* the home route — so a boundary
      // around `home` photographs the page behind the modal and nothing else.
      // Both month shots came out that way, and the tests still passed:
      // `find.byType(MonthOverlay)` is a query against the tree, not against
      // the picture. If a harness can be green while the image is wrong, the
      // harness is not measuring what it claims to.
      builder: (context, child) =>
          RepaintBoundary(key: _boundary, child: child!),
      home: home,
    ),
  );
  await tester.pump();
  // ⚠️ Never `pumpAndSettle` at the top level: the now line pulses forever, so
  // settling spins to the timeout. A chosen phase instead.
  await tester.pump(const Duration(milliseconds: 300));
}

const _shotDirs = ['build/shots'];

Future<void> _shoot(WidgetTester tester, String name) async {
  // `pumpAndSettle` does not rethrow a `RenderFlex` overflow — `takeException`
  // is what asks, and it is how the header's 93px overflow was caught.
  expect(tester.takeException(), isNull);
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    for (final dir in _shotDirs) {
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}

Future<void> _loadFonts() async {
  // ⚠️ **Icon fonts are not loaded in a widget test by default**, so every
  // `Icon` renders as a tofu box — which is exactly what a "missing glyph"
  // looks like, and how a real font problem and a harness problem get
  // confused. Load MaterialIcons from the SDK so a box in a shot means a box
  // in the app.
  for (final root in [
    Directory('${Platform.environment['HOME']}/flutter-sdk'),
    Directory('/opt/flutter'),
  ]) {
    final f = File(
      '${root.path}/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
      await loader.load();
      break;
    }
  }

  final dir = Directory('assets/fonts');
  if (!dir.existsSync()) return;
  final byFamily = <String, List<String>>{};
  for (final f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.ttf')) continue;
    final base = f.path.split('/').last.split('.').first;
    final family = base.split('-').first;
    byFamily.putIfAbsent(family, () => []).add(f.path);
  }
  for (final entry in byFamily.entries) {
    final loader = FontLoader(entry.key);
    for (final p in entry.value) {
      loader.addFont(
        File(p).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }
}
