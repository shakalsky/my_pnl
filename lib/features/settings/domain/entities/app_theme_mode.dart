/// Which of the app's two themes is shown.
///
/// Its own enum rather than Flutter's `ThemeMode` so that the store and the
/// preference beneath it stay clear of the widget layer — everything below the
/// presentation folder in this app is Dart, not Flutter, and the mapping to
/// `ThemeMode` is one line where the theme is actually applied.
enum AppThemeMode {
  /// Whatever the device is set to, and following it when it changes.
  ///
  /// The default. A phone that dims itself at sunset should dim this app with
  /// it, and an app that made its own choice by default would be the one thing
  /// on the screen that did not.
  system,

  light,
  dark;

  /// Reads back what [name] wrote, or null for anything else.
  ///
  /// Null rather than a fallback: the caller is a store deciding whether the
  /// device has a preference at all, and it has its own answer for "no".
  static AppThemeMode? tryParse(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
