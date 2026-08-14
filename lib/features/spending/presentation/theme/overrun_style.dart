import 'package:flutter/material.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// How a category tile is outlined when its month has run past the usual.
///
/// Three colours over one shape, because the thing being shown is a degree of
/// the same thing: amber for "worth a look", red for "well over", dark red for
/// "twice the usual or more". Kept out of the widget so the border, the legend
/// and any future chart cannot drift apart on what a level looks like.
///
/// [brightness] is what the tile is drawn against, and it has to be asked for
/// rather than assumed. The light set escalates by getting darker, which is how
/// a scale reads on white — and exactly backwards on near-black, where the
/// worst of the three would be the one nobody could see. The dark set escalates
/// the other way, by getting hotter, and keeps each level's hue so the two sets
/// mean the same three things.
///
/// Defaults to light: every caller that has a [BuildContext] should pass
/// `Theme.of(context).brightness`, and a caller with no theme in hand — a test
/// naming an expected colour — is asking about the app as it has always looked.
Color? overrunBorderColor(
  SpendOverrun overrun, {
  Brightness brightness = Brightness.light,
}) => switch ((overrun, brightness)) {
  // No border of its own: a tile within its usual month keeps the plain fill
  // the grid is read against, and an outline on everything would make the
  // flagged ones just a different colour rather than a standout.
  (SpendOverrun.none, _) => null,
  (SpendOverrun.mild, Brightness.light) => const Color(0xFFE0A100),
  (SpendOverrun.high, Brightness.light) => const Color(0xFFD32F2F),
  (SpendOverrun.severe, Brightness.light) => const Color(0xFF7A0C15),
  (SpendOverrun.mild, Brightness.dark) => const Color(0xFFFFC44D),
  (SpendOverrun.high, Brightness.dark) => const Color(0xFFFF6B5E),
  (SpendOverrun.severe, Brightness.dark) => const Color(0xFFFF3B4E),
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
