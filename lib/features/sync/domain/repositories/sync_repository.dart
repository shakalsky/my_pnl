import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';

/// Where sync stands, as the UI needs it.
///
/// An interface so the indicator does not import PowerSync, and so a test can
/// drive it through every state without a server.
// ignore: one_member_abstracts
abstract interface class SyncRepository {
  /// Emits the current state immediately, then on every change.
  Stream<SyncState> watchSyncState();
}
