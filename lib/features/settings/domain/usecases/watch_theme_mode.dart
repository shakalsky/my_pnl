import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';

/// Streams which theme the app is shown in.
class WatchThemeMode {
  const WatchThemeMode(this._store);

  final ThemeModeStore _store;

  Stream<AppThemeMode> call() => _store.watch();
}
