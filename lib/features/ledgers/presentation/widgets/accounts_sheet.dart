import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/database/database.dart' show personalLedgerId;
import 'package:my_pnl/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/presentation/bloc/ledger/ledger_bloc.dart';
import 'package:my_pnl/features/ledgers/presentation/widgets/ledger_form_sheet.dart';
import 'package:my_pnl/features/ledgers/presentation/widgets/ledger_switcher.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Modal for switching between accounts, and for sharing one with a partner.
///
/// One sheet rather than several, because the reader arrives here with the same
/// question however many books they have — "whose spending am I looking at, and
/// who else can see it" — and the answer to the second half is what the first
/// half switches between.
///
/// Naming a new one happens in [LedgerFormSheet] rather than here: it is the one
/// choice the reader gets to make about a book, and it deserves more than a field
/// wedged in below a list.
///
/// Opened from [LedgerSwitcher], which provides the bloc, so this reads the list
/// the switcher was already showing rather than opening a second query for it.
class AccountsSheet extends StatelessWidget {
  const AccountsSheet({super.key});

  static Future<void> show(BuildContext context) {
    // The bloc comes from above rather than being created here: it lives on the
    // page, and a sheet that made its own would show a list built from a second
    // subscription — briefly empty, and out of step with the switcher behind it.
    final bloc = context.read<LedgerBloc>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const AccountsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewerId = context.watch<AuthBloc>().state.user?.id ?? '';
    // The one book that cannot be removed, worked out the same way every device
    // works it out.
    final firstPersonalId = personalLedgerId(viewerId);

    // Nothing here closes the sheet on a successful switch, and it does not need
    // to: the app shell rebuilds beneath itself when the ledger changes, which
    // takes this route with it. What is left to handle is the case where nothing
    // switched — a code that matched nothing, a join that has not synced yet —
    // and that is what the message is for.
    return BlocConsumer<LedgerBloc, LedgerState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage case final message?) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            // Lifts the sheet clear of the keyboard, which the two text fields
            // below bring up.
            bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.accounts.title, style: theme.textTheme.titleLarge),
                Text(
                  t.accounts.subtitle(count: LedgerLimits.personal),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final ledger in state.ledgers)
                  LedgerTile(
                    ledger: ledger,
                    isActive: ledger.id == state.activeId,
                    viewerId: viewerId,
                    onTap: state.busy
                        ? null
                        : () => context.read<LedgerBloc>().add(
                            LedgerSelected(ledger.id),
                          ),
                    // Only on the extra ones. The first book has no remove
                    // action because it cannot go — every fallback in the app
                    // lands on it.
                    onRemove:
                        ledger.isPersonal &&
                            ledger.id != firstPersonalId &&
                            !state.busy
                        ? () => _confirmRemove(context, ledger)
                        : null,
                  ),
                if (state.active case final active? when active.isFamily) ...[
                  const Divider(height: 24),
                  _InviteCode(ledger: active),
                  _Members(ledger: active, viewerId: viewerId),
                  _LeaveButton(ledger: active, busy: state.busy),
                ],
                const Divider(height: 24),
                _NewAccountButton(state: state),
                const SizedBox(height: 8),
                _JoinField(busy: state.busy, canJoin: state.canAddFamily),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Asks before discarding one of the reader's own books.
Future<void> _confirmRemove(BuildContext context, Ledger ledger) async {
  final bloc = context.read<LedgerBloc>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(t.accounts.removeTitle(name: ledger.name)),
      // Honest about what it does and does not do. The rows are not swept up —
      // every read narrows to a ledger, so a removed one simply stops being
      // reachable, and saying "hidden" is what makes that recoverable rather
      // than a promise nothing kept.
      content: Text(t.accounts.removeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(t.common.remove),
        ),
      ],
    ),
  );

  if (confirmed ?? false) bloc.add(LedgerDeleted(ledger.id));
}

/// Opens the form where a new account is named.
///
/// Disabled only when there is no room for either kind, and it says which —
/// a button that opened a form refusing both would be a wasted tap.
class _NewAccountButton extends StatelessWidget {
  const _NewAccountButton({required this.state});

  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = state.canAddPersonal || state.canAddFamily;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: room && !state.busy
                ? () => LedgerFormSheet.show(context)
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text(t.accounts.newAccount),
          ),
        ),
        if (!room)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t.accounts.noRoom(count: LedgerLimits.personal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The code a partner types to join, with a way to copy or replace it.
class _InviteCode extends StatelessWidget {
  const _InviteCode({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = ledger.inviteCode;

    if (code == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.accounts.inviteCode,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                code,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  // Wide enough to read out loud a character at a time, which is
                  // how most of these will actually be shared.
                  letterSpacing: 4,
                ),
              ),
            ),
            IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.accounts.codeCopied)),
                );
              },
              icon: const Icon(Icons.copy, size: 20),
              tooltip: t.accounts.copyCode,
            ),
            IconButton(
              onPressed: () => _confirmRotate(context),
              icon: const Icon(Icons.autorenew, size: 20),
              tooltip: t.accounts.newCode,
            ),
          ],
        ),
        Text(
          t.accounts.inviteWarning,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _confirmRotate(BuildContext context) async {
    final bloc = context.read<LedgerBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.accounts.rotateTitle),
        // Worth spelling out: this is the only way to take an invite back, and
        // it is also the only way to break one that has been shared already.
        content: Text(t.accounts.rotateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.accounts.newCode),
          ),
        ],
      ),
    );

    if (confirmed ?? false) bloc.add(LedgerInviteCodeRotated(ledger.id));
  }
}

/// Who can see this book.
class _Members extends StatelessWidget {
  const _Members({required this.ledger, required this.viewerId});

  final Ledger ledger;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.accounts.members,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final member in ledger.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.account_circle_outlined, size: 20),
            title: Text(
              member.userId == viewerId
                  ? t.accounts.memberYou(label: member.label)
                  : member.label,
            ),
            subtitle: Text(
              member.isOwner
                  ? t.accounts.memberOwner
                  : t.accounts.memberPartner,
            ),
          ),
      ],
    );
  }
}

/// Gives up access, with a warning about what stays behind.
class _LeaveButton extends StatelessWidget {
  const _LeaveButton({required this.ledger, required this.busy});

  final Ledger ledger;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: busy ? null : () => _confirmLeave(context),
        icon: const Icon(Icons.logout, size: 18),
        label: Text(t.accounts.leaveAction),
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final bloc = context.read<LedgerBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.accounts.leaveTitle(name: ledger.name)),
        // The entries stay, and that is worth saying: someone leaving expects
        // their spending to go with them, and it cannot — a partner is still
        // reading totals it is part of.
        content: Text(t.accounts.leaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.common.leave),
          ),
        ],
      ),
    );

    if (confirmed ?? false) bloc.add(LedgerLeft(ledger.id));
  }
}

/// Where a partner types the code they were given.
class _JoinField extends StatefulWidget {
  const _JoinField({required this.busy, required this.canJoin});

  final bool busy;

  /// False once the reader is already in a family account. Kept apart from
  /// [busy]: one is "wait a moment" and the other is "not until you leave the
  /// one you are in", and a spinner would say the wrong one.
  final bool canJoin;

  @override
  State<_JoinField> createState() => _JoinFieldState();
}

class _JoinFieldState extends State<_JoinField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    context.read<LedgerBloc>().add(LedgerJoinRequested(code));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.canJoin && !widget.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: enabled,
                // Codes are drawn from an upper-case alphabet, so a keyboard that
                // starts in lower case only makes the reader fight it.
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: t.accounts.joinLabel,
                  hintText: t.accounts.joinHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: enabled ? _submit : null,
              child: widget.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.common.join),
            ),
          ],
        ),
        // Left disabled with the reason under it rather than hidden: a reader
        // holding a code their partner just sent them needs to be told why it
        // will not go in, not left looking for where it went.
        if (!widget.canJoin)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t.accounts.joinBlocked,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
