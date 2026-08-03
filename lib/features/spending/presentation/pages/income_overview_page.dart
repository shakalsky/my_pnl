import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/generate_due_recurring_income.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_overview_body.dart';

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
          kind: CategoryKind.income,
        )..add(const SpendingOverviewSubscriptionRequested());
      },
      child: const IncomeOverviewView(),
    );
  }
}

class IncomeOverviewView extends StatelessWidget {
  const IncomeOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<SpendingOverviewBloc, SpendingOverviewState>(
            builder: (context, state) {
              return switch (state.status) {
                SpendingOverviewStatus.initial ||
                SpendingOverviewStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                SpendingOverviewStatus.failure => const Center(
                  child: Text('Could not load your income'),
                ),
                SpendingOverviewStatus.success => CategoryOverviewBody(
                  state: state,
                  kind: CategoryKind.income,
                  totalLabel: 'Total income',
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}
