part of 'overrun_settings_bloc.dart';

enum OverrunSettingsStatus { editing, submitting, success, failure }

final class OverrunSettingsState extends Equatable {
  const OverrunSettingsState({
    this.settings = OverrunSettings.defaults,
    this.status = OverrunSettingsStatus.editing,
    this.errorMessage,
  });

  /// The draft being edited. Nothing is written until it is submitted.
  final OverrunSettings settings;

  final OverrunSettingsStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == OverrunSettingsStatus.submitting;

  /// Whether the draft is already what the app ships with, which is what greys
  /// out the reset.
  bool get isDefault => settings == OverrunSettings.defaults;

  OverrunSettingsState copyWith({
    OverrunSettings? settings,
    OverrunSettingsStatus? status,
    String? errorMessage,
  }) {
    return OverrunSettingsState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
      // Cleared on any other change: an error about the last attempt has
      // nothing to say about a draft that has since moved on.
      errorMessage: status == OverrunSettingsStatus.failure
          ? errorMessage ?? this.errorMessage
          : null,
    );
  }

  @override
  List<Object?> get props => [settings, status, errorMessage];
}
