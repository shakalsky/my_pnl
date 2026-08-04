import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';

/// Streams when to warn that a month has run past the usual.
class WatchOverrunSettings {
  const WatchOverrunSettings(this._store);

  final OverrunSettingsStore _store;

  Stream<OverrunSettings> call() => _store.watch();
}
