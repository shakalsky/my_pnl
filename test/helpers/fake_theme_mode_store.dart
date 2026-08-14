import 'dart:async';

import 'package:my_pnl/features/settings/domain/entities/app_theme_mode.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';

/// In-memory stand-in for the appearance preference.
///
/// Behaves like the real store in the one way the app shell depends on: the
/// stream opens with what is stored and a write is announced to whatever is
/// already watching, so the theme changes under a page that is already up.
class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore({AppThemeMode initial = AppThemeMode.system})
    : _mode = initial;

  AppThemeMode _mode;
  final _changes = StreamController<AppThemeMode>.broadcast();

  /// Set to have [read] throw, which is how an unopenable store behaves.
  Exception? readError;

  /// Every mode written, in order, so a test can see that a choice was kept as
  /// well as that it was applied.
  final writes = <AppThemeMode>[];

  @override
  Stream<AppThemeMode> watch() async* {
    yield _mode;
    yield* _changes.stream;
  }

  @override
  Future<AppThemeMode> read() async {
    if (readError case final error?) throw error;
    return _mode;
  }

  @override
  Future<void> write(AppThemeMode mode) async {
    _mode = mode;
    writes.add(mode);
    if (!_changes.isClosed) _changes.add(mode);
  }

  Future<void> close() => _changes.close();
}
