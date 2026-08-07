import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/database/powersync/powersync_service.dart';
import 'package:my_pnl/features/app_update/data/datasources/app_requirement_source.dart';
import 'package:my_pnl/features/app_update/data/repositories/remote_app_update_repository.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/auth/data/repositories/local_only_auth_repository.dart';
import 'package:my_pnl/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/currencies/data/datasources/currency_local_data_source.dart';
import 'package:my_pnl/features/currencies/data/datasources/preferences_base_currency_store.dart';
import 'package:my_pnl/features/currencies/data/datasources/preferences_display_currency_store.dart';
import 'package:my_pnl/features/currencies/data/repositories/currency_repository_impl.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';
import 'package:my_pnl/features/debts/data/datasources/debt_local_data_source.dart';
import 'package:my_pnl/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/goals/data/datasources/goal_local_data_source.dart';
import 'package:my_pnl/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/data/datasources/preferences_overrun_settings_store.dart';
import 'package:my_pnl/features/spending/data/datasources/transaction_local_data_source.dart';
import 'package:my_pnl/features/spending/data/repositories/category_repository_impl.dart';
import 'package:my_pnl/features/spending/data/repositories/transaction_repository_impl.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/sync/data/repositories/powersync_sync_repository.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The composition root.
///
/// The only place that knows which implementation satisfies which interface.
/// Everything above is handed the abstraction.
class AppDependencies {
  const AppDependencies({
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
  });

  /// Typed access to the local database. Reads and writes never wait on the
  /// network — sync happens underneath.
  final AppDatabase database;

  /// Says whether this build is still allowed to run. Read over the network, not
  /// through sync: it has to answer before anyone signs in.
  final AppUpdateRepository appUpdateRepository;

  final AuthRepository authRepository;

  /// Which currency amounts are recorded and shown in. A device preference, so
  /// it is not one of the synced repositories above.
  final BaseCurrencyStore baseCurrencyStore;
  final CategoryRepository categoryRepository;
  final CurrencyRepository currencyRepository;

  /// Which currency totals are read in. A device preference, so it is not one
  /// of the synced repositories above.
  final DisplayCurrencyStore displayCurrencyStore;
  final DebtRepository debtRepository;
  final GoalRepository goalRepository;

  /// When to warn that a month has run past what a category usually costs.
  /// A device preference, like the display currency above.
  final OverrunSettingsStore overrunSettingsStore;
  final TransactionRepository transactionRepository;
  final SyncRepository syncRepository;
}

/// Opens the local database and, when a backend is configured, starts syncing.
Future<AppDependencies> initializeDependencies() async {
  final powerSync = await openPowerSyncDatabase();
  final hasBackend = await initializeSupabase();

  // No backend means no account to sign into, so the app reports a fixed local
  // user and opens straight onto its data instead of an unusable sign-in page.
  final authRepository = hasBackend
      ? SupabaseAuthRepository(Supabase.instance.client)
      : const LocalOnlyAuthRepository();

  if (hasBackend) {
    // Connects now if a session was restored, and on every later sign-in.
    connectPowerSyncToSupabase(powerSync);
  }

  final database = AppDatabase(powerSync);
  final sessionOwner = AuthSessionOwner(authRepository);
  final appUpdateRepository = await _buildAppUpdateRepository(
    hasBackend: hasBackend,
  );

  // Awaited, unlike the repair passes below: every figure in the app is labelled
  // with the base currency, and applying it after the first frame would open the
  // app in dollars and then relabel it in front of the reader.
  final baseCurrencyStore = PreferencesBaseCurrencyStore();
  setActiveBaseCurrency(await baseCurrencyStore.read());

  final dependencies = AppDependencies(
    database: database,
    appUpdateRepository: appUpdateRepository,
    authRepository: authRepository,
    baseCurrencyStore: baseCurrencyStore,
    categoryRepository: CategoryRepositoryImpl(
      localDataSource: CategoryLocalDataSource(database),
      sessionOwner: sessionOwner,
    ),
    currencyRepository: CurrencyRepositoryImpl(
      localDataSource: CurrencyLocalDataSource(database),
      sessionOwner: sessionOwner,
    ),
    displayCurrencyStore: PreferencesDisplayCurrencyStore(),
    debtRepository: DebtRepositoryImpl(
      localDataSource: DebtLocalDataSource(database),
      sessionOwner: sessionOwner,
    ),
    goalRepository: GoalRepositoryImpl(
      localDataSource: GoalLocalDataSource(database),
      sessionOwner: sessionOwner,
    ),
    overrunSettingsStore: PreferencesOverrunSettingsStore(),
    transactionRepository: TransactionRepositoryImpl(
      localDataSource: TransactionLocalDataSource(database),
      sessionOwner: sessionOwner,
    ),
    // Without a backend there is nothing to report, so the dot stays grey
    // rather than red.
    syncRepository: hasBackend
        ? PowerSyncSyncRepository(powerSync)
        : const LocalOnlySyncRepository(),
  );

  // Rows written before income and spending had signs would otherwise count
  // spending as income. Idempotent, and not awaited: it is a repair pass, and
  // the watch streams pick up whatever it changes.
  unawaited(dependencies.transactionRepository.normalizeAmountSigns());
  unawaited(dependencies.categoryRepository.generateDueRecurringIncome());

  // Asked once at startup, and again on every resume. Not awaited: the app has
  // to open at the same speed whether or not the network answers, and the
  // router redirects the moment the answer arrives.
  unawaited(appUpdateRepository.checkForUpdate());

  return dependencies;
}

/// Stands in for a version that could not be read. Never gates anything, and
/// never reaches a screen: the repository below refuses to build a real gate
/// around it.
const _unknownVersion = AppVersion(major: 0, minor: 0, patch: 0);

/// Builds the update gate for the platform this build is running on.
///
/// The version comes from the platform bundle rather than a constant in Dart,
/// so it cannot drift out of step with what the store actually shipped.
///
/// Falls back to a gate that blocks nobody when the version cannot be read at
/// all — the same fail-open rule as an unreachable backend. A build that does
/// not know its own version cannot say whether it is too old, and an app that
/// refuses to start is worse than one running a version behind.
Future<AppUpdateRepository> _buildAppUpdateRepository({
  required bool hasBackend,
}) async {
  final currentVersion = await _readCurrentVersion();

  if (!hasBackend || currentVersion == null) {
    return LocalOnlyAppUpdateRepository(currentVersion ?? _unknownVersion);
  }

  return RemoteAppUpdateRepository(
    fetchRequirement: SupabaseAppRequirementSource(
      Supabase.instance.client,
    ).fetch,
    currentVersion: currentVersion,
    platform: platformKey,
  );
}

/// The running build's version, or null when the platform will not say.
///
/// Wrapped because this is the one thing in startup that talks to a platform
/// channel for something optional. A missing plugin registration — the state of
/// every hot restart that follows adding one — used to throw here and take the
/// whole app down with it.
Future<AppVersion?> _readCurrentVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersion.tryParse('${info.version}+${info.buildNumber}');
  } on Object catch (e, s) {
    log('Reading the app version failed', error: e, stackTrace: s);
    return null;
  }
}

/// The `platform` column's value for this build.
///
/// Matches the check constraint on `app_requirements`, so a row can name one
/// platform without affecting the others — an iOS release blocked on review
/// should not lock out Android.
String get platformKey => switch (defaultTargetPlatform) {
  // Checked first: on the web `defaultTargetPlatform` reports the host OS, so
  // a browser would otherwise be told to visit the App Store.
  _ when kIsWeb => 'web',
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.windows => 'windows',
  TargetPlatform.linux => 'linux',
  TargetPlatform.fuchsia => 'other',
};
