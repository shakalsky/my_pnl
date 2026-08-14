import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/bloc/sign_in_form/sign_in_form_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Email and password, in either sign-in or sign-up mode.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SignInFormBloc(authRepository: context.read<AuthRepository>()),
      child: const SignInView(),
    );
  }
}

/// Password entry with a reveal toggle, so a typo in a field nobody can read
/// is not the reason someone cannot get into their own account.
class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.onChanged, required this.onSubmitted});

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppInput.white(
      label: t.auth.password,
      obscureText: _obscured,
      autofillHints: const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      // The reveal toggle is the only affordance this field needs; a clear
      // button beside it would be two icons competing in the same corner.
      showClearButton: false,
      suffixIcon: IconButton(
        icon: Icon(
          _obscured ? Icons.visibility : Icons.visibility_off,
          size: 18,
        ),
        tooltip: _obscured ? t.auth.showPassword : t.auth.hidePassword,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}

class SignInView extends StatelessWidget {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<SignInFormBloc>();
    final state = context.watch<SignInFormBloc>().state;
    // Read rather than fetched: startup already asked the platform for this to
    // run the update gate, so the sign-in page has nothing left to await.
    final version = context.read<AppUpdateRepository>().status.currentVersion;

    // The confirmation step is the one outcome that leaves the user on this
    // page with nothing visibly changed, so it gets a snackbar as well as the
    // inline note below — the note stays put once the snackbar has gone.
    return BlocListener<SignInFormBloc, SignInFormState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == SignInFormStatus.awaitingConfirmation,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(t.auth.confirmSnack),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      state.isSignUp ? t.auth.signUpTitle : t.auth.signInTitle,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.auth.blurb,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    AppInput.white(
                      label: t.auth.email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => bloc.add(SignInEmailChanged(value)),
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      onChanged: (value) =>
                          bloc.add(SignInPasswordChanged(value)),
                      onSubmitted: (_) => bloc.add(const SignInSubmitted()),
                    ),
                    if (state.errorMessage case final message?) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    if (state.status ==
                        SignInFormStatus.awaitingConfirmation) ...[
                      const SizedBox(height: 12),
                      Text(
                        t.auth.confirmNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.isValid && !state.isSubmitting
                          ? () => bloc.add(const SignInSubmitted())
                          : null,
                      child: state.isSubmitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              state.isSignUp
                                  ? t.auth.signUpAction
                                  : t.auth.signInAction,
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () => bloc.add(const SignInModeToggled()),
                      child: Text(
                        state.isSignUp ? t.auth.toSignIn : t.auth.toSignUp,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Here rather than behind a settings screen: this is the one
                    // page a user can reach before signing in, which is where a
                    // bug report starts when they cannot get in at all.
                    Text(
                      t.auth.version(
                        label: version.label,
                        build: version.build,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
