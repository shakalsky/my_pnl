import 'package:flutter/material.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/theme/overrun_style.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// One cell of the category grid.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    required this.spend,
    required this.onAddAmount,
    required this.onShowHistory,
    required this.onEdit,
    this.totalScaled,
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

  /// Tap books an amount — the frequent action gets the primary gesture.
  final VoidCallback onAddAmount;

  /// The category mark, top-left: it lists what has been booked here.
  ///
  /// On the icon rather than off a third one, which a quarter of a phone's
  /// width has no room for: the mark is already what names the category, so
  /// asking it what went into that category is the gesture people reach for
  /// first. It stays reachable from the settings modal too, for anyone who
  /// learnt it there.
  final VoidCallback onShowHistory;

  /// The settings icon, top-right: it edits the category itself.
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
    final flagColor = overrunBorderColor(
      overrun,
      brightness: theme.brightness,
    );

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
                    // Sits inside the tile's InkWell, so it needs its own hit
                    // target to keep the tap from opening the amount modal.
                    Semantics(
                      label: t.entries.categoryHistory(name: category.name),
                      button: true,
                      child: InkResponse(
                        onTap: onShowHistory,
                        radius: 20,
                        child: Container(
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
                      ),
                    ),
                    const Spacer(),
                    // Sits inside the tile's InkWell, so it needs its own hit
                    // target to keep the tap from opening the amount modal.
                    _SettingsButton(
                      onPressed: onEdit,
                      semanticLabel: t.spending.categorySettings(
                        name: category.name,
                      ),
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
                          // A magnitude: spending is stored negative, and a
                          // minus in front of every tile on a page whose
                          // heading already says these are what went out is a
                          // sign that never varies and so says nothing.
                          _amountText((totalScaled ?? spend.totalScaled).abs()),
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

/// What a tile shows for [scaled], the currency named by the circle above.
///
/// A dash for nothing booked, rather than `0.00`: a grid where every untouched
/// category reads as a figure gives the eye four columns of digits to sort
/// through before the ones that were actually spent stand out.
String _amountText(int scaled) => scaled == 0 ? '-' : formatAmountBare(scaled);

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
              t.common.add,
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
