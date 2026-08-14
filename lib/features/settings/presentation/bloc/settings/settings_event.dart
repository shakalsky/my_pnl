part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Seeds the page with the settings in force.
final class SettingsRequested extends SettingsEvent {
  const SettingsRequested();
}

/// Shows the app light, dark, or however the device is.
final class SettingsThemeModeSelected extends SettingsEvent {
  const SettingsThemeModeSelected(this.mode);

  final AppThemeMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Reads the app in one language, or hands the choice back to the device.
final class SettingsLanguageSelected extends SettingsEvent {
  const SettingsLanguageSelected(this.languageTag);

  /// A language tag this build ships strings for, or null to follow the device.
  final String? languageTag;

  @override
  List<Object?> get props => [languageTag];
}
