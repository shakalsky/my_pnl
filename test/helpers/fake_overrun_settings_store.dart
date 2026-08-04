import 'dart:async';

import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';

/// In-memory stand-in for the warning-threshold preference.
///
/// Behaves like the real store in the one way the pages depend on: a write is
/// announced to whatever is already watching, so a grid re-flags itself the
/// moment the settings change.
class FakeOverrunSettingsStore implements OverrunSettingsStore {
  FakeOverrunSettingsStore({OverrunSettings initial = OverrunSettings.defaults})
    : _settings = initial;

  OverrunSettings _settings;
  final _changes = StreamController<OverrunSettings>.broadcast();

  /// Set to have [read] throw, which is how an unopenable store behaves.
  Exception? readError;

  /// Set to have [write] throw.
  Exception? writeError;

  /// What was last written, for a test that checks the form saved.
  OverrunSettings? saved;

  @override
  Stream<OverrunSettings> watch() async* {
    yield _settings;
    yield* _changes.stream;
  }

  @override
  Future<OverrunSettings> read() async {
    if (readError case final error?) throw error;
    return _settings;
  }

  @override
  Future<void> write(OverrunSettings settings) async {
    if (writeError case final error?) throw error;

    // Normalized like the real store, so a test cannot save a set of
    // thresholds through the fake that the app could never hold.
    _settings = settings.normalized;
    saved = _settings;
    _changes.add(_settings);
  }

  Future<void> close() => _changes.close();
}
