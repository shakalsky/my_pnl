import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/goals/domain/entities/investment_projection.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/goals/domain/usecases/clear_goal.dart';
import 'package:my_pnl/features/goals/domain/usecases/watch_goal.dart';
import 'package:my_pnl/features/goals/presentation/bloc/goal_overview/goal_overview_bloc.dart';
import 'package:my_pnl/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_monthly_pnl.dart';

/// What the good months add up to, against what the user is saving for.
class GoalPage extends StatelessWidget {
  const GoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = context.read<GoalRepository>();
    final transactions = context.read<TransactionRepository>();

    return BlocProvider(
      create: (_) =>
          GoalOverviewBloc(
              watchMonthlyPnl: WatchMonthlyPnl(transactions),
              watchGoal: WatchGoal(goals),
              clearGoal: ClearGoal(goals),
            )
            ..add(const GoalOverviewSubscriptionRequested())
            ..add(const GoalTargetSubscriptionRequested()),
      child: const GoalView(),
    );
  }
}

class GoalView extends StatelessWidget {
  const GoalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          BlocBuilder<GoalOverviewBloc, GoalOverviewState>(
            buildWhen: (previous, current) =>
                previous.hasGoal != current.hasGoal,
            builder: (context, state) {
              if (!state.hasGoal) return const SizedBox.shrink();

              return IconButton(
                onPressed: () async {
                  final bloc = context.read<GoalOverviewBloc>();
                  if (await _confirmClear(context) ?? false) {
                    bloc.add(const GoalCleared());
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Remove goal',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<GoalOverviewBloc, GoalOverviewState>(
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
              GoalOverviewStatus.initial ||
              GoalOverviewStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              GoalOverviewStatus.failure => const Center(
                child: Text('Could not load your months'),
              ),
              GoalOverviewStatus.success => _GoalBody(state: state),
            };
          },
        ),
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove your goal?'),
        content: const Text(
          'Your months stay exactly as they are — only the target goes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _GoalBody extends StatelessWidget {
  const _GoalBody({required this.state});

  final GoalOverviewState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProgressCard(state: state),
        // Nothing saved is nothing to project: a card of zeroes with a slider
        // that cannot move them off zero only reads as broken.
        if (state.savedScaled > 0) ...[
          const SizedBox(height: 12),
          _IfInvestedCard(state: state),
        ],
        const SizedBox(height: 24),
        _MonthsHeader(count: state.positiveMonths.length),
        if (state.positiveMonths.isEmpty)
          const _NoPositiveMonths()
        else
          for (final month in state.positiveMonths) _MonthTile(month: month),
        if (state.negativeMonths.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NegativeMonthsNote(
            count: state.negativeMonths.length,
            lostScaled: state.lostScaled,
          ),
        ],
      ],
    );
  }
}

/// The target, what has been put towards it, and the bar between them.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final GoalOverviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved from good months',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                formatAmount(state.savedScaled),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (!state.hasGoal)
              _NoGoalYet(savedScaled: state.savedScaled)
            else ...[
              const SizedBox(height: 4),
              Text(
                'of ${formatAmount(state.goal!.targetAmountScaled)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 14,
                  backgroundColor: colors.surfaceContainerHighest,
                  // Green-by-theme for a goal still running, and the tertiary
                  // colour once it is met, so "done" reads without the text.
                  color: state.isReached ? colors.tertiary : colors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.progressPercent}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    state.isReached
                        ? 'Goal reached'
                        : '${formatAmount(state.remainingScaled)} to go',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: state.isReached
                          ? colors.tertiary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      GoalFormSheet.show(context, initial: state.goal),
                  child: const Text('Edit goal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the saved total would earn a day if it were invested, and what it would
/// come to over the years.
///
/// Its own card rather than a line in the progress card: the figure above is
/// money that exists, and this one is a what-if at assumptions the reader
/// picked. Putting them in one box would blur which is which.
class _IfInvestedCard extends StatelessWidget {
  const _IfInvestedCard({required this.state});

  final GoalOverviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bloc = context.read<GoalOverviewBloc>();
    final projection = state.projection;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'If invested',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Icons.savings_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatAmount(state.dailyProfitLaterScaled),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.tertiary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'a day',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              // Which day that is, and what has happened by then. Compounding
              // is the whole reason the figure is worth reading: the day's rate
              // never changes, but by then it applies to a much larger balance.
              // Kept to one line — the months below are what the page is for.
              '${_years(projection.years)} on, with '
              '${formatAmount(state.totalLaterScaled)} in the pot',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _AssumptionSlider(
              label: 'Return',
              value: '${projection.annualPercent}% a year',
              current: projection.annualPercent,
              min: InvestmentProjection.minPercent,
              max: InvestmentProjection.maxPercent,
              onChanged: (percent) => bloc.add(GoalReturnRateChanged(percent)),
            ),
            _AssumptionSlider(
              label: 'Left alone for',
              value: _years(projection.years),
              current: projection.years,
              min: InvestmentProjection.minYears,
              max: InvestmentProjection.maxYears,
              onChanged: (years) => bloc.add(GoalProjectionYearsChanged(years)),
            ),
          ],
        ),
      ),
    );
  }

  static String _years(int years) => years == 1 ? '1 year' : '$years years';
}

/// One assumption behind the projection: what it is worth now, and a track to
/// move it along.
///
/// The figure sits above the track rather than only in the slider's own bubble,
/// which is only visible mid-drag — the reader needs to know what is assumed
/// without touching anything.
class _AssumptionSlider extends StatelessWidget {
  const _AssumptionSlider({
    required this.label,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String value;
  final int current;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        // Trimmed padding: the default slider pads itself out to a 48px row, and
        // two of those turn this card into a screenful on a small phone. The
        // track and thumb keep their own sizes, so it is still easy to hit.
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
          child: Slider(
            value: current.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            // Whole steps, so the figure above is one someone could have meant
            // rather than 7.4% or 22.6 years.
            divisions: max - min,
            label: value,
            onChanged: (moved) => onChanged(moved.round()),
          ),
        ),
      ],
    );
  }
}

class _NoGoalYet extends StatelessWidget {
  const _NoGoalYet({required this.savedScaled});

  final int savedScaled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          savedScaled > 0
              ? 'Set a target and this becomes progress towards it.'
              : 'Set a target, then every month you finish up counts '
                    'towards it.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => GoalFormSheet.show(context),
            child: const Text('Set a goal'),
          ),
        ),
      ],
    );
  }
}

class _MonthsHeader extends StatelessWidget {
  const _MonthsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            'Months you finished up',
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

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.month});

  final MonthlyPnl month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.trending_up,
          size: 18,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(DateFormat.yMMMM().format(month.startsOn)),
      subtitle: const Text('Income over spending'),
      trailing: Text(
        // Signed on purpose: a bare figure in a list of months reads as a
        // balance rather than what the month added.
        '+${formatAmount(month.netScaled)}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _NoPositiveMonths extends StatelessWidget {
  const _NoPositiveMonths();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'No month has finished up yet. A month counts once its income beats '
        'its spending.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Says what the progress figure leaves out.
///
/// Without this the total reads as money in the bank, when a month that ended
/// down has already spent some of it.
class _NegativeMonthsNote extends StatelessWidget {
  const _NegativeMonthsNote({required this.count, required this.lostScaled});

  final int count;

  /// Negative, as stored.
  final int lostScaled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${count == 1 ? '1 month' : '$count months'} ended down, '
            '${formatAmount(lostScaled.abs())} in total. Those are left out of '
            'the figure above.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
