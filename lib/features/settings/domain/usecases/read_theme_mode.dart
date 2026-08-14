import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';

/// Reads which theme the app is shown in, once.
///
/// For the settings page, which shows the choice as it stands rather than
/// following it — what it draws is what it is about to change.
class ReadThemeMode {
  const ReadThemeMode(this._store);

  final ThemeModeStore _store;

  Future<AppThemeMode> call() => _store.read();
}
