import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/debts/domain/usecases/delete_debt.dart';
import 'package:my_pnl/features/debts/domain/usecases/mark_debt_settled.dart';
import 'package:my_pnl/features/debts/domain/usecases/watch_debts.dart';
import 'package:my_pnl/features/debts/presentation/bloc/debt_list/debt_list_bloc.dart';
import 'package:my_pnl/features/debts/presentation/widgets/debt_form_sheet.dart';

/// What the user owes and what is owed to them.
class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<DebtRepository>();

    return BlocProvider(
      create: (_) =>
          DebtListBloc(
            watchDebts: WatchDebts(repository),
            deleteDebt: DeleteDebt(repository),
            markDebtSettled: MarkDebtSettled(repository),
          )..add(const DebtListSubscriptionRequested()),
      child: const DebtsView(),
    );
  }
}

class DebtsView extends StatelessWidget {
  const DebtsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => DebtFormSheet.showCreate(context),
        tooltip: 'Add debt',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: BlocConsumer<DebtListBloc, DebtListState>(
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
            return switch (state.status) {
              DebtListStatus.initial ||
              DebtListStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              DebtListStatus.failure => const Center(
                child: Text('Could not load your debts'),
              ),
              DebtListStatus.success => _DebtsBody(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _DebtsBody extends StatelessWidget {
  const _DebtsBody({required this.state});

  final DebtListState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Bottom padding clears the floating action button, which would
      // otherwise sit on top of the last tile.
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
      children: [
        _Totals(state: state),
        const SizedBox(height: 20),
        if (state.hasNoDebts) const _NoDebtsYet(),
        ..._section('They owe you', state.owedToMe),
        ..._section('You owe', state.owedByMe),
        ..._section('Settled', state.settled),
      ],
    );
  }

  /// A header and its tiles, or nothing at all when the group is empty — an
  /// empty heading reads as a loading failure.
  List<Widget> _section(String title, List<Debt> debts) {
    if (debts.isEmpty) return const [];

    return [
      _SectionHeader(title: title, count: debts.length),
      for (final debt in debts) _DebtTile(debt: debt),
      const SizedBox(height: 12),
    ];
  }
}

/// The two open sides, and where they leave the user.
class _Totals extends StatelessWidget {
  const _Totals({required this.state});

  final DebtListState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final net = state.netTotalScaled;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: 'Owed to you',
                    amountScaled: state.owedToMeTotalScaled,
                    color: colors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: colors.outlineVariant,
                ),
                Expanded(
                  child: _Figure(
                    label: 'Owed by you',
                    amountScaled: state.owedByMeTotalScaled,
                    color: colors.error,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              // Spelt out rather than labelled "net": a signed figure on its
              // own leaves the reader working out which way it points.
              switch (net) {
                0 => 'You are square',
                > 0 => 'You are owed ${formatAmount(net)} overall',
                _ => 'You owe ${formatAmount(net.abs())} overall',
              },
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amountScaled,
    required this.color,
  });

  final String label;
  final int amountScaled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            formatAmount(amountScaled),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overdue = debt.isOverdue(DateTime.now());

    final amountColor = switch (debt) {
      final d when d.isSettled => colors.onSurfaceVariant,
      final d when d.isOwedToMe => colors.primary,
      _ => colors.error,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => DebtFormSheet.showEdit(context, debt),
      leading: CircleAvatar(
        backgroundColor: debt.isSettled
            ? colors.surfaceContainerHighest
            : debt.isOwedToMe
            ? colors.primaryContainer
            : colors.errorContainer,
        child: debt.isSettled
            ? Icon(Icons.check, size: 18, color: colors.onSurfaceVariant)
            : Icon(
                debt.isOwedToMe ? Icons.call_received : Icons.call_made,
                size: 18,
                color: debt.isOwedToMe
                    ? colors.onPrimaryContainer
                    : colors.onErrorContainer,
              ),
      ),
      title: Text(debt.counterparty),
      subtitle: Text(_subtitle(overdue: overdue)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatAmount(debt.amountScaled),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: amountColor,
              decoration: debt.isSettled ? TextDecoration.lineThrough : null,
            ),
          ),
          _DebtMenu(debt: debt),
        ],
      ),
      // Only the date turns red: colouring the whole row would compete with
      // the direction, which is the more important thing to read at a glance.
      subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
        color: overdue ? colors.error : colors.onSurfaceVariant,
      ),
    );
  }

  /// The note and the date that matters, whichever that is.
  String _subtitle({required bool overdue}) {
    final dateFormat = DateFormat.yMMMd();
    final parts = <String>[
      ?debt.note,
      if (debt.settledAt case final settledAt?)
        'Settled ${dateFormat.format(settledAt.toLocal())}'
      else if (debt.dueAt case final dueAt?)
        '${overdue ? 'Overdue' : 'Due'} ${dateFormat.format(dueAt.toLocal())}',
    ];

    // Something is always shown, so the tile does not change height depending
    // on whether a note was filled in.
    return parts.isEmpty
        ? (debt.isOwedToMe ? 'Owes you' : 'You owe them')
        : parts.join(' · ');
  }
}

class _DebtMenu extends StatelessWidget {
  const _DebtMenu({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DebtAction>(
      tooltip: 'Actions for ${debt.counterparty}',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) => _run(context, action),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: debt.isSettled ? _DebtAction.reopen : _DebtAction.settle,
          child: Text(debt.isSettled ? 'Reopen' : 'Mark settled'),
        ),
        const PopupMenuItem(value: _DebtAction.edit, child: Text('Edit')),
        const PopupMenuItem(value: _DebtAction.delete, child: Text('Delete')),
      ],
    );
  }

  Future<void> _run(BuildContext context, _DebtAction action) async {
    // Read before any await: the menu is gone by the time the dialog closes,
    // and with it the context that could find the bloc.
    final bloc = context.read<DebtListBloc>();

    switch (action) {
      case _DebtAction.settle:
        bloc.add(DebtSettleToggled(id: debt.id, settled: true));
      case _DebtAction.reopen:
        bloc.add(DebtSettleToggled(id: debt.id, settled: false));
      case _DebtAction.edit:
        await DebtFormSheet.showEdit(context, debt);
      case _DebtAction.delete:
        if (await _confirmDelete(context) ?? false) {
          bloc.add(DebtDeleted(debt.id));
        }
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete the debt with ${debt.counterparty}?'),
        content: Text(
          '${formatAmount(debt.amountScaled)} will stop being tracked. '
          'Nothing in your spending changes — a debt was never part of it.',
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

enum _DebtAction { settle, reopen, edit, delete }

class _NoDebtsYet extends StatelessWidget {
  const _NoDebtsYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.handshake_outlined,
            size: 40,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No debts yet',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Add what you owe and what people owe you. Debts are tracked '
            'here only — they never move your spending totals.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
