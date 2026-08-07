import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pnl/app/routing/app_router.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_list_sheet.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:my_pnl/features/spending/domain/usecases/reorder_categories.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_spend_baselines.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/account_button.dart';
import 'package:my_pnl/features/spending/presentation/widgets/all_transactions_sheet.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_overview_body.dart';
import 'package:my_pnl/features/spending/presentation/widgets/overrun_settings_sheet.dart';
import 'package:my_pnl/features/sync/presentation/widgets/sync_indicator.dart';

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
        // The grid runs to the bottom of the screen, and the home indicator
        // sits over the gap the page's own padding already leaves — insetting
        // for it as well only wastes a row of tiles' worth of height.
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SyncIndicator(),
                  const Spacer(),
                  IconButton(
                    onPressed: () => AllTransactionsSheet.show(context),
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    tooltip: 'All transactions',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => context.pushNamed(AppRoute.debts.name),
                    icon: const Icon(Icons.handshake_outlined, size: 20),
                    tooltip: 'Debts',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => context.pushNamed(AppRoute.goal.name),
                    icon: const Icon(Icons.flag_outlined, size: 20),
                    tooltip: 'Goal',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => CurrencyListSheet.show(context),
                    icon: const Icon(Icons.currency_exchange, size: 20),
                    tooltip: 'Currencies',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => OverrunSettingsSheet.show(context),
                    icon: const Icon(Icons.warning_amber_rounded, size: 20),
                    tooltip: 'Unusual months',
                    visualDensity: VisualDensity.compact,
                  ),
                  const Flexible(child: AccountButton()),
                ],
              ),
              Expanded(
                child: BlocBuilder<SpendingOverviewBloc, SpendingOverviewState>(
                  builder: (context, state) {
                    return switch (state.status) {
                      SpendingOverviewStatus.initial ||
                      SpendingOverviewStatus.loading => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      SpendingOverviewStatus.failure => const Center(
                        child: Text('Could not load your spending'),
                      ),
                      SpendingOverviewStatus.success => CategoryOverviewBody(
                        state: state,
                        kind: CategoryKind.expense,
                        // Just what went out: this page's own categories added
                        // up, which is what the ring below is drawn from too. A
                        // net figure over a grid of spending reads as though the
                        // tiles made it, and what is left after income is the
                        // goal page's business.
                        totalLabel: 'Spending',
                      ),
                    };
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
