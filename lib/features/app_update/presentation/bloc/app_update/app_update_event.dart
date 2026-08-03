part of 'app_update_bloc.dart';

sealed class AppUpdateEvent extends Equatable {
  const AppUpdateEvent();

  @override
  List<Object?> get props => [];
}

final class AppUpdateSubscriptionRequested extends AppUpdateEvent {
  const AppUpdateSubscriptionRequested();
}

/// The user asking whether the requirement still stands.
final class AppUpdateCheckRequested extends AppUpdateEvent {
  const AppUpdateCheckRequested();
}
