import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/domain/usecases/sign_out.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Holds the session for the whole app.
///
/// Lives above the router rather than on a page, because every page's presence
/// depends on it.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      _signOut = SignOut(authRepository),
      super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<AuthSignOutRequested>((event, emit) => _signOut());
  }

  final AuthRepository _authRepository;
  final SignOut _signOut;

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) {
    return emit.forEach<AuthUser?>(
      _authRepository.watchUser(),
      onData: (user) => user == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(user),
      // A failing auth stream is indistinguishable from being signed out, and
      // treating it as signed in would show a shell with no data behind it.
      onError: (_, _) => const AuthState.unauthenticated(),
    );
  }
}
