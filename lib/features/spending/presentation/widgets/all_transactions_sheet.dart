import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_all_entries.dart';
import 'package:my_pnl/features/spending/presentation/bloc/all_transactions/all_transactions_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/amount_entry_sheet.dart';
import 'package:my_pnl/features/spending/presentation/widgets/day_divided_list.dart';
import 'package:my_pnl/features/spending/presentation/widgets/entry_author_label.dart';
import 'package:my_pnl/i18n/strings.g.dart';

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
        create: (_) => AllTransactionsBloc(
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
                          t.entries.allTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          t.entries.newestFirst,
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
                  AllTransactionsStatus.failure => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(t.entries.loadFailed)),
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
            t.entries.empty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // The date lives in the day heading now, so the row keeps only the time of
    // day, which is what orders one entry against another within a day.
    final timeFormat = DateFormat.jm();
    final rows = divideByDay(entries, (item) => item.entry.occurredAt);

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        switch (rows[index]) {
          case DayHeadingRow(:final day):
            return DayHeading(day: day, first: index == 0);
          case DayEntryRow(:final entry, :final opensDay):
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!opensDay) const Divider(height: 1),
                _tile(context, entry, timeFormat),
              ],
            );
        }
      },
    );
  }

  Widget _tile(BuildContext context, LedgerEntry item, DateFormat timeFormat) {
    final theme = Theme.of(context);
    final category = item.category;
    final amount = item.entry.amountScaled;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      // A partner's entry is read here but not written: only whoever
      // recorded one may change it, so no edit is offered rather than one
      // that the server would refuse on upload.
      onTap: item.entry.isOwn ? () => _edit(context, item) : null,
      leading: CircleAvatar(
        backgroundColor: category == null
            ? theme.colorScheme.surfaceContainerHighest
            : Color(category.colorArgb),
        child: Icon(
          category == null ? Icons.help_outline : iconForKey(category.iconKey),
          size: 18,
          color: category == null
              ? theme.colorScheme.onSurfaceVariant
              : Colors.white,
        ),
      ),
      title: Text(category?.name ?? t.entries.uncategorised),
      // Stored in UTC, shown in the reader's zone. The entry's own note
      // rides along on the same line — it is what tells two amounts in the
      // same category apart — and in a family account a partner's name leads
      // it, which is what makes a total anyone can see legible as a total two
      // people made.
      subtitle: Row(
        children: [
          EntryAuthorLabel(entry: item.entry),
          Expanded(
            child: Text(
              switch (item.entry.note) {
                null => timeFormat.format(item.entry.occurredAt.toLocal()),
                final note =>
                  '${timeFormat.format(item.entry.occurredAt.toLocal())}'
                      ' · $note',
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
                  : AppSemanticColors.of(context).positive,
            ),
          ),
          IconButton(
            // Disabled rather than hidden on a partner's entry: the row
            // still has to line up with the ones above and below it, and a
            // greyed bin says "not yours" where a gap would just look like
            // a rendering fault.
            onPressed: item.entry.isOwn
                ? () async {
                    final bloc = context.read<AllTransactionsBloc>();
                    if (await _confirmDelete(context, item) ?? false) {
                      bloc.add(AllTransactionsEntryDeleted(item.entry.id));
                    }
                  }
                : null,
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: item.entry.isOwn
                ? t.entries.deleteTooltip
                : t.entries.onlyAuthorCanChange(
                    who: item.entry.authorName ?? t.entries.authorFallback,
                  ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, LedgerEntry item) {
    // An entry whose category was deleted still has an amount worth
    // correcting, so it gets a stand-in for the header rather than no edit.
    final category =
        item.category ??
        Category(
          id: '',
          name: t.entries.uncategorised,
          colorArgb: 0xFF56606B,
          iconKey: 'unknown',
        );

    return AmountEntrySheet.showEdit(context, category, item.entry);
  }

  Future<bool?> _confirmDelete(BuildContext context, LedgerEntry item) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.entries.deleteTitle),
        content: Text(
          switch (item.category?.name) {
            final name? => t.entries.deleteBodyCategory(
              amount: formatAmount(item.entry.amountScaled),
              category: name,
            ),
            null => t.entries.deleteBodyTotals(
              amount: formatAmount(item.entry.amountScaled),
            ),
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }
}
