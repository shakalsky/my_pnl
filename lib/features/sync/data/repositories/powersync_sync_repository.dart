import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';
import 'package:powersync/powersync.dart';

/// Reads sync state from PowerSync.
///
/// Translates the engine's status into the four states the dot can show, and
/// stamps the failure time itself — PowerSync reports that an error is
/// current, not when it first appeared, so without this a red dot could not
/// say when things went wrong.
class PowerSyncSyncRepository implements SyncRepository {
  PowerSyncSyncRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PowerSyncDatabase _db;
  final DateTime Function() _clock;

  DateTime? _lastFailedAt;
  Object? _lastErrorSeen;

  @override
  Stream<SyncState> watchSyncState() async* {
    yield _toState(_db.currentStatus);
    yield* _db.statusStream.map(_toState);
  }

  SyncState _toState(SyncStatus status) {
    final error = status.anyError;

    if (error != null) {
      // Only re-stamp when the error is a new one, so a status stream that
      // repeats the same failure does not keep moving the clock forward.
      if (!identical(error, _lastErrorSeen)) {
        _lastErrorSeen = error;
        _lastFailedAt = _clock().toUtc();
      }

      return SyncState(
        health: SyncHealth.failed,
        lastSyncedAt: status.lastSyncedAt?.toUtc(),
        lastFailedAt: _lastFailedAt,
        lastError: error.toString(),
      );
    }

    _lastErrorSeen = null;

    if (status.downloading || status.uploading || status.connecting) {
      return SyncState(
        health: SyncHealth.syncing,
        lastSyncedAt: status.lastSyncedAt?.toUtc(),
        lastFailedAt: _lastFailedAt,
      );
    }

    // hasSynced is null until the engine knows, and false before the first
    // completed sync; neither is "green".
    if (status.hasSynced ?? false) {
      return SyncState(
        health: SyncHealth.synced,
        lastSyncedAt: status.lastSyncedAt?.toUtc(),
        lastFailedAt: _lastFailedAt,
      );
    }

    return SyncState(lastFailedAt: _lastFailedAt);
  }
}

/// Sync state for builds with no backend configured.
///
/// Always idle: there is nothing to sync, and a red dot would suggest a fault
/// where there is only a missing configuration.
class LocalOnlySyncRepository implements SyncRepository {
  const LocalOnlySyncRepository();

  @override
  Stream<SyncState> watchSyncState() =>
      Stream.value(const SyncState());
}
