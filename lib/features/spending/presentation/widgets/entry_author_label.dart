import 'package:flutter/material.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';

/// Says who recorded an entry, when that was not the reader.
///
/// Renders nothing for your own entries, which is why it can be dropped into a
/// row without asking whether the ledger is shared. Two reasons it works that
/// way round: in a book nobody else is in, every row would otherwise carry the
/// same badge and it would say nothing; and in a shared one, the rows without a
/// name are yours by elimination — which is also the rule for which rows offer
/// an edit.
class EntryAuthorLabel extends StatelessWidget {
  const EntryAuthorLabel({required this.entry, super.key});

  final SpendEntry entry;

  @override
  Widget build(BuildContext context) {
    final name = entry.authorName;
    if (entry.isOwn || name == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text(
            name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
