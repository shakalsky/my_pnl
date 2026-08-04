import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';

/// Remembers when to warn that a month has run past the usual.
class SaveOverrunSettings {
  const SaveOverrunSettings(this._store);

  final OverrunSettingsStore _store;

  Future<void> call(OverrunSettings settings) => _store.write(settings);
}
