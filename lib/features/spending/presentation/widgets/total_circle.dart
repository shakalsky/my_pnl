import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/scales.dart';

/// One slice of the ring around the total.
class TotalCircleSegment extends Equatable {
  const TotalCircleSegment({required this.color, required this.weightScaled});

  final Color color;

  /// How much this slice accounts for, as a magnitude scaled by `amountScale`.
  ///
  /// A magnitude, not a signed amount: spending is stored negative, and a
  /// negative share has no length to draw. Zero or less draws nothing.
  final int weightScaled;

  @override
  List<Object?> get props => [color, weightScaled];
}

/// One arc of the ring, in radians.
class RingArc extends Equatable {
  const RingArc({
    required this.color,
    required this.start,
    required this.sweep,
  });

  final Color color;

  /// Where the arc begins. Clockwise from twelve o'clock.
  final double start;

  final double sweep;

  @override
  List<Object?> get props => [color, start, sweep];
}

/// Canvas angles start at three o'clock, so the ring is rotated back a quarter
/// turn to begin where a reader expects it to.
const double _twelveOClock = -math.pi / 2;

/// Blank left between neighbouring slices, in radians — about 3°.
const double _defaultGap = 0.05;

/// How thick the ring is drawn.
const double _ringWidth = 6;

/// Lays [segments] around the circle, each taking the share of the whole that
/// its weight is of the total.
///
/// Empty when there is nothing to show, which is the signal to draw a plain
/// ring instead.
List<RingArc> ringArcs(
  List<TotalCircleSegment> segments, {
  double gap = _defaultGap,
}) {
  final drawable = segments
      .where((segment) => segment.weightScaled > 0)
      .toList(growable: false);

  final total = drawable.fold<int>(
    0,
    (sum, segment) => sum + segment.weightScaled,
  );
  if (total == 0) return const [];

  // A single slice covers the whole ring, where a gap would only put a notch
  // in an otherwise unbroken circle.
  final between = drawable.length == 1 ? 0.0 : gap;

  final arcs = <RingArc>[];
  var start = _twelveOClock;

  for (final segment in drawable) {
    final sweep = (segment.weightScaled / total) * 2 * math.pi;
    // The gap never eats more than a quarter of a slice, so a category worth a
    // fraction of a percent still draws a sliver rather than vanishing into
    // the space meant to separate it from its neighbours.
    final trimmed = math.min(between, sweep / 4);

    arcs.add(
      RingArc(
        color: segment.color,
        start: start + trimmed / 2,
        sweep: sweep - trimmed,
      ),
    );
    start += sweep;
  }

  return arcs;
}

/// Total spend, as a circle, ringed by where it went.
///
/// The ring is the breakdown: one arc per category, each as long a share of the
/// circle as that category is of the whole, in the category's own colour. With
/// nothing to break down it falls back to a plain ring.
class TotalCircle extends StatelessWidget {
  const TotalCircle({
    required this.totalScaled,
    this.segments = const [],
    this.label = 'Total spent',
    this.currencyLabel = baseCurrencySymbol,
    this.onTap,
    super.key,
  });

  /// The figure to show, already in whatever currency [currencyLabel] names.
  /// Converting is the caller's business; this only draws.
  final int totalScaled;

  final String label;

  /// The symbol or ticker beside the figure.
  final String currencyLabel;

  /// Called when the circle is tapped. Null leaves it inert, with no ink to
  /// suggest otherwise.
  final VoidCallback? onTap;

  /// What the ring is made of. The slices need not add up to [totalScaled] —
  /// the spending page shows a net figure in the middle and the categories
  /// behind it around the edge.
  final List<TotalCircleSegment> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CustomPaint(
      // A foreground painter: the ring has to land on top of the filled circle
      // below, and `painter` draws underneath the child rather than over it.
      foregroundPainter: _RingPainter(
        arcs: ringArcs(segments),
        emptyColor: colors.outlineVariant,
        strokeWidth: _ringWidth,
      ),
      // A Material rather than a DecoratedBox: it fills the circle and is also
      // what paints the tap's ink. Ink from the Scaffold above would land
      // underneath an opaque fill and never be seen.
      child: Material(
        color: colors.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              // Clears the ring as well as the edge: unlike a border, a painted
              // ring does not inset what it surrounds.
              padding: const EdgeInsets.all(_ringWidth + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      formatAmountIn(totalScaled, currencyLabel),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.arcs,
    required this.emptyColor,
    required this.strokeWidth,
  });

  final List<RingArc> arcs;

  /// Drawn as an unbroken ring when there are no arcs.
  final Color emptyColor;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Half the stroke in from the edge: a stroke straddles the path it follows,
    // so the outer half of it would otherwise be clipped off.
    final radius = (size.shortestSide - strokeWidth) / 2;
    if (radius <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (arcs.isEmpty) {
      canvas.drawCircle(center, radius, paint..color = emptyColor);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (final arc in arcs) {
      canvas.drawArc(rect, arc.start, arc.sweep, false, paint..color = arc.color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      !listEquals(oldDelegate.arcs, arcs) ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
