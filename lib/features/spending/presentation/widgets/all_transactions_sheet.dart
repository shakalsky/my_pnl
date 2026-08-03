import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_all_entries.dart';
import 'package:my_pnl/features/spending/presentation/bloc/all_transactions/all_transactions_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/amount_entry_sheet.dart';

/// Every entry across every category, newest first.
///
/// Tap to correct an amount, the bin to remove one. The per-category history
/// does the same for one category; this is the whole ledger.
class AllTransactionsSheet extends StatelessWidget {
  const AllTransactionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final repository = context.read<TransactionRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) =>
            AllTransactionsBloc(
              watchAllEntries: WatchAllEntries(repository),
              deleteSpend: DeleteSpend(repository),
            )..add(const AllTransactionsSubscriptionRequested()),
        child: const AllTransactionsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<AllTransactionsBloc, AllTransactionsState>(
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
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'All transactions',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Newest first',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatAmount(state.netScaled),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Capped so a long ledger scrolls inside the modal rather than
              // pushing it off the top.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: switch (state.status) {
                  AllTransactionsStatus.initial ||
                  AllTransactionsStatus.loading => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  AllTransactionsStatus.failure => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Could not load transactions')),
                  ),
                  AllTransactionsStatus.success => _EntryList(
                    entries: state.entries,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Nothing recorded yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat.yMMMd().add_jm();

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = entries[index];
        final category = item.category;
        final amount = item.entry.amountScaled;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => _edit(context, item),
          leading: CircleAvatar(
            backgroundColor: category == null
                ? theme.colorScheme.surfaceContainerHighest
                : Color(category.colorArgb),
            child: Icon(
              category == null
                  ? Icons.help_outline
                  : iconForKey(category.iconKey),
              size: 18,
              color: category == null
                  ? theme.colorScheme.onSurfaceVariant
                  : Colors.white,
            ),
          ),
          title: Text(category?.name ?? 'Uncategorised'),
          // Stored in UTC, shown in the reader's zone.
          subtitle: Text(dateFormat.format(item.entry.occurredAt.toLocal())),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatAmount(amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  // Income reads as a gain, spending as a cost.
                  color: amount < 0
                      ? theme.colorScheme.onSurface
                      : const Color(0xFF2E7D32),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final bloc = context.read<AllTransactionsBloc>();
                  if (await _confirmDelete(context, item) ?? false) {
                    bloc.add(AllTransactionsEntryDeleted(item.entry.id));
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete entry',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, LedgerEntry item) {
    // An entry whose category was deleted still has an amount worth
    // correcting, so it gets a stand-in for the header rather than no edit.
    final category =
        item.category ??
        const Category(
          id: '',
          name: 'Uncategorised',
          colorArgb: 0xFF56606B,
          iconKey: 'unknown',
        );

    return AmountEntrySheet.showEdit(context, category, item.entry);
  }

  Future<bool?> _confirmDelete(BuildContext context, LedgerEntry item) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          '${formatAmount(item.entry.amountScaled)} will be removed from '
          '${item.category?.name ?? 'your totals'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
