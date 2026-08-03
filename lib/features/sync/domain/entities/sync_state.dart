import 'package:equatable/equatable.dart';

/// What the indicator dot is saying.
enum SyncHealth {
  /// Nothing to sync — no backend configured, or never connected.
  idle,

  /// A sync is in flight.
  syncing,

  /// The last attempt completed.
  synced,

  /// The last attempt failed.
  failed,
}

/// A snapshot of where sync stands.
class SyncState extends Equatable {
  const SyncState({
    this.health = SyncHealth.idle,
    this.lastSyncedAt,
    this.lastFailedAt,
    this.lastError,
  });

  final SyncHealth health;

  /// When the last successful sync completed, in UTC. Null before the first.
  final DateTime? lastSyncedAt;

  /// When the last failure was observed, in UTC.
  ///
  /// Stamped by the app rather than read from the sync engine: the engine
  /// reports *that* it is failing, not when it started.
  final DateTime? lastFailedAt;

  /// The failure, for the message shown on tap.
  final String? lastError;

  @override
  List<Object?> get props => [health, lastSyncedAt, lastFailedAt, lastError];
}
