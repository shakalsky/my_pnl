import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/bloc/sign_in_form/sign_in_form_bloc.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  group('SignInFormBloc', () {
    late FakeAuthRepository repository;

    setUp(() => repository = FakeAuthRepository());
    tearDown(() => repository.close());

    SignInFormBloc build() => SignInFormBloc(authRepository: repository);

    blocTest<SignInFormBloc, SignInFormState>(
      'rejects a malformed email',
      build: build,
      act: (bloc) => bloc
        ..add(const SignInEmailChanged('not-an-email'))
        ..add(const SignInPasswordChanged('secret1')),
      verify: (bloc) => expect(bloc.state.isValid, isFalse),
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'accepts any non-empty password when signing in',
      build: build,
      act: (bloc) => bloc
        ..add(const SignInEmailChanged('a@b.com'))
        ..add(const SignInPasswordChanged('x')),
      verify: (bloc) => expect(bloc.state.isValid, isTrue),
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'requires a longer password when signing up',
      build: build,
      act: (bloc) => bloc
        ..add(const SignInEmailChanged('a@b.com'))
        ..add(const SignInPasswordChanged('x'))
        ..add(const SignInModeToggled()),
      verify: (bloc) {
        expect(bloc.state.isSignUp, isTrue);
        expect(bloc.state.isValid, isFalse);
      },
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'ignores submit while invalid',
      build: build,
      act: (bloc) => bloc.add(const SignInSubmitted()),
      expect: () => const <SignInFormState>[],
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'signs in with the trimmed email',
      build: build,
      act: (bloc) => bloc
        ..add(const SignInEmailChanged('  a@b.com  '))
        ..add(const SignInPasswordChanged('secret1'))
        ..add(const SignInSubmitted()),
      verify: (bloc) {
        expect(repository.lastEmail, 'a@b.com');
        expect(repository.signUpCalled, isFalse);
        expect(bloc.state.errorMessage, isNull);
      },
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'creates an account in sign-up mode',
      build: build,
      act: (bloc) => bloc
        ..add(const SignInModeToggled())
        ..add(const SignInEmailChanged('a@b.com'))
        ..add(const SignInPasswordChanged('secret1'))
        ..add(const SignInSubmitted()),
      verify: (bloc) => expect(repository.signUpCalled, isTrue),
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'says so when the account needs email confirmation',
      build: () {
        repository.signUpOutcome = SignUpOutcome.confirmationRequired;
        return build();
      },
      act: (bloc) => bloc
        ..add(const SignInModeToggled())
        ..add(const SignInEmailChanged('a@b.com'))
        ..add(const SignInPasswordChanged('secret1'))
        ..add(const SignInSubmitted()),
      verify: (bloc) {
        expect(bloc.state.status, SignInFormStatus.awaitingConfirmation);
        expect(bloc.state.errorMessage, isNull);
      },
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'surfaces the failure message and stays on the form',
      build: () {
        repository.failure = const AuthFailure('Invalid login credentials');
        return build();
      },
      act: (bloc) => bloc
        ..add(const SignInEmailChanged('a@b.com'))
        ..add(const SignInPasswordChanged('wrong'))
        ..add(const SignInSubmitted()),
      verify: (bloc) {
        expect(bloc.state.status, SignInFormStatus.failure);
        expect(bloc.state.errorMessage, 'Invalid login credentials');
        expect(bloc.state.email, 'a@b.com', reason: 'input survives');
      },
    );

    blocTest<SignInFormBloc, SignInFormState>(
      'clears the error once the user edits again',
      build: () {
        repository.failure = const AuthFailure('Invalid login credentials');
        return build();
      },
      act: (bloc) async {
        bloc
          ..add(const SignInEmailChanged('a@b.com'))
          ..add(const SignInPasswordChanged('wrong'))
          ..add(const SignInSubmitted());
        await pumpEventQueue();
        bloc.add(const SignInPasswordChanged('wrong2'));
      },
      verify: (bloc) => expect(bloc.state.errorMessage, isNull),
    );
  });
}
