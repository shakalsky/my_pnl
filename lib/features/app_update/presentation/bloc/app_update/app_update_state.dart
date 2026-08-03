part of 'app_update_bloc.dart';

final class AppUpdateState extends Equatable {
  const AppUpdateState({required this.status, this.isChecking = false});

  final AppUpdateStatus status;

  /// A check the user asked for is in flight.
  final bool isChecking;

  /// The version running now.
  AppVersion get currentVersion => status.currentVersion;

  UpdateRequirement? get requirement => status.requirement;

  bool get isUpdateRequired => status.isUpdateRequired;

  AppUpdateState copyWith({AppUpdateStatus? status, bool? isChecking}) {
    return AppUpdateState(
      status: status ?? this.status,
      isChecking: isChecking ?? this.isChecking,
    );
  }

  @override
  List<Object?> get props => [status, isChecking];
}
