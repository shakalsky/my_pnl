part of 'settings_bloc.dart';

enum SettingsStatus {
  /// Nothing has been read yet. The page shows the defaults, which is what the
  /// app is running on until a preference says otherwise.
  initial,
  ready,
}

final class SettingsState extends Equatable {
  const SettingsState({
    this.themeMode = AppThemeMode.system,
    this.languageTag,
    this.status = SettingsStatus.initial,
  });

  final AppThemeMode themeMode;

  /// The language chosen, or null while the device's own is being followed.
  ///
  /// Null is a value here rather than an absence, which is why [copyWith] needs
  /// a flag to write it: "follow the device" is a choice someone can make, and
  /// one they have to be able to make again after picking a language.
  final String? languageTag;

  final SettingsStatus status;

  /// Whether the app is following the device's language.
  bool get followsDeviceLanguage => languageTag == null;

  SettingsState copyWith({
    AppThemeMode? themeMode,
    String? languageTag,
    bool clearLanguageTag = false,
    SettingsStatus? status,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      languageTag: clearLanguageTag ? languageTag : languageTag ?? this.languageTag,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [themeMode, languageTag, status];
}
