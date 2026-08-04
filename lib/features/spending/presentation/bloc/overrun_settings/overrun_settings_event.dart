part of 'overrun_settings_bloc.dart';

sealed class OverrunSettingsEvent extends Equatable {
  const OverrunSettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Seeds the form with the settings in force.
final class OverrunSettingsRequested extends OverrunSettingsEvent {
  const OverrunSettingsRequested();
}

/// Turns the warning borders on or off altogether.
final class OverrunWarningsToggled extends OverrunSettingsEvent {
  const OverrunWarningsToggled({required this.on});

  final bool on;

  @override
  List<Object?> get props => [on];
}

/// Moves where one level starts.
final class OverrunThresholdChanged extends OverrunSettingsEvent {
  const OverrunThresholdChanged(this.level, this.percent);

  /// Which border colour is being set. [SpendOverrun.none] is not a level
  /// anyone can move and is ignored.
  final SpendOverrun level;

  /// Percentage of the usual month it should start at.
  final int percent;

  @override
  List<Object?> get props => [level, percent];
}

/// Puts every threshold back to what the app ships with.
final class OverrunSettingsRestored extends OverrunSettingsEvent {
  const OverrunSettingsRestored();
}

/// Writes the draft.
final class OverrunSettingsSubmitted extends OverrunSettingsEvent {
  const OverrunSettingsSubmitted();
}
