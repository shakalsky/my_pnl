part of 'sign_in_form_bloc.dart';

enum SignInMode { signIn, signUp }

enum SignInFormStatus {
  editing,
  submitting,
  failure,

  /// Account created, but the address has to be confirmed before there is a
  /// session. The user stays on this page with an explanation.
  awaitingConfirmation,
}

final class SignInFormState extends Equatable {
  const SignInFormState({
    this.email = '',
    this.password = '',
    this.mode = SignInMode.signIn,
    this.status = SignInFormStatus.editing,
    this.errorMessage,
  });

  final String email;
  final String password;
  final SignInMode mode;
  final SignInFormStatus status;
  final String? errorMessage;

  bool get isSignUp => mode == SignInMode.signUp;

  bool get isSubmitting => status == SignInFormStatus.submitting;

  /// Enough to enable the button. The use cases validate again, and the
  /// backend has the final say.
  bool get isValid =>
      isValidEmail(email) &&
      password.length >= (isSignUp ? minPasswordLength : 1);

  SignInFormState copyWith({
    String? email,
    String? password,
    SignInMode? mode,
    SignInFormStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SignInFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [email, password, mode, status, errorMessage];
}
