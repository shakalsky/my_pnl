import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';

/// Which of the two overviews is on screen, drawn as a pair of arrows.
///
/// Arrows rather than the usual dots because the two pages are not a sequence
/// of equals: one rises, the other falls, which is the difference between the
/// two halves of the ledger. Income takes the arrow up and to the left,
/// spending the one down and to the right, and whichever page is on screen is
/// the one drawn in its colour and at the larger size.
///
/// It reads the controller directly rather than being told the page, so the
/// colour and the size follow the finger through a drag instead of snapping
/// once the page has settled.
class OverviewPageIndicator extends StatelessWidget {
  const OverviewPageIndicator({
    required this.controller,
    required this.incomePage,
    required this.spendingPage,
    super.key,
  });

  final PageController controller;
  final int incomePage;
  final int spendingPage;

  /// The active arrow, against the [_inactiveSize] of the one it is not.
  static const _activeSize = 22.0;
  static const _inactiveSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final semantics = AppSemanticColors.of(context);
    final idle = Theme.of(context).colorScheme.outline;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // `page` cannot be read before the PageView it drives has been laid
        // out, which is the frame this first builds in.
        final page = controller.hasClients
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();

        // How far along the way to spending we are: 0 sitting on income, 1 on
        // spending, and everything between mid-swipe.
        final toSpending = ((page - incomePage) / (spendingPage - incomePage))
            .clamp(0.0, 1.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Arrow(
              icon: Icons.north_west,
              strength: 1 - toSpending,
              idle: idle,
              active: semantics.positive,
            ),
            _Arrow(
              icon: Icons.south_east,
              strength: toSpending,
              idle: idle,
              active: semantics.negative,
            ),
          ],
        );
      },
    );
  }
}

/// One arrow, between grey and its meaning by [strength].
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.strength,
    required this.idle,
    required this.active,
  });

  final IconData icon;

  /// 0 for the page that is off screen, 1 for the one on it.
  final double strength;

  final Color idle;
  final Color active;

  @override
  Widget build(BuildContext context) {
    // A box the size of the grown arrow, so the pair keeps its place on the
    // row while one of them swells and the other shrinks.
    return SizedBox.square(
      dimension: OverviewPageIndicator._activeSize + 8,
      child: Center(
        child: Icon(
          icon,
          size: lerpDouble(
            OverviewPageIndicator._inactiveSize,
            OverviewPageIndicator._activeSize,
            strength,
          ),
          color: Color.lerp(idle, active, strength),
        ),
      ),
    );
  }
}
