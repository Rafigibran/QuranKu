import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/l10n/app_localizations.dart';
import 'package:quranku/screens/hajj_umrah_screen.dart';

/// Renders the guide at a phone size in both languages and both tabs.
///
/// The guide holds long reference lists and per-step sunnah blocks, so the
/// realistic failure is a layout overflow rather than a wrong value. The page
/// is dragged to the bottom because a ListView builds its children lazily:
/// dragging is what lays the rest of the guide out and surfaces an overflow.
void main() {
  Future<void> pumpGuide(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HajjUmrahScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags the guide to the bottom so every list and step is laid out.
  Future<void> scrollToBottom(WidgetTester tester) async {
    final guide = find.byType(Scrollable).last;
    for (var i = 0; i < 14; i++) {
      await tester.drag(guide, const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('renders the Hajj tab in Indonesian', (tester) async {
    await pumpGuide(tester, const Locale('id'));
    expect(find.text('Rukun haji'), findsOneWidget);
    await scrollToBottom(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the Hajj tab in English', (tester) async {
    await pumpGuide(tester, const Locale('en'));
    expect(find.text('Pillars of Hajj'), findsOneWidget);
    await scrollToBottom(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the Umrah tab in Indonesian', (tester) async {
    await pumpGuide(tester, const Locale('id'));
    await tester.tap(find.widgetWithText(Tab, 'Umrah'));
    await tester.pumpAndSettle();

    expect(find.text('Rukun umrah'), findsOneWidget);
    await scrollToBottom(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the Umrah tab in English', (tester) async {
    await pumpGuide(tester, const Locale('en'));
    await tester.tap(find.widgetWithText(Tab, 'Umrah'));
    await tester.pumpAndSettle();

    expect(find.text('Pillars of Umrah'), findsOneWidget);
    await scrollToBottom(tester);
    expect(tester.takeException(), isNull);
  });
}
