import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';

abstract interface class AppUpdateRepository {
  /// Where the running build stands right now.
  ///
  /// Synchronous because the router's redirect has to answer without waiting —
  /// the same reason `AuthRepository.currentUser` exists. Reads the last answer
  /// the backend gave, which is "nothing required" until [checkForUpdate] has
  /// returned at least once.
  AppUpdateStatus get status;

  /// Re-emitted whenever the answer changes.
  Stream<AppUpdateStatus> watchStatus();

  /// Asks the backend what the minimum is now.
  ///
  /// Never throws: a failed check leaves the last known answer in place and is
  /// logged. The gate fails open, so an unreachable backend cannot lock a user
  /// out of local data.
  Future<void> checkForUpdate();
}
