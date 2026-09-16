import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/generate_due_recurring_income.dart';
import 'package:my_pnl/features/spending/domain/usecases/reorder_categories.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/presentation/bloc/selected_month/selected_month_cubit.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_overview_body.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Income categories and their totals.
///
/// The same screen as the spending overview over the other side of the
/// ledger, so it shares the body and the bloc class.
class IncomeOverviewPage extends StatelessWidget {
  const IncomeOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<CategoryRepository>();

    return BlocProvider(
      create: (context) {
        // Catch up on any month that came due while the app was closed. Not
        // awaited on purpose: the watch stream picks the rows up as they
        // land, so the page renders immediately either way.
        unawaited(GenerateDueRecurringIncome(repository).call());

        return SpendingOverviewBloc(
          watchCategorySpend: WatchCategorySpend(repository),
          reorderCategories: ReorderCategories(repository),
          kind: CategoryKind.income,
          // The month both overviews share: this page is built as the reader
          // swipes to it, and it has to arrive on the month they were looking
          // at rather than on the current one.
          initialMonth: context.read<SelectedMonthCubit>().state,
        )..add(const SpendingOverviewSubscriptionRequested());
      },
      // Paging months on either overview writes to the shared month, which is
      // handed back to both pages here — so the two never disagree about which
      // month is on screen.
      child: BlocListener<SelectedMonthCubit, CalendarMonth>(
        listener: (context, month) => context.read<SpendingOverviewBloc>().add(
          SpendingOverviewMonthChanged(month),
        ),
        child: const IncomeOverviewView(),
      ),
    );
  }
}

class IncomeOverviewView extends StatelessWidget {
  const IncomeOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Laid out exactly as the spending page is, so the circle and the grid
        // stay put as the two slide past each other under the pinned toolbar.
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlocBuilder<SpendingOverviewBloc, SpendingOverviewState>(
            builder: (context, state) {
              return switch (state.status) {
                SpendingOverviewStatus.initial ||
                SpendingOverviewStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                SpendingOverviewStatus.failure => Center(
                  child: Text(t.income.loadFailed),
                ),
                SpendingOverviewStatus.success => CategoryOverviewBody(
                  state: state,
                  kind: CategoryKind.income,
                  totalLabel: t.income.totalLabel,
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}
