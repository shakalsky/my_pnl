import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/presentation/theme/overrun_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_tile.dart';

import '../../../../helpers/helpers.dart';

/// A cell the size the grid gives one: four to a row on a narrow phone.
const _cellWidth = 84.0;
const _cellHeight = 104.0;

CategorySpend _spend(String name, int totalScaled) => CategorySpend(
  category: Category(
    id: name,
    name: name,
    colorArgb: 0xFFFF0000,
    iconKey: 'groceries',
  ),
  totalScaled: totalScaled,
);

extension on WidgetTester {
  Future<void> pumpTile(
    CategorySpend spend, {
    SpendOverrun overrun = SpendOverrun.none,
  }) async {
    await pumpApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: _cellWidth,
            height: _cellHeight,
            child: CategoryTile(
              spend: spend,
              overrun: overrun,
              onAddAmount: () {},
              onEdit: () {},
            ),
          ),
        ),
      ),
    );
  }

  /// The outline the tile is currently drawn with.
  BorderSide tileBorder() {
    final material = widget<Material>(find.byType(Material).last);
    return (material.shape! as RoundedRectangleBorder).side;
  }

  /// How many lines the paragraph showing [text] settled on.
  ///
  /// Counted from the boxes the glyphs were laid into — one distinct top per
  /// line — because a paragraph keeps its line metrics to itself.
  int lineCount(String text) {
    final paragraph = renderObject<RenderParagraph>(find.text(text));
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );

    return boxes.map((box) => box.top).toSet().length;
  }
}

void main() {
  group('CategoryTile', () {
    testWidgets('gives a long name a second line to run onto', (tester) async {
      await tester.pumpTile(_spend('Groceries and household', -4235));

      expect(tester.lineCount('Groceries and household'), 2);
    });

    testWidgets('keeps the name two lines tall when one would do', (
      tester,
    ) async {
      await tester.pumpTile(_spend('Rent', -4235));
      final short = tester.getSize(find.text('Rent')).height;

      await tester.pumpTile(_spend('Groceries and household', -4235));
      final long = tester.getSize(find.text('Groceries and household')).height;

      // Amounts are read down the grid's columns, so a one-word name has to
      // hold the same height as a name that wraps or the figures beneath them
      // would sit at different heights.
      expect(short, long);
    });

    testWidgets('holds the amount block’s height as the figure shrinks', (
      tester,
    ) async {
      await tester.pumpTile(_spend('Rent', -4235));
      final short = tester.getSize(find.byType(FittedBox)).height;

      // Wide enough that it cannot be drawn at full size in a quarter of a
      // phone's width, so the FittedBox scales it down.
      await tester.pumpTile(_spend('Rent', -123456789));
      final long = tester.getSize(find.byType(FittedBox)).height;

      expect(long, short);
    });

    testWidgets('fits the cell the grid gives it', (tester) async {
      await tester.pumpTile(_spend('Groceries and household', -123456789));

      expect(tester.takeException(), isNull);
    });

    testWidgets('leaves a usual month unoutlined', (tester) async {
      await tester.pumpTile(_spend('Rent', -4235));

      // An outline on every tile would make the flagged ones merely a different
      // colour rather than a standout.
      expect(tester.tileBorder(), BorderSide.none);
    });

    testWidgets('outlines a flagged month in the colour of its level', (
      tester,
    ) async {
      for (final overrun in SpendOverrun.values.where((o) => o.isFlagged)) {
        await tester.pumpTile(_spend('Rent', -4235), overrun: overrun);
        final border = tester.tileBorder();

        expect(border.color, overrunBorderColor(overrun));
        expect(border.width, overrunBorderWidth);
      }
    });

    testWidgets('draws each level a different colour', (tester) async {
      final colors = {
        for (final overrun in SpendOverrun.values) overrunBorderColor(overrun),
      };

      // Three flagged levels plus the null of an unflagged one: a level that
      // shared a colour with another could not be told apart on screen.
      expect(colors, hasLength(SpendOverrun.values.length));
    });

    testWidgets('says out loud what the colour shows', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpTile(
        _spend('Rent', -4235),
        overrun: SpendOverrun.severe,
      );

      // The border carries the level for anyone who can see it; this carries it
      // for anyone who cannot. Matched loosely because the warning is read out
      // as part of the tile, ahead of the name and the amount.
      expect(
        find.bySemanticsLabel(
          RegExp(overrunSemanticLabel(SpendOverrun.severe)!),
        ),
        findsOne,
      );

      await tester.pumpTile(_spend('Rent', -4235));
      expect(find.bySemanticsLabel(RegExp('usual month')), findsNothing);

      // Disposed here rather than in a tear-down: the framework checks for a
      // live handle before tear-downs run.
      semantics.dispose();
    });
  });
}
