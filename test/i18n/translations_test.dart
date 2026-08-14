import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/debts/presentation/pages/debts_page.dart';
import 'package:my_pnl/i18n/strings.g.dart';

import '../helpers/helpers.dart';

/// The plural categories, which are the one place the two files are meant to
/// disagree: Russian needs `few` and `many` where English has only `other`.
const _pluralCategories = {'zero', 'one', 'two', 'few', 'many', 'other'};

/// Every string this file offers, as dotted paths.
///
/// A plural counts as one path rather than one per category, so the two files
/// can be compared as sets. Compared at all because `fallback_strategy` is
/// `base_locale`: a key missing from a translation quietly falls back to
/// English, and nothing else in the build would report it.
Set<String> _keys(Map<String, dynamic> json, [String prefix = '']) {
  final keys = <String>{};

  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    switch (value) {
      case final Map<String, dynamic> child
          when !child.keys.every(_pluralCategories.contains):
        keys.addAll(_keys(child, path));
      case _:
        keys.add(path);
    }
  });

  return keys;
}

Set<String> _keysOf(String path) =>
    _keys(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);

void main() {
  group('translations', () {
    test('Russian covers every English key, and adds none of its own', () {
      final en = _keysOf('lib/i18n/en.i18n.json');
      final ru = _keysOf('lib/i18n/ru.i18n.json');

      expect(en.difference(ru), isEmpty, reason: 'untranslated');
      expect(ru.difference(en), isEmpty, reason: 'no longer used');
    });

    test('Russian picks the plural form the count calls for', () async {
      // The one thing English cannot check: `one/few/many` where English has
      // only `one/other`, so a resolver wired up wrongly still reads fine in
      // the base locale.
      final ru = await AppLocale.ru.build();

      expect(ru.goal.years(n: 1), '1 год');
      expect(ru.goal.years(n: 3), '3 года');
      expect(ru.goal.years(n: 7), '7 лет');
    });
  });

  group('a page in Russian', () {
    setUp(() => LocaleSettings.setLocale(AppLocale.ru));
    tearDown(() => LocaleSettings.setLocale(AppLocale.en));

    testWidgets('reads in Russian throughout', (tester) async {
      final debts = FakeDebtRepository();
      addTearDown(debts.close);

      await tester.pumpApp(const DebtsPage(), debtRepository: debts);
      await tester.pumpAndSettle();

      expect(find.text('Долги'), findsOneWidget);
      expect(find.text('Вам должны'), findsWidgets);
      expect(find.text('Долгов пока нет'), findsOneWidget);
      // The English wording is gone rather than merely joined.
      expect(find.text('Debts'), findsNothing);
    });
  });
}
