part of 'sync_indicator_bloc.dart';

sealed class SyncIndicatorEvent extends Equatable {
  const SyncIndicatorEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching sync state.
final class SyncIndicatorSubscriptionRequested extends SyncIndicatorEvent {
  const SyncIndicatorSubscriptionRequested();
}
