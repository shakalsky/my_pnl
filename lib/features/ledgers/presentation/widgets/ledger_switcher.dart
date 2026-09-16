import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/presentation/bloc/ledger/ledger_bloc.dart';
import 'package:my_pnl/features/ledgers/presentation/widgets/accounts_sheet.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Which book the page below is showing, and a way to change it.
///
/// Sits in the overview header ahead of the other actions, because it is the
/// thing every figure on the page depends on: a total read against the wrong
/// book is not a small mistake.
///
/// Always names the book rather than standing as a bare icon, even for a reader
/// with only one. A personal book and a family one are a tap apart and read the
/// same at a glance otherwise, and a name that appears only once a second book
/// exists teaches nothing about where the figures came from before that.
class LedgerSwitcher extends StatelessWidget {
  const LedgerSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<LedgerBloc, LedgerState>(
      builder: (context, state) {
        final active = state.active;
        // A family account earns a different icon whichever shape is showing:
        // the reader should be able to tell at a glance that the totals below
        // are two people's.
        final icon = (active?.isShared ?? false)
            ? Icons.people_outline
            : Icons.person_outline;

        return TextButton.icon(
          onPressed: () => AccountsSheet.show(context),
          icon: Icon(icon, size: 18),
          // No Flexible around this: `TextButton.icon` puts the label in one
          // already, and a second writes over the first's parent data. The
          // ellipsis is what keeps a long family name from pushing the actions
          // beside it off the row.
          label: Text(
            active?.name ?? '…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: theme.colorScheme.onSurface,
            // The header hands it the row's whole remainder, which is more than
            // most names need. Centred, the icon would drift away from the edge
            // it belongs to and sit at a different place on every account.
            alignment: Alignment.centerLeft,
          ),
        );
      },
    );
  }
}

/// One row of the switcher's list.
///
/// Pulled out because both the sheet's list and its empty state need the same
/// tile, and a family account with a partner in it says so on the same line.
class LedgerTile extends StatelessWidget {
  const LedgerTile({
    required this.ledger,
    required this.isActive,
    required this.viewerId,
    this.onTap,
    this.onRemove,
    super.key,
  });

  final Ledger ledger;
  final bool isActive;

  /// Who is reading, so the members can be described as "you and …" rather than
  /// listed back at the reader.
  final String viewerId;

  final VoidCallback? onTap;

  /// Null on a row that cannot be removed — a family account, which is left
  /// rather than removed, and the reader's first book, which has to stay.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partners = ledger.partnersOf(viewerId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: isActive ? null : onTap,
      leading: CircleAvatar(
        backgroundColor: isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          ledger.isFamily ? Icons.people_outline : Icons.person_outline,
          size: 18,
          color: isActive
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(ledger.name),
      subtitle: Text(switch (partners) {
        // A family account nobody has joined yet is still one person's, and
        // saying "shared with" would be a promise the code has not kept.
        [] when ledger.isFamily => t.accounts.tileNobodyJoined,
        [] => t.accounts.tileOnlyYou,
        [final one] => t.accounts.tileSharedWith(name: one.label),
        final many => t.accounts.tileSharedWithOthers(count: many.length),
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(Icons.check, size: 20, color: theme.colorScheme.primary),
          if (onRemove case final remove?)
            IconButton(
              onPressed: remove,
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: t.accounts.removeTooltip(name: ledger.name),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
