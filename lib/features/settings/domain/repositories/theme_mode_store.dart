import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';

/// Remembers whether the app is shown light, dark, or however the device is.
///
/// A device preference rather than user data, like the display currency and the
/// overrun thresholds: it says nothing about what was spent, and a choice that
/// travelled between devices would darken a phone because a laptop was.
abstract interface class ThemeModeStore {
  /// The mode in force, from the first read onwards.
  ///
  /// Emits the current value before any change, which is what lets the app
  /// shell hold one subscription for both startup and every later switch.
  Stream<AppThemeMode> watch();

  /// What is in force now.
  ///
  /// Never throws: an unreadable preference is the same as never having set
  /// one, which is [AppThemeMode.system].
  Future<AppThemeMode> read();

  /// Remembers [mode], and tells whatever is on screen.
  ///
  /// Never throws either — failing to remember an appearance is not worth
  /// interrupting anyone over.
  Future<void> write(AppThemeMode mode);
}
