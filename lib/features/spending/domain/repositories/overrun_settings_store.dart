import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';

/// Remembers when to warn that a month has run past the usual.
///
/// A device preference rather than user data, so it lives beside the app rather
/// than in the synced database: how strict the warnings are says nothing about
/// what was spent, and a threshold that travelled between devices would change
/// what a second one shows without anyone touching it.
abstract interface class OverrunSettingsStore {
  /// The settings in force, re-emitted whenever they are changed.
  ///
  /// A stream rather than a one-off read because the grid is drawn from these:
  /// turning the warnings off has to clear the borders that are already on
  /// screen, not wait for the page to be opened again.
  ///
  /// Never errors — unreadable settings are the defaults.
  Stream<OverrunSettings> watch();

  /// The settings as they stand, for seeding the form that edits them.
  ///
  /// Never throws: an unreadable preference is the same as never having set one.
  Future<OverrunSettings> read();

  /// Remembers [settings] and re-emits them to [watch].
  ///
  /// Never throws either — failing to remember a threshold is not worth
  /// interrupting anyone over, and the choice still applies for this run.
  Future<void> write(OverrunSettings settings);
}
