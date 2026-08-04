import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';

/// A usual month of 100.00, over enough months to be worth comparing against.
const _usual = SpendBaseline(averageScaled: 10000, months: 4);

const OverrunSettings _defaults = OverrunSettings.defaults;

void main() {
  group('OverrunSettings', () {
    test('warns out of the box', () {
      // A feature nobody knows is there is one nobody turns on, and the flags
      // are the point of recording the months at all.
      expect(_defaults.enabled, isTrue);
    });

    group('which level a month falls on', () {
      test('leaves a month within the usual unflagged', () {
        expect(_defaults.overrunFor(-11000, against: _usual), SpendOverrun.none);
      });

      test('flags a month a quarter over as mild', () {
        expect(_defaults.overrunFor(-12500, against: _usual), SpendOverrun.mild);
      });

      test('flags a month half again over as high', () {
        expect(_defaults.overrunFor(-15000, against: _usual), SpendOverrun.high);
      });

      test('flags twice the usual month as severe', () {
        expect(
          _defaults.overrunFor(-20000, against: _usual),
          SpendOverrun.severe,
        );
      });

      test('stays on the step it reached as the figure climbs', () {
        expect(
          _defaults.overrunFor(-99999999, against: _usual),
          SpendOverrun.severe,
        );
      });

      test('leaves a month with nothing booked unflagged', () {
        expect(_defaults.overrunFor(0, against: _usual), SpendOverrun.none);
      });

      test('says nothing with no usual month on record', () {
        // A category used for the first time is not overspending.
        expect(_defaults.overrunFor(-999999), SpendOverrun.none);
      });
    });

    group('the reader’s own thresholds', () {
      test('flags at the percentage they chose', () {
        const strict = OverrunSettings(
          mildPercent: 105,
          highPercent: 110,
          severePercent: 115,
        );

        // A tenth over is nothing by default and "well over" here.
        expect(strict.overrunFor(-11000, against: _usual), SpendOverrun.high);
        expect(_defaults.overrunFor(-11000, against: _usual), SpendOverrun.none);
      });

      test('flags nothing at all with the warnings turned off', () {
        const off = OverrunSettings(enabled: false);

        expect(off.overrunFor(-99999999, against: _usual), SpendOverrun.none);
        expect(off.levelFor(500), SpendOverrun.none);
      });

      test('reports the severest level a figure reaches, not the first', () {
        // Out of order on purpose: mild set above severe leaves the levels
        // between unreachable, which must not become "reports mild for 300%".
        const muddled = OverrunSettings(
          mildPercent: 250,
          highPercent: 160,
          severePercent: 210,
        );

        expect(muddled.levelFor(300), SpendOverrun.severe);
      });
    });

    group('keeping the figures usable', () {
      test('refuses a threshold at or below the usual month', () {
        // At 100% a month landing on its average to the cent would be flagged,
        // which is half of every grid every month.
        const tooTight = OverrunSettings(mildPercent: 1);

        expect(tooTight.normalized.mildPercent, OverrunSettings.minPercent);
      });

      test('caps a threshold nobody could reach', () {
        const tooLoose = OverrunSettings(severePercent: 100000);

        expect(tooLoose.normalized.severePercent, OverrunSettings.maxPercent);
      });

      test('puts the levels in order', () {
        const muddled = OverrunSettings(
          mildPercent: 200,
          highPercent: 160,
          severePercent: 120,
        );
        final ordered = muddled.normalized;

        // Each level starts no lower than the one below it, so no colour is
        // left unreachable.
        expect(ordered.mildPercent, 200);
        expect(ordered.highPercent, 200);
        expect(ordered.severePercent, 200);
      });

      test('leaves a sane set of thresholds alone', () {
        expect(_defaults.normalized, _defaults);
      });
    });

    group('editing one level', () {
      test('moves the level it was given', () {
        final moved = _defaults.withLevel(SpendOverrun.high, 175);

        expect(moved.highPercent, 175);
        expect(moved.percentFor(SpendOverrun.high), 175);
        expect(moved.mildPercent, _defaults.mildPercent);
      });

      test('pushes the looser levels along rather than crossing them', () {
        // Mild dragged past both of the others.
        final pushed = _defaults.withLevel(SpendOverrun.mild, 250);

        expect(pushed.mildPercent, 250);
        expect(pushed.highPercent, 250);
        expect(pushed.severePercent, 250);
      });

      test('holds a level at the one below rather than crossing down', () {
        final held = _defaults.withLevel(SpendOverrun.severe, 110);

        expect(held.severePercent, _defaults.highPercent);
      });

      test('ignores a move of the level that is not one', () {
        expect(_defaults.withLevel(SpendOverrun.none, 300), _defaults);
      });
    });

    test('is equal to another set of the same figures', () {
      expect(
        const OverrunSettings(mildPercent: 130),
        const OverrunSettings(mildPercent: 130),
      );
      expect(
        const OverrunSettings(enabled: false),
        isNot(OverrunSettings.defaults),
      );
    });
  });
}
