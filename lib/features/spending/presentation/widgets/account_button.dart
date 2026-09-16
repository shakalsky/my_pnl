import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Signs the current user out.
///
/// Renders nothing for the local-only user: there is no sign-in behind it to
/// undo. Which book is open is a different question, answered by the switcher at
/// the other end of the row, so nothing is named here.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;

    if (user == null || !user.isRemote) return const SizedBox.shrink();

    return IconButton(
      onPressed: () => _confirmSignOut(context),
      icon: const Icon(Icons.logout, size: 18),
      tooltip: t.account.signOut,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final bloc = context.read<AuthBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.account.signOutTitle),
        // Worth spelling out: PowerSync clears the local copy on sign-out, so
        // anything that never reached the server is gone.
        content: Text(t.account.signOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.account.signOut),
          ),
        ],
      ),
    );

    if (confirmed ?? false) bloc.add(const AuthSignOutRequested());
  }
}
