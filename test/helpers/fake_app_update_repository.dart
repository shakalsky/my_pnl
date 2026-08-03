import 'dart:async';

import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';

/// In-memory stand-in for [AppUpdateRepository].
class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({
    AppVersion currentVersion = const AppVersion(major: 1, minor: 0, patch: 0),
    UpdateRequirement? requirement,
  }) : _status = AppUpdateStatus(
         currentVersion: currentVersion,
         requirement: requirement,
       );

  AppUpdateStatus _status;
  final _controller = StreamController<AppUpdateStatus>.broadcast();

  /// What the next [checkForUpdate] will find. Defaults to leaving things as
  /// they are, so a test that never sets it sees no surprise redirects.
  UpdateRequirement? Function()? nextRequirement;

  /// How many times the app asked.
  int checkCount = 0;

  @override
  AppUpdateStatus get status => _status;

  @override
  Stream<AppUpdateStatus> watchStatus() => _controller.stream;

  @override
  Future<void> checkForUpdate() async {
    checkCount++;
    if (nextRequirement case final next?) {
      final requirement = next();
      require(requirement);
    }
  }

  /// Announces a requirement as though the backend had just reported it.
  void require(UpdateRequirement? requirement) {
    _status = requirement == null
        ? _status.copyWith(clearRequirement: true)
        : _status.copyWith(requirement: requirement);
    _controller.add(_status);
  }

  Future<void> close() => _controller.close();
}
