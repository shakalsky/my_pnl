import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pnl/app/routing/app_router.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_base_currency.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';

class App extends StatefulWidget {
  const App({
    required this.database,
    required this.appUpdateRepository,
    required this.authRepository,
    required this.baseCurrencyStore,
    required this.categoryRepository,
    required this.currencyRepository,
    required this.displayCurrencyStore,
    required this.debtRepository,
    required this.goalRepository,
    required this.overrunSettingsStore,
    required this.transactionRepository,
    required this.syncRepository,
    this.router,
    super.key,
  });

  final AppDatabase database;

  /// Provided as domain interfaces, not implementations — widgets and blocs
  /// below here cannot reach drift or Supabase even by accident.
  final AppUpdateRepository appUpdateRepository;
  final AuthRepository authRepository;
  final BaseCurrencyStore baseCurrencyStore;
  final CategoryRepository categoryRepository;
  final CurrencyRepository currencyRepository;
  final DisplayCurrencyStore displayCurrencyStore;
  final DebtRepository debtRepository;
  final GoalRepository goalRepository;
  final OverrunSettingsStore overrunSettingsStore;
  final TransactionRepository transactionRepository;
  final SyncRepository syncRepository;

  /// Overridable so tests can pump a router with a single route.
  final GoRouter? router;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;
  AppLifecycleListener? _lifecycle;
  StreamSubscription<BaseCurrency>? _baseCurrencyChanges;

  @override
  void initState() {
    super.initState();
    // Built once: a GoRouter holds navigation state, so recreating it on
    // rebuild would drop the user back at the initial route.
    _router =
        widget.router ??
        createAppRouter(
          authRepository: widget.authRepository,
          appUpdateRepository: widget.appUpdateRepository,
        );

    // An app left open for weeks would otherwise never notice a new minimum.
    // Not awaited: the check fails open, so there is nothing to wait for.
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(widget.appUpdateRepository.checkForUpdate()),
    );

    // Every figure in the app is labelled with the base currency, and the code
    // that formats one reads it from a single value rather than being handed it
    // — so a change is applied here and rebuilt over, which relabels what is
    // already on screen. Startup has set it before the first frame; this is only
    // for a change made while the app is running.
    _baseCurrencyChanges = WatchBaseCurrency(
      widget.baseCurrencyStore,
    )().listen(_applyBaseCurrency);
  }

  void _applyBaseCurrency(BaseCurrency base) {
    if (base == activeBaseCurrency) return;

    setActiveBaseCurrency(base);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_baseCurrencyChanges?.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.database),
        RepositoryProvider.value(value: widget.appUpdateRepository),
        RepositoryProvider.value(value: widget.authRepository),
        RepositoryProvider.value(value: widget.baseCurrencyStore),
        RepositoryProvider.value(value: widget.categoryRepository),
        RepositoryProvider.value(value: widget.currencyRepository),
        RepositoryProvider.value(value: widget.displayCurrencyStore),
        RepositoryProvider.value(value: widget.debtRepository),
        RepositoryProvider.value(value: widget.goalRepository),
        RepositoryProvider.value(value: widget.overrunSettingsStore),
        RepositoryProvider.value(value: widget.transactionRepository),
        RepositoryProvider.value(value: widget.syncRepository),
      ],
      // Above the router, because every page's presence depends on it.
      child: BlocProvider(
        create: (_) =>
            AuthBloc(authRepository: widget.authRepository)
              ..add(const AuthSubscriptionRequested()),
        child: MaterialApp.router(
          routerConfig: _router,
          // Rebuilt from scratch when the base currency changes, and only then.
          //
          // A rebuild alone does not reach the pages: they are the router's, and
          // it hands the Navigator the same page objects it did before, so
          // nothing beneath is asked to build again. Keying the Navigator throws
          // the pages away and builds them from the router's current location —
          // the reader stays where they are, and no figure is left labelled with
          // the currency they have just stopped using.
          builder: (context, child) => KeyedSubtree(
            key: ValueKey(activeBaseCurrency.ticker),
            child: child!,
          ),
          theme: ThemeData(
            appBarTheme: AppBarTheme(
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            useMaterial3: true,
          ),
        ),
      ),
    );
  }
}
