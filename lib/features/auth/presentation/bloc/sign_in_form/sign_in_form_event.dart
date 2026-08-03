part of 'sign_in_form_bloc.dart';

sealed class SignInFormEvent extends Equatable {
  const SignInFormEvent();

  @override
  List<Object?> get props => [];
}

final class SignInEmailChanged extends SignInFormEvent {
  const SignInEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class SignInPasswordChanged extends SignInFormEvent {
  const SignInPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Switches between signing in and creating an account.
final class SignInModeToggled extends SignInFormEvent {
  const SignInModeToggled();
}

final class SignInSubmitted extends SignInFormEvent {
  const SignInSubmitted();
}
