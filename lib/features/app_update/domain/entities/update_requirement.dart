import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';

/// The oldest build the backend still accepts, for one platform.
class UpdateRequirement extends Equatable {
  const UpdateRequirement({
    required this.minVersion,
    this.storeUrl,
    this.message,
  });

  final AppVersion minVersion;

  /// Where to send the user. Null when no link is configured, in which case the
  /// screen explains without offering a button it cannot honour.
  final String? storeUrl;

  /// Wording to show instead of the default explanation. For a release that
  /// needs a reason given ("accounts moved to a new format").
  final String? message;

  @override
  List<Object?> get props => [minVersion, storeUrl, message];
}

/// Where the running build stands against the requirement.
class AppUpdateStatus extends Equatable {
  const AppUpdateStatus({required this.currentVersion, this.requirement});

  final AppVersion currentVersion;

  /// Null when nothing is required, or when the check has not answered yet.
  final UpdateRequirement? requirement;

  /// Whether the app has to stop and send the user to the store.
  ///
  /// False whenever the requirement is unknown. The check fails open on
  /// purpose: this app works offline, and a device that cannot reach the
  /// backend must not be locked out of data it already holds by a rule it
  /// cannot read.
  bool get isUpdateRequired => switch (requirement) {
    null => false,
    final requirement => currentVersion.isOlderThan(requirement.minVersion),
  };

  AppUpdateStatus copyWith({
    UpdateRequirement? requirement,
    bool clearRequirement = false,
  }) {
    return AppUpdateStatus(
      currentVersion: currentVersion,
      requirement: clearRequirement ? null : requirement ?? this.requirement,
    );
  }

  @override
  List<Object?> get props => [currentVersion, requirement];
}
