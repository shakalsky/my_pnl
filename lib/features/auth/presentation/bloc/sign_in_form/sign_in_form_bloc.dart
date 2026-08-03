import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/domain/usecases/sign_in.dart';
import 'package:my_pnl/features/auth/domain/usecases/sign_up.dart';

part 'sign_in_form_event.dart';
part 'sign_in_form_state.dart';

/// Drives the sign-in page.
///
/// There is no success state: a successful sign-in changes the session, the
/// app-level `AuthBloc` picks that up, and the router moves off this. Leaving
/// navigation to the router keeps one source of truth for where the user is.
class SignInFormBloc extends Bloc<SignInFormEvent, SignInFormState> {
  SignInFormBloc({required AuthRepository authRepository})
    : _signIn = SignIn(authRepository),
      _signUp = SignUp(authRepository),
      super(const SignInFormState()) {
    on<SignInEmailChanged>(
      (event, emit) =>
          emit(state.copyWith(email: event.email, clearError: true)),
    );
    on<SignInPasswordChanged>(
      (event, emit) =>
          emit(state.copyWith(password: event.password, clearError: true)),
    );
    on<SignInModeToggled>(
      (event, emit) => emit(
        state.copyWith(
          mode: state.isSignUp ? SignInMode.signIn : SignInMode.signUp,
          status: SignInFormStatus.editing,
          clearError: true,
        ),
      ),
    );
    on<SignInSubmitted>(_onSubmitted);
  }

  final SignIn _signIn;
  final SignUp _signUp;

  Future<void> _onSubmitted(
    SignInSubmitted event,
    Emitter<SignInFormState> emit,
  ) async {
    if (!state.isValid || state.isSubmitting) return;

    emit(
      state.copyWith(status: SignInFormStatus.submitting, clearError: true),
    );

    try {
      if (state.isSignUp) {
        final outcome = await _signUp(
          email: state.email,
          password: state.password,
        );

        if (outcome == SignUpOutcome.confirmationRequired) {
          emit(
            state.copyWith(status: SignInFormStatus.awaitingConfirmation),
          );
          return;
        }
      } else {
        await _signIn(email: state.email, password: state.password);
      }
      // No success state on purpose — see the class doc.
      emit(state.copyWith(status: SignInFormStatus.editing));
    } on AuthFailure catch (e) {
      emit(
        state.copyWith(
          status: SignInFormStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }
}
