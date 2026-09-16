import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:my_pnl/features/spending/domain/usecases/reorder_categories.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_spend_baselines.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_overview_body.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Total spend up top, categories in a grid beneath it.
class SpendingOverviewPage extends StatelessWidget {
  const SpendingOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SpendingOverviewBloc(
              watchCategorySpend: WatchCategorySpend(
                context.read<CategoryRepository>(),
              ),
              // Only the spending page: a month of income above the usual is
              // not something to warn anybody about.
              watchSpendBaselines: WatchSpendBaselines(
                context.read<CategoryRepository>(),
              ),
              watchOverrunSettings: WatchOverrunSettings(
                context.read<OverrunSettingsStore>(),
              ),
              reorderCategories: ReorderCategories(
                context.read<CategoryRepository>(),
              ),
            )
            // No net total: the headline is what this page's own categories add
            // up to, and nothing here shows income against spending.
            ..add(const SpendingOverviewSubscriptionRequested())
            ..add(const SpendingOverviewBaselinesRequested())
            ..add(const SpendingOverviewSettingsRequested()),
      child: const SpendingOverviewView(),
    );
  }
}

class SpendingOverviewView extends StatelessWidget {
  const SpendingOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // The grid runs all the way to the bottom of the screen: neither the
        // system inset nor the page's own padding is worth a row of tiles'
        // worth of height, and the home indicator sits over the gap the last
        // row's spacing already leaves.
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
                  child: Text(t.spending.loadFailed),
                ),
                SpendingOverviewStatus.success => CategoryOverviewBody(
                  state: state,
                  kind: CategoryKind.expense,
                  // Just what went out: this page's own categories added up,
                  // which is what the ring below is drawn from too. A net figure
                  // over a grid of spending reads as though the tiles made it,
                  // and what is left after income is the goal page's business.
                  totalLabel: t.spending.totalLabel,
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}
