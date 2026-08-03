import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';

import 'fake_auth_repository.dart';
import 'fake_display_currency_store.dart';
import 'fake_sync_repository.dart';

extension PumpApp on WidgetTester {
  /// Pumps [widget] with the repositories a page expects to find above it.
  ///
  /// An [AuthBloc] is always provided — pages carry an account affordance, and
  /// leaving it out fails with a provider lookup error rather than anything
  /// that points at the real problem.
  Future<void> pumpApp(
    Widget widget, {
    AppUpdateRepository? appUpdateRepository,
    AuthRepository? authRepository,
    CategoryRepository? categoryRepository,
    CurrencyRepository? currencyRepository,
    DisplayCurrencyStore? displayCurrencyStore,
    DebtRepository? debtRepository,
    GoalRepository? goalRepository,
    TransactionRepository? transactionRepository,
    SyncRepository? syncRepository,
  }) {
    final auth = authRepository ?? FakeAuthRepository();
    // Always provided: the overview header carries a sync dot, and leaving it
    // out fails with a provider lookup rather than anything informative.
    final sync = syncRepository ?? FakeSyncRepository();
    // Likewise: every page showing a total reads which currency to show it in,
    // and an empty store is the ordinary case of never having chosen.
    final displayCurrency = displayCurrencyStore ?? FakeDisplayCurrencyStore();

    // Providers sit ABOVE MaterialApp, exactly as they do in App. Below it
    // they would also sit below the Navigator, and anything pushed as a route
    // — every modal in this app — could not see them.
    return pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: auth),
          if (appUpdateRepository != null)
            RepositoryProvider<AppUpdateRepository>.value(
              value: appUpdateRepository,
            ),
          RepositoryProvider<SyncRepository>.value(value: sync),
          RepositoryProvider<DisplayCurrencyStore>.value(
            value: displayCurrency,
          ),
          if (categoryRepository != null)
            RepositoryProvider<CategoryRepository>.value(
              value: categoryRepository,
            ),
          if (currencyRepository != null)
            RepositoryProvider<CurrencyRepository>.value(
              value: currencyRepository,
            ),
          if (debtRepository != null)
            RepositoryProvider<DebtRepository>.value(value: debtRepository),
          if (goalRepository != null)
            RepositoryProvider<GoalRepository>.value(value: goalRepository),
          if (transactionRepository != null)
            RepositoryProvider<TransactionRepository>.value(
              value: transactionRepository,
            ),
        ],
        child: BlocProvider(
          create: (_) =>
              AuthBloc(authRepository: auth)
                ..add(const AuthSubscriptionRequested()),
          child: MaterialApp(home: widget),
        ),
      ),
    );
  }
}
