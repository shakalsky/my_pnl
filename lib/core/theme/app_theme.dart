import 'package:flutter/material.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';

/// The light theme, and the one the app has always shown.
///
/// Grown from Flutter's own Material 3 baseline rather than a seed of our own,
/// which is what the app was already running on — so turning the theme into
/// something declared here changes nothing about how it looks.
ThemeData get appLightTheme => _themeFor(Brightness.light);

/// The same theme in the dark.
///
/// Its counterpart in every part: the baseline dark scheme is the light one's
/// own pair, so the two agree on which colour is the primary and differ only in
/// what they are drawn against.
ThemeData get appDarkTheme => _themeFor(Brightness.dark);

ThemeData _themeFor(Brightness brightness) {
  // Built first and read below, so the pieces bolted on agree with the scheme
  // Flutter picked for this brightness rather than guessing at it.
  final base = ThemeData(brightness: brightness);
  final colors = base.colorScheme;

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: colors.inversePrimary,
      // Named rather than left to the default: the default is drawn for the
      // surface colour, and the bar is no longer on it.
      foregroundColor: colors.onSurface,
    ),
    extensions: [
      switch (brightness) {
        Brightness.light => AppSemanticColors.light,
        Brightness.dark => AppSemanticColors.dark,
      },
    ],
  );
}
