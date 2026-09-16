import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pnl/app/routing/app_router.dart';
import 'package:my_pnl/features/ledgers/presentation/widgets/ledger_switcher.dart';
import 'package:my_pnl/features/spending/presentation/bloc/selected_month/selected_month_cubit.dart';
import 'package:my_pnl/features/spending/presentation/widgets/account_button.dart';
import 'package:my_pnl/features/spending/presentation/widgets/all_transactions_sheet.dart';
import 'package:my_pnl/features/sync/presentation/widgets/sync_indicator.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// The row of actions above both overviews.
///
/// Lives in the pager rather than in either page, so it stays put while the two
/// slide underneath it. Nothing on it belongs to one side of the ledger — which
/// book is open, what has been booked, the debts, the goal — and a header that
/// swiped away with the grid made the two pages read as separate screens rather
/// than as two halves of the same one.
class OverviewToolbar extends StatelessWidget {
  const OverviewToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The row's own inset rather than the pager's: the pages beneath it pad
      // themselves, and a padding around both would have to come off the width
      // the grid lays its tiles out in.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SyncIndicator(),
          // Ahead of everything else, and given the row's whole remainder
          // rather than a Flexible beside a Spacer: which book is open is what
          // every figure below depends on, and a total read against the wrong
          // one is not a small mistake. Sharing the free width with a spacer
          // split it evenly — half a row of blank against half a name — and on
          // a phone that left the name as an ellipsis. The switcher cuts its
          // own label short, so the icons keep their room either way.
          const Expanded(child: LedgerSwitcher()),
          IconButton(
            // Scoped to the month both overviews are showing: the sheet is
            // opened from a page of figures for one month, and a ledger
            // running back over every month would not be a list of them.
            onPressed: () => AllTransactionsSheet.show(
              context,
              month: context.read<SelectedMonthCubit>().state,
            ),
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
          // Currencies and unusual months used to sit here; they live under
          // settings now. Both are set once and left, and a row this crowded is
          // read as a row of buttons rather than as the three that are worth a
          // tap on any given day.
          IconButton(
            onPressed: () => context.pushNamed(AppRoute.settings.name),
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: t.settings.tooltip,
            visualDensity: VisualDensity.compact,
          ),
          const AccountButton(),
        ],
      ),
    );
  }
}
