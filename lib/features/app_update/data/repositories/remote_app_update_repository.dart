import 'dart:async';
import 'dart:developer';

import 'package:my_pnl/features/app_update/data/datasources/app_requirement_source.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';

/// Holds the last answer the backend gave and re-asks on demand.
class RemoteAppUpdateRepository implements AppUpdateRepository {
  RemoteAppUpdateRepository({
    required FetchRequirement fetchRequirement,
    required AppVersion currentVersion,
    required String platform,
  }) : _fetch = fetchRequirement,
       _platform = platform,
       _status = AppUpdateStatus(currentVersion: currentVersion);

  final FetchRequirement _fetch;
  final String _platform;
  final _controller = StreamController<AppUpdateStatus>.broadcast();

  AppUpdateStatus _status;

  @override
  AppUpdateStatus get status => _status;

  @override
  Stream<AppUpdateStatus> watchStatus() => _controller.stream;

  @override
  Future<void> checkForUpdate() async {
    try {
      final requirement = await _fetch(_platform);
      _emit(
        requirement == null
            ? _status.copyWith(clearRequirement: true)
            : _status.copyWith(requirement: requirement),
      );
    } on Object catch (e, s) {
      // Swallowed on purpose. The gate fails open: a device that cannot reach
      // the backend keeps the app it already has, and the next check — on
      // resume, or from the update screen's own button — tries again.
      log('Update check failed', error: e, stackTrace: s);
    }
  }

  void _emit(AppUpdateStatus status) {
    if (status == _status) return;

    _status = status;
    _controller.add(status);
  }

  Future<void> close() => _controller.close();
}

/// Stands in when no backend is configured.
///
/// Nothing can require an update, so nothing does — the same shape as the
/// local-only auth and sync repositories.
class LocalOnlyAppUpdateRepository implements AppUpdateRepository {
  const LocalOnlyAppUpdateRepository(this.currentVersion);

  final AppVersion currentVersion;

  @override
  AppUpdateStatus get status => AppUpdateStatus(currentVersion: currentVersion);

  @override
  Stream<AppUpdateStatus> watchStatus() => const Stream.empty();

  @override
  Future<void> checkForUpdate() async {}
}
