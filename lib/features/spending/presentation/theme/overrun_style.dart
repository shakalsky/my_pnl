import 'package:flutter/material.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// How a category tile is outlined when its month has run past the usual.
///
/// Three colours over one shape, because the thing being shown is a degree of
/// the same thing: amber for "worth a look", red for "well over", dark red for
/// "twice the usual or more". Kept out of the widget so the border, the legend
/// and any future chart cannot drift apart on what a level looks like.
Color? overrunBorderColor(SpendOverrun overrun) => switch (overrun) {
  // No border of its own: a tile within its usual month keeps the plain fill
  // the grid is read against, and an outline on everything would make the
  // flagged ones just a different colour rather than a standout.
  SpendOverrun.none => null,
  SpendOverrun.mild => const Color(0xFFE0A100),
  SpendOverrun.high => const Color(0xFFD32F2F),
  SpendOverrun.severe => const Color(0xFF7A0C15),
};

/// How thick that outline is.
///
/// Wider than the add tile's, so a flagged category reads as marked rather than
/// as merely bordered.
const overrunBorderWidth = 2.5;

/// What a flagged tile says to a screen reader.
///
/// The colour carries the level for anyone who can see it; this carries the
/// same thing for anyone who cannot, which is why it names the level in words
/// rather than describing the border.
String? overrunSemanticLabel(SpendOverrun overrun) => switch (overrun) {
  SpendOverrun.none => null,
  SpendOverrun.mild => t.overrun.semanticsMild,
  SpendOverrun.high => t.overrun.semanticsHigh,
  SpendOverrun.severe => t.overrun.semanticsSevere,
};
