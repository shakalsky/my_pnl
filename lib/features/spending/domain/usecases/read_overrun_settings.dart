import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';

/// The warning thresholds as they stand, for seeding the form.
class ReadOverrunSettings {
  const ReadOverrunSettings(this._store);

  final OverrunSettingsStore _store;

  Future<OverrunSettings> call() => _store.read();
}
