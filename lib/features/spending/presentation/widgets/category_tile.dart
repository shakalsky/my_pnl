import 'package:flutter/material.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';

/// One cell of the category grid.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    required this.spend,
    required this.onAddAmount,
    required this.onShowHistory,
    required this.onEdit,
    this.totalScaled,
    this.currencyLabel = baseCurrencySymbol,
    super.key,
  });

  final CategorySpend spend;

  /// What to show for the total, when it is not the figure on [spend] itself.
  ///
  /// The page converts every amount it shows together, so the tile is told what
  /// to display rather than working it out — one currency for the circle and the
  /// grid, or they would disagree.
  final int? totalScaled;

  /// The sign or ticker beside the total.
  final String currencyLabel;

  /// Tap books an amount — the frequent action gets the primary gesture.
  final VoidCallback onAddAmount;

  /// The history icon, top-right.
  final VoidCallback onShowHistory;

  /// Long-press edits the category itself.
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

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAddAmount,
        onLongPress: onEdit,
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
                  _HistoryButton(
                    onPressed: onShowHistory,
                    semanticLabel: '${category.name} history',
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
                          currencyLabel,
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

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onPressed, required this.semanticLabel});

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
            Icons.receipt_long_outlined,
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
