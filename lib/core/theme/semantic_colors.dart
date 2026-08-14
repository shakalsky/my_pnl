import 'package:flutter/material.dart';

/// The colours in the app that carry a meaning rather than a style.
///
/// Green for money coming in and for a device that is up to date, amber for
/// something still in flight, green again — a brighter one — for the field the
/// cursor is in. None of these can come from the colour scheme: a scheme's
/// primary and secondary say which app you are in, and these have to say the
/// same thing in any app, in either brightness.
///
/// They cannot be constants either, which is the reason this is a theme
/// extension rather than a file of `const Color`s. A green picked to read on
/// white is close to unreadable on a dark surface, so each meaning needs two
/// values and something to choose between them. That something is the theme,
/// which every widget already has in hand.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.positive,
    required this.caution,
    required this.focus,
  });

  /// What these meant before there was a dark theme, kept to the shade.
  static const light = AppSemanticColors(
    positive: Color(0xFF2E7D32),
    caution: Color(0xFFF9A825),
    focus: Color(0xFF4CAF50),
  );

  /// The same three meanings, lightened to carry on a dark surface.
  ///
  /// Lightened rather than merely reused: the light set is chosen to be dark
  /// enough to read against white, which is exactly what makes it disappear
  /// against a near-black one.
  static const dark = AppSemanticColors(
    positive: Color(0xFF81C784),
    caution: Color(0xFFFFD54F),
    focus: Color(0xFF66BB6A),
  );

  /// Money in, and sync that has nothing left to send.
  final Color positive;

  /// Sync still working.
  final Color caution;

  /// The outline on the field being typed into.
  final Color focus;

  /// The set in force, or the light one when the theme carries none.
  ///
  /// The fallback is what lets a widget be pumped under a bare [MaterialApp] —
  /// every widget test in this repo does — without each of them having to build
  /// the app's theme first.
  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ?? light;

  @override
  AppSemanticColors copyWith({
    Color? positive,
    Color? caution,
    Color? focus,
  }) {
    return AppSemanticColors(
      positive: positive ?? this.positive,
      caution: caution ?? this.caution,
      focus: focus ?? this.focus,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;

    return AppSemanticColors(
      positive: Color.lerp(positive, other.positive, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}
