import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/core/session/ledger_scope.dart';
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
import 'package:my_pnl/features/ledgers/data/datasources/ledger_invite_source.dart';
import 'package:my_pnl/features/ledgers/data/datasources/ledger_local_data_source.dart';
import 'package:my_pnl/features/ledgers/data/datasources/preferences_active_ledger_store.dart';
import 'package:my_pnl/features/ledgers/data/repositories/ledger_repository_impl.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';
import 'package:my_pnl/features/settings/data/datasources/preferences_language_store.dart';
import 'package:my_pnl/features/settings/data/datasources/preferences_theme_mode_store.dart';
import 'package:my_pnl/features/settings/domain/repositories/language_store.dart';
import 'package:my_pnl/features/settings/domain/repositories/theme_mode_store.dart';
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
import 'package:my_pnl/i18n/app_locale_setup.dart';
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
    required this.languageStore,
    required this.ledgerRepository,
    required this.overrunSettingsStore,
    required this.themeModeStore,
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

  /// Which language the app is read in, when the reader has said rather than
  /// left it to the device. A device preference, like the display currency.
  final LanguageStore languageStore;

  /// Which books the reader has, and which one everything above is reading.
  /// Every other repository here is narrowed by the ledger this one holds.
  final LedgerRepository ledgerRepository;

  /// When to warn that a month has run past what a category usually costs.
  /// A device preference, like the display currency above.
  final OverrunSettingsStore overrunSettingsStore;

  /// Whether the app is drawn light, dark, or however the device is. A device
  /// preference for the same reason as the rest: it says nothing about the
  /// books, and a phone dimmed at night should not dim a laptop with it.
  final ThemeModeStore themeModeStore;
  final TransactionRepository transactionRepository;
  final SyncRepository syncRepository;
}

/// Opens the local database and, when a backend is configured, starts syncing.
Future<AppDependencies> initializeDependencies() async {
  // First of everything, and awaited. `bootstrap` has already settled on the
  // device's own language; this is where a language the reader chose instead
  // takes over, and it has to be in force before anything below writes a row.
  // The seeded account is named in words that come from `t`, and a name settled
  // in the wrong language is not something a later rebuild can put right — it
  // is stored.
  final languageStore = PreferencesLanguageStore();
  await applyLanguageChoice(await languageStore.read());

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

  // Seeded with the reader's own book, which is derivable from their id and so
  // always exists as an answer even before anything has been read. `resolveActive`
  // below replaces it with whatever this device was last left on.
  final activeLedger = ActiveLedger(personalLedgerId(sessionOwner.id));

  final ledgerRepository = LedgerRepositoryImpl(
    localDataSource: LedgerLocalDataSource(database),
    // Joining is the one ledger operation that needs a server: sync only
    // delivers ledgers you are already in, so nothing local can match a code.
    inviteSource: hasBackend
        ? SupabaseLedgerInviteSource(Supabase.instance.client).redeem
        : inviteSourceUnavailable,
    activeLedgerStore: PreferencesActiveLedgerStore(),
    sessionOwner: sessionOwner,
    activeLedger: activeLedger,
  );

  // Awaited, unlike the repair passes below: every figure in the app is labelled
  // with the base currency, and applying it after the first frame would open the
  // app in dollars and then relabel it in front of the reader.
  final baseCurrencyStore = PreferencesBaseCurrencyStore();
  setActiveBaseCurrency(await baseCurrencyStore.read());

  // Both awaited, and in this order, because every repository below reads
  // through the ledger scope: a page that queried first would read from whatever
  // ledger the last session left behind and then swap its contents out in front
  // of the reader.
  //
  // The adoption pass comes first so that resolving does not have to care whether
  // this is an upgrade — after it, every row on the device belongs to a ledger.
  // It is a couple of bulk updates over local rows, not a network call.
  await ledgerRepository.adoptUnscopedRows();
  await ledgerRepository.resolveActive();

  final dependencies = AppDependencies(
    database: database,
    appUpdateRepository: appUpdateRepository,
    authRepository: authRepository,
    baseCurrencyStore: baseCurrencyStore,
    categoryRepository: CategoryRepositoryImpl(
      localDataSource: CategoryLocalDataSource(database),
      sessionOwner: sessionOwner,
      ledgerScope: activeLedger,
    ),
    currencyRepository: CurrencyRepositoryImpl(
      localDataSource: CurrencyLocalDataSource(database),
      sessionOwner: sessionOwner,
      ledgerScope: activeLedger,
    ),
    displayCurrencyStore: PreferencesDisplayCurrencyStore(),
    debtRepository: DebtRepositoryImpl(
      localDataSource: DebtLocalDataSource(database),
      sessionOwner: sessionOwner,
      ledgerScope: activeLedger,
    ),
    goalRepository: GoalRepositoryImpl(
      localDataSource: GoalLocalDataSource(database),
      sessionOwner: sessionOwner,
      ledgerScope: activeLedger,
    ),
    languageStore: languageStore,
    ledgerRepository: ledgerRepository,
    overrunSettingsStore: PreferencesOverrunSettingsStore(),
    // Not awaited anywhere in startup, unlike the language above: the app shell
    // subscribes to it and the first value arrives with the first frames, so
    // the worst a slow store can do is open in the device's own brightness for
    // an instant rather than in the chosen one.
    themeModeStore: PreferencesThemeModeStore(),
    transactionRepository: TransactionRepositoryImpl(
      localDataSource: TransactionLocalDataSource(database),
      sessionOwner: sessionOwner,
      ledgerScope: activeLedger,
    ),
    // Without a backend there is nothing to report, so the dot stays grey
    // rather than red.
    syncRepository: hasBackend
        ? PowerSyncSyncRepository(powerSync)
        : const LocalOnlySyncRepository(),
  );

  // Rows written before income and spending had signs would otherwise count
  // spending as income. Idempotent, and not awaited: it is a repair pass, and
  // the watch streams pick up whatever it changes. Scoped by owner rather than by
  // ledger, so once is enough however many books the reader has.
  unawaited(dependencies.transactionRepository.normalizeAmountSigns());

  // Recurring income is booked per ledger, so this has to run for whichever book
  // is open — and again for the next one, because a family account switched into
  // may have months to catch up on. `changes` emits the current ledger first,
  // which is what makes one subscription cover startup as well as every switch.
  //
  // Not awaited, for the same reason as the pass above. The subscription is never
  // cancelled: it lives as long as the app does, like the repositories it drives.
  activeLedger.changes.listen(
    (_) =>
        unawaited(dependencies.categoryRepository.generateDueRecurringIncome()),
  );

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
