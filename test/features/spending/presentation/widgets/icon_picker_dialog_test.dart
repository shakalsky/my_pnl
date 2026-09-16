import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/icon_picker_dialog.dart';
import 'package:my_pnl/i18n/strings.g.dart';

import '../../../../helpers/helpers.dart';

/// Opens the picker over a bare page.
///
/// The chosen key comes back in a record rather than as the return value:
/// returned bare, Dart would flatten it into the future this helper already
/// is, and awaiting the helper would then wait for a dialog nobody has closed.
Future<({Future<String?> picked})> _open(
  WidgetTester tester, {
  String selected = 'groceries',
}) async {
  late Future<String?> picked;

  await tester.pumpApp(
    Builder(
      builder: (context) => TextButton(
        onPressed: () => picked = IconPickerDialog.show(context, selected),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return (picked: picked);
}

void main() {
  group('the category icon sets', () {
    test('offer eleven on the form and forty behind the button', () {
      expect(categoryQuickIcons, hasLength(11));
      expect(categoryMoreIcons, hasLength(40));
    });

    test('never repeat a key between them', () {
      expect(categoryIcons, hasLength(51));
    });

    test('resolve every key either set holds', () {
      for (final key in categoryIcons.keys) {
        expect(iconForKey(key), categoryIcons[key], reason: key);
      }
    });
  });

  group('IconPickerDialog', () {
    testWidgets('shows the forty behind the button, and only those', (
      tester,
    ) async {
      final opened = await _open(tester);

      for (final icon in categoryMoreIcons.values) {
        expect(find.byIcon(icon), findsOneWidget);
      }
      // The eleven on the form are still on the form behind this dialog.
      for (final icon in categoryQuickIcons.values) {
        expect(find.byIcon(icon), findsNothing);
      }

      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      await opened.picked;
    });

    testWidgets('lays the grid out five to a row', (tester) async {
      final opened = await _open(tester);

      final tops = [
        for (final icon in categoryMoreIcons.values.take(6))
          tester.getTopLeft(find.byIcon(icon)).dy,
      ];

      // The first five share a row; the sixth has dropped to the next one.
      expect(tops.take(5).toSet(), hasLength(1));
      expect(tops.last, greaterThan(tops.first));

      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      await opened.picked;
    });

    testWidgets('returns the key of the icon tapped', (tester) async {
      final opened = await _open(tester);

      // Eight rows do not fit a dialog, so this one has to be scrolled to —
      // which is the point of picking one from the far end of the grid.
      final savings = find.byIcon(categoryMoreIcons['savings']!);
      await tester.ensureVisible(savings);
      await tester.pumpAndSettle();
      await tester.tap(savings);
      await tester.pumpAndSettle();

      // Tapping both chooses and closes — there is nothing left to confirm.
      expect(await opened.picked, 'savings');
      expect(find.byType(IconPickerDialog), findsNothing);
    });

    testWidgets('returns nothing when cancelled', (tester) async {
      final opened = await _open(tester);

      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();

      expect(await opened.picked, isNull);
    });
  });
}
