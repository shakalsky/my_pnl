import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pnl/app/routing/app_router.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/create_family_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/create_personal_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/delete_personal_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/join_family_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/leave_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/rotate_invite_code.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/select_ledger.dart';
import 'package:my_pnl/features/ledgers/domain/usecases/watch_ledgers.dart';
import 'package:my_pnl/features/ledgers/presentation/bloc/ledger/ledger_bloc.dart';
import 'package:my_pnl/features/ledgers/presentation/widgets/ledger_switcher.dart';
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
import 'package:my_pnl/features/sync/presentation/widgets/sync_indicator.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Total spend up top, categories in a grid beneath it.
class SpendingOverviewPage extends StatelessWidget {
  const SpendingOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ledgers = context.read<LedgerRepository>();

    return MultiBlocProvider(
      providers: [
        // The switcher in the header, and the sheet it opens. Provided by this
        // page rather than by the pager above it, because this is the page that
        // shows it — and a page that provides what it needs is one a test can
        // pump on its own.
        BlocProvider(
          create: (_) => LedgerBloc(
            watchLedgers: WatchLedgers(ledgers),
            activeId: ledgers.activeId,
            selectLedger: SelectLedger(ledgers),
            createPersonalLedger: CreatePersonalLedger(ledgers),
            createFamilyLedger: CreateFamilyLedger(ledgers),
            joinFamilyLedger: JoinFamilyLedger(ledgers),
            leaveLedger: LeaveLedger(ledgers),
            deletePersonalLedger: DeletePersonalLedger(ledgers),
            rotateInviteCode: RotateInviteCode(ledgers),
          )..add(const LedgerSubscriptionRequested()),
        ),
        BlocProvider(
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
        ),
      ],
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
                  // Ahead of everything else, and flexible so the icons keep
                  // their room: which book is open is what every figure below
                  // depends on, and a total read against the wrong one is not a
                  // small mistake.
                  const Flexible(child: LedgerSwitcher()),
                  const Spacer(),
                  IconButton(
                    onPressed: () => AllTransactionsSheet.show(context),
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    tooltip: t.spending.allTransactions,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => context.pushNamed(AppRoute.debts.name),
                    icon: const Icon(Icons.handshake_outlined, size: 20),
                    tooltip: t.spending.debts,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => context.pushNamed(AppRoute.goal.name),
                    icon: const Icon(Icons.flag_outlined, size: 20),
                    tooltip: t.spending.goal,
                    visualDensity: VisualDensity.compact,
                  ),
                  // Currencies and unusual months used to sit here; they live
                  // under settings now. Both are set once and left, and a row
                  // this crowded is read as a row of buttons rather than as the
                  // three that are worth a tap on any given day.
                  IconButton(
                    onPressed: () => context.pushNamed(AppRoute.settings.name),
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    tooltip: t.settings.tooltip,
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
                      SpendingOverviewStatus.failure => Center(
                        child: Text(t.spending.loadFailed),
                      ),
                      SpendingOverviewStatus.success => CategoryOverviewBody(
                        state: state,
                        kind: CategoryKind.expense,
                        // Just what went out: this page's own categories added
                        // up, which is what the ring below is drawn from too. A
                        // net figure over a grid of spending reads as though the
                        // tiles made it, and what is left after income is the
                        // goal page's business.
                        totalLabel: t.spending.totalLabel,
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
