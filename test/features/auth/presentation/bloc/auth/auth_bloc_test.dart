import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/presentation/bloc/auth/auth_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _user = AuthUser(id: 'user-1', email: 'a@b.com');

void main() {
  group('AuthBloc', () {
    late FakeAuthRepository repository;

    setUp(() => repository = FakeAuthRepository());
    tearDown(() => repository.close());

    test('starts unknown so routing does not bounce on a cold start', () {
      final bloc = AuthBloc(authRepository: repository);
      expect(bloc.state.status, AuthStatus.unknown);
      expect(bloc.state.user, isNull);
    });

    blocTest<AuthBloc, AuthState>(
      'reports unauthenticated when there is no session',
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
      expect: () => const <AuthState>[AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'reports the restored session',
      build: () => AuthBloc(
        authRepository: FakeAuthRepository(initialUser: _user),
      ),
      act: (bloc) => bloc.add(const AuthSubscriptionRequested()),
      expect: () => const <AuthState>[AuthState.authenticated(_user)],
    );

    blocTest<AuthBloc, AuthState>(
      'follows sign-in and sign-out',
      build: () => AuthBloc(authRepository: repository),
      act: (bloc) async {
        bloc.add(const AuthSubscriptionRequested());
        await pumpEventQueue();
        await repository.signIn(email: 'a@b.com', password: 'secret1');
        await pumpEventQueue();
        bloc.add(const AuthSignOutRequested());
      },
      expect: () => const <AuthState>[
        AuthState.unauthenticated(),
        AuthState.authenticated(_user),
        AuthState.unauthenticated(),
      ],
    );
  });
}
