import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pnl/app/routing/app_router.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_base_currency.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';
import 'package:my_pnl/i18n/app_locale_setup.dart';
import 'package:my_pnl/i18n/strings.g.dart';

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
    required this.ledgerRepository,
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
  final LedgerRepository ledgerRepository;
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
  StreamSubscription<AuthUser?>? _sessionChanges;
  StreamSubscription<AppLocale>? _localeChanges;

  /// The language the tree below is built in. Held rather than read off
  /// [LocaleSettings] at build time so it can key the shell — see [build].
  AppLocale _locale = LocaleSettings.currentLocale;

  /// Who the tree below is built for. Only used to tell one session from the
  /// next; the pages read the session through [AuthBloc].
  String? _sessionUserId;

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

    // Nothing here watches the open ledger, and it would not help if it did: the
    // router keeps its Navigator behind a GlobalKey, so rebuilding this shell
    // preserves the pages and the blocs beneath them, subscriptions and all. A
    // switch reaches them through the repositories instead — every watch stream
    // is built over `LedgerScope.changes`.
    //
    // Which books exist depends on who is signed in, so a sign-in or sign-out
    // has to settle the open one again. Without this, the ledger resolved for
    // the signed-out local user would stay in force after signing in, and every
    // read and write would go to a book the account has no access to.
    _sessionUserId = widget.authRepository.currentUser?.id;
    _sessionChanges = widget.authRepository.watchUser().listen(_applySession);

    // Startup has already settled the language; this is for one changed in the
    // system settings while the app is open, which slang picks up on its own.
    _localeChanges = LocaleSettings.getLocaleStream().listen(_applyLocale);
  }

  Future<void> _applyLocale(AppLocale locale) async {
    if (locale == _locale) return;

    // Awaited before the rebuild: the pages below format dates, and a
    // [DateFormat] built for a locale whose symbols are not loaded throws.
    await applyToIntl(locale);
    if (mounted) setState(() => _locale = locale);
  }

  void _applySession(AuthUser? user) {
    if (user?.id == _sessionUserId) return;

    _sessionUserId = user?.id;
    // Not awaited, and nothing here waits for it: the switch it may cause
    // arrives through [_applyLedger] like any other.
    unawaited(widget.ledgerRepository.resolveActive());
  }

  void _applyBaseCurrency(BaseCurrency base) {
    if (base == activeBaseCurrency) return;

    setActiveBaseCurrency(base);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_baseCurrencyChanges?.cancel());
    unawaited(_sessionChanges?.cancel());
    unawaited(_localeChanges?.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Outermost, so `context.t` resolves anywhere below — including inside the
    // routes, which are built beneath the router's own Navigator.
    return TranslationProvider(
      child: MultiRepositoryProvider(
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
          RepositoryProvider.value(value: widget.ledgerRepository),
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
            // What Flutter's own widgets are shown in — the date picker's month
            // grid, the text selection menu. The app's own wording comes from
            // `t` and is settled before the first frame; this is the half
            // Flutter draws.
            locale: _locale.flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            // Rebuilt when the base currency or the language changes, and only
            // then.
            //
            // Both are read from a single value rather than handed down: every
            // figure goes through `formatAmount`, which reads the base, and
            // every label goes through `t`, which reads the locale. A rebuild
            // is all it takes to relabel what is on screen. Keying it is what
            // makes the rebuild happen at all — the router hands the Navigator
            // the same page objects it did before, so without a key change
            // nothing beneath is asked to build again.
            //
            // Note what this does *not* do: the pages themselves survive it,
            // because the router's Navigator sits behind a GlobalKey. Anything
            // that has to be re-read rather than re-rendered — the open ledger
            // — cannot be done from here.
            builder: (context, child) => KeyedSubtree(
              key: ValueKey('${activeBaseCurrency.ticker}:${_locale.name}'),
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
      ),
    );
  }
}
