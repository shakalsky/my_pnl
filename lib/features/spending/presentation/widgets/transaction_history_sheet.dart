import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_history.dart';
import 'package:my_pnl/features/spending/presentation/bloc/transaction_history/transaction_history_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/amount_entry_sheet.dart';
import 'package:my_pnl/features/spending/presentation/widgets/day_divided_list.dart';
import 'package:my_pnl/features/spending/presentation/widgets/entry_author_label.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Modal listing what has been booked against a category.
class TransactionHistorySheet extends StatelessWidget {
  const TransactionHistorySheet({super.key});

  static Future<void> show(BuildContext context, Category category) {
    final repository = context.read<TransactionRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => TransactionHistoryBloc(
          watchCategoryHistory: WatchCategoryHistory(repository),
          deleteSpend: DeleteSpend(repository),
          category: category,
        )..add(const TransactionHistorySubscriptionRequested()),
        child: const TransactionHistorySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<TransactionHistoryBloc, TransactionHistoryState>(
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
        final category = state.category;

        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(category.colorArgb),
                    ),
                    child: Icon(
                      iconForKey(category.iconKey),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          category.name,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          t.entries.historyTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatAmount(state.totalScaled),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Caps the sheet at half the screen so a long history scrolls
              // inside the modal rather than pushing it off the top.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: switch (state.status) {
                  TransactionHistoryStatus.initial ||
                  TransactionHistoryStatus.loading => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  TransactionHistoryStatus.failure => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(t.entries.historyLoadFailed)),
                  ),
                  TransactionHistoryStatus.success => _HistoryList(
                    entries: state.entries,
                    category: category,
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

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries, required this.category});

  final List<SpendEntry> entries;
  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            t.entries.historyEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final rows = divideByDay(entries, (entry) => entry.occurredAt);

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
                _row(context, entry),
              ],
            );
        }
      },
    );
  }

  Widget _row(BuildContext context, SpendEntry entry) {
    final theme = Theme.of(context);

    // A partner's entry is read here but not written: only whoever recorded
    // one may change or remove it. The row is built without the swipe and
    // without the actions rather than with ones that would be refused on
    // upload.
    if (!entry.isOwn) {
      return _HistoryRow(entry: entry);
    }

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
      // Confirmed before the row animates away: deleting money by accident
      // is worse than one extra tap.
      confirmDismiss: (_) => _confirmDelete(context, entry),
      onDismissed: (_) => context.read<TransactionHistoryBloc>().add(
        TransactionHistoryEntryDeleted(entry.id),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => AmountEntrySheet.showEdit(context, category, entry),
        // Stored in UTC, shown in the reader's zone — and only the time of
        // day, the date having moved up into the heading over the day.
        title: Text(DateFormat.jm().format(entry.occurredAt.toLocal())),
        subtitle: entry.note == null ? null : Text(entry.note!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatAmount(entry.amountScaled),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // Swiping is not discoverable, and is awkward inside a
            // scrollable sheet, so the same action gets a button.
            IconButton(
              onPressed: () async {
                final bloc = context.read<TransactionHistoryBloc>();
                if (await _confirmDelete(context, entry) ?? false) {
                  bloc.add(TransactionHistoryEntryDeleted(entry.id));
                }
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: t.entries.deleteTooltip,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, SpendEntry entry) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.entries.deleteTitle),
        content: Text(
          t.entries.deleteBodyCategory(
            amount: formatAmount(entry.amountScaled),
            category: category.name,
          ),
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

/// A partner's entry: the same row without the actions.
///
/// A separate widget rather than a pile of conditionals inside the one above,
/// because what changes is the structure and not a few properties — there is no
/// [Dismissible] wrapping it, no tap, and no bin. Read-only is the whole shape of
/// it, and writing it out says so more plainly than three ternaries would.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final SpendEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      // Stored in UTC, shown in the reader's zone — and only the time of day,
      // the date having moved up into the heading over the day.
      title: Text(DateFormat.jm().format(entry.occurredAt.toLocal())),
      subtitle: Row(
        children: [
          EntryAuthorLabel(entry: entry),
          if (entry.note case final note?)
            Expanded(
              child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
      trailing: Text(
        formatAmount(entry.amountScaled),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          // Dimmed a shade: it counts towards the total above like any other
          // amount, but it is not one this reader can do anything about.
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
