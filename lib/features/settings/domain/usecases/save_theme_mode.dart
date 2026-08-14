import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';

/// Remembers which theme the app is shown in.
class SaveThemeMode {
  const SaveThemeMode(this._store);

  final ThemeModeStore _store;

  Future<void> call(AppThemeMode mode) => _store.write(mode);
}
