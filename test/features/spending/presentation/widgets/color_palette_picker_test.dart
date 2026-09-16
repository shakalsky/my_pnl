import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/presentation/widgets/color_palette_picker.dart';
import 'package:my_pnl/i18n/strings.g.dart';

import '../../../../helpers/helpers.dart';

/// A mid green, away from every edge of the gradient so a pick anywhere lands
/// somewhere different.
const _opening = Color(0xFF3B7A57);

const _field = ValueKey<String>('saturation-value-field');
const _track = ValueKey<String>('hue-track');

/// Opens the picker over a bare page.
///
/// The chosen colour comes back in a record rather than as the return value:
/// returned bare, Dart would flatten it into the future this helper already
/// is, and awaiting the helper would then wait for a dialog nobody has closed.
Future<({Future<int?> picked})> _open(WidgetTester tester) async {
  late Future<int?> picked;

  await tester.pumpApp(
    Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            picked = ColorPalettePicker.show(context, _opening.toARGB32()),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return (picked: picked);
}

/// Takes the picker's answer apart again, so a test can say what it expects in
/// the terms the picker works in.
Future<HSVColor> _chosen(Future<int?> picked) async =>
    HSVColor.fromColor(Color((await picked)!));

void main() {
  group('ColorPalettePicker', () {
    testWidgets('opens on the colour it was given', (tester) async {
      final opened = await _open(tester);

      expect(find.text('#3B7A57'), findsOneWidget);

      // Left open otherwise, and the pending future outlives the test.
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      await opened.picked;
    });

    testWidgets('returns nothing when cancelled', (tester) async {
      final opened = await _open(tester);

      // Even after a pick: cancel means the form keeps the colour it had.
      await tester.tapAt(tester.getCenter(find.byKey(_field)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();

      expect(await opened.picked, isNull);
    });

    testWidgets('picks saturation and value off the gradient', (tester) async {
      final opened = await _open(tester);

      // The middle of the field is half saturation, half value.
      await tester.tapAt(tester.getCenter(find.byKey(_field)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.select));
      await tester.pumpAndSettle();

      final chosen = await _chosen(opened.picked);
      expect(chosen.saturation, closeTo(0.5, 0.02));
      expect(chosen.value, closeTo(0.5, 0.02));
      // The hue is the track's to set, and nothing touched it.
      expect(chosen.hue, closeTo(HSVColor.fromColor(_opening).hue, 1));
    });

    testWidgets('picks the hue off the track', (tester) async {
      final opened = await _open(tester);
      final opening = HSVColor.fromColor(_opening);

      // A quarter along the track is 90 degrees, well away from the green it
      // opened on.
      final track = tester.getRect(find.byKey(_track));
      await tester.tapAt(
        Offset(track.left + track.width / 4, track.center.dy),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.select));
      await tester.pumpAndSettle();

      final chosen = await _chosen(opened.picked);
      expect(chosen.hue, closeTo(90, 1));
      // Saturation and value survive the hue change, which is the point of
      // holding the colour as HSV rather than as a packed int.
      expect(chosen.saturation, closeTo(opening.saturation, 0.02));
      expect(chosen.value, closeTo(opening.value, 0.02));
    });
  });
}
