import 'package:flutter/material.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/theme/overrun_style.dart';

/// One cell of the category grid.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    required this.spend,
    required this.onAddAmount,
    required this.onEdit,
    this.totalScaled,
    this.currencyLabel,
    this.overrun = SpendOverrun.none,
    super.key,
  });

  final CategorySpend spend;

  /// How far past its usual month this category has gone, which is what the
  /// tile's border shows.
  ///
  /// Passed in rather than worked out here: the comparison needs the months
  /// before the one on screen, which a tile has no way to see.
  final SpendOverrun overrun;

  /// What to show for the total, when it is not the figure on [spend] itself.
  ///
  /// The page converts every amount it shows together, so the tile is told what
  /// to display rather than working it out — one currency for the circle and the
  /// grid, or they would disagree.
  final int? totalScaled;

  /// The sign or ticker beside the total. Null falls back to the base
  /// currency's sign, which is what the total is recorded in.
  ///
  /// Nullable rather than defaulted to it: the base is a choice the reader can
  /// change, so it is not a constant a default value could name.
  final String? currencyLabel;

  /// Tap books an amount — the frequent action gets the primary gesture.
  final VoidCallback onAddAmount;

  /// The settings icon, top-right: it edits the category itself. Its history is
  /// reached from that same modal, one step in rather than off a second icon
  /// competing for a quarter of a phone's width.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = spend.category;
    final nameStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final amountStyle = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w600,
    );
    final flagColor = overrunBorderColor(overrun);

    return Semantics(
      // Read out with the tile, ahead of its name and amount: the border says
      // "unusual" to anyone who can see it, and a colour on its own says nothing
      // to anyone who cannot. Null on a normal month, which adds nothing.
      label: overrunSemanticLabel(overrun),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        // A shape rather than a radius, because the two cannot both be given and
        // the border is what marks a month that has run past the usual.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: flagColor == null
              ? BorderSide.none
              : BorderSide(color: flagColor, width: overrunBorderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAddAmount,
          // No long-press: it belongs to the drag that rearranges the grid, and
          // a gesture that both lifts a tile and opens a modal would fire the
          // modal every time a drag was thought better of.
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(category.colorArgb),
                      ),
                      child: Icon(
                        iconForKey(category.iconKey),
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const Spacer(),
                    // Sits inside the tile's InkWell, so it needs its own hit
                    // target to keep the tap from opening the amount modal.
                    _SettingsButton(
                      onPressed: onEdit,
                      semanticLabel: '${category.name} settings',
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Two lines' worth of height whether the name needs them or
                    // not: the grid is read down its columns, and a one-word name
                    // next to a two-word one would otherwise sit its amount at a
                    // different height.
                    SizedBox(
                      height: _lineBoxHeight(context, nameStyle, 2),
                      child: Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: nameStyle,
                        strutStyle: StrutStyle.fromTextStyle(
                          nameStyle,
                          forceStrutHeight: true,
                        ),
                      ),
                    ),
                    // Four to a row leaves little width, so long amounts shrink
                    // rather than get truncated — the number is the point of the
                    // tile. The height stays that of an unshrunk line, so a tile
                    // holding a long figure keeps its baseline with the rest.
                    SizedBox(
                      height: _lineBoxHeight(context, amountStyle, 1),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatAmountIn(
                            totalScaled ?? spend.totalScaled,
                            currencyLabel ?? baseCurrencySymbol,
                          ),
                          maxLines: 1,
                          style: amountStyle,
                          strutStyle: StrutStyle.fromTextStyle(
                            amountStyle,
                            forceStrutHeight: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How tall [lines] lines of [style] come out here, text scaling included.
///
/// One line is measured rather than worked out from `fontSize`, because a line's
/// height is the font's business — a metric no arithmetic on the style can
/// recover. Multiplying is then exact: a forced strut makes every line that
/// height, and forcing the same strut on the `Text` is what lets the box it goes
/// in be sized this way at all.
double _lineBoxHeight(BuildContext context, TextStyle style, int lines) {
  final painter = TextPainter(
    text: TextSpan(text: 'M', style: style),
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();

  final height = painter.height;
  painter.dispose();
  return height * lines;
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed, required this.semanticLabel});

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.settings_outlined,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The trailing cell of the grid, which opens the new-category modal.
class AddCategoryTile extends StatelessWidget {
  const AddCategoryTile({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: colors.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
