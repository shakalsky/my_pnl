import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_list_sheet.dart';
import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/presentation/pages/settings_page.dart';
import 'package:my_pnl/features/spending/presentation/widgets/overrun_settings_sheet.dart';
import 'package:my_pnl/i18n/strings.g.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('SettingsPage', () {
    late FakeThemeModeStore themes;
    late FakeLanguageStore languages;
    late FakeCurrencyRepository currencies;

    setUp(() {
      themes = FakeThemeModeStore();
      languages = FakeLanguageStore();
      currencies = FakeCurrencyRepository();
    });

    tearDown(() async {
      await themes.close();
      await currencies.close();
      // The locale is one value for the whole process, and tapping a language
      // here really does move it.
      await LocaleSettings.setLocale(AppLocale.en);
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpApp(
        const SettingsPage(),
        themeModeStore: themes,
        languageStore: languages,
        // What the two spending rows open onto. Provided at the root of the
        // app, so the page finds it there rather than making one of its own.
        currencyRepository: currencies,
      );
      await tester.pumpAndSettle();
    }

    /// The tile carrying [label] within one of the two groups.
    ///
    /// Scoped rather than found by its text alone: both groups offer a "match
    /// the device" option and both are worded the same way, which is the point
    /// — the section header above each says which device setting is meant.
    Finder tileIn(Finder group, String label) => find.descendant(
      of: group,
      matching: find.ancestor(
        of: find.text(label),
        matching: find.byType(ListTile),
      ),
    );

    final appearanceGroup = find.byType(RadioGroup<AppThemeMode>);
    final languageGroup = find.byType(RadioGroup<String?>);

    testWidgets('offers both settings', (tester) async {
      await pumpPage(tester);

      expect(find.text(t.settings.appearance), findsOneWidget);
      expect(find.text(t.settings.language), findsOneWidget);
      // Three appearances and three language options — the two languages this
      // build ships, plus following the device.
      expect(find.byType(RadioListTile<AppThemeMode>), findsNWidgets(3));
      expect(find.byType(RadioListTile<String?>), findsNWidgets(3));
    });

    testWidgets('opens the currencies sheet from its own row', (tester) async {
      await pumpPage(tester);
      await tester.scrollUntilVisible(find.text(t.spending.currencies), 100);
      await tester.ensureVisible(find.text(t.spending.currencies));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.spending.currencies));
      await tester.pumpAndSettle();

      expect(find.byType(CurrencyListSheet), findsOneWidget);
    });

    testWidgets('opens the unusual-months sheet from its own row', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.scrollUntilVisible(find.text(t.spending.unusualMonths), 100);
      await tester.ensureVisible(find.text(t.spending.unusualMonths));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.spending.unusualMonths));
      await tester.pumpAndSettle();

      expect(find.byType(OverrunSettingsSheet), findsOneWidget);
    });

    testWidgets('opens on the appearance in force', (tester) async {
      themes = FakeThemeModeStore(initial: AppThemeMode.dark);

      await pumpPage(tester);

      final group = tester.widget<RadioGroup<AppThemeMode>>(
        find.byType(RadioGroup<AppThemeMode>),
      );

      expect(group.groupValue, AppThemeMode.dark);
    });

    testWidgets('remembers an appearance the moment it is chosen', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(tileIn(appearanceGroup, t.settings.themeDark));
      await tester.pumpAndSettle();

      // No Save on this page: the write is the tap.
      expect(themes.writes, [AppThemeMode.dark]);
    });

    testWidgets('reads the app in a chosen language, and remembers it', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(tileIn(languageGroup, 'Русский'));
      await tester.pumpAndSettle();

      expect(languages.writes, ['ru']);
      expect(LocaleSettings.currentLocale, AppLocale.ru);
      // And the page it was chosen on is in Russian too, without a restart.
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('hands the language back to the device', (tester) async {
      languages = FakeLanguageStore(remembered: 'ru');

      await pumpPage(tester);
      await tester.tap(tileIn(languageGroup, t.settings.languageSystem));
      await tester.pumpAndSettle();

      // Written as an absence, which is what a later read has to see to know
      // nobody has chosen.
      expect(languages.writes, [null]);
    });

    testWidgets('names each language in its own words', (tester) async {
      await pumpPage(tester);

      // The point being that a reader stuck in a language they cannot read can
      // still find their own.
      expect(tileIn(languageGroup, 'Русский'), findsOneWidget);
      // Twice over for English: once as the option, and once as the subtitle
      // saying which language following this device currently lands on — which
      // in a test is English.
      expect(find.text('English'), findsNWidgets(2));
    });
  });
}
