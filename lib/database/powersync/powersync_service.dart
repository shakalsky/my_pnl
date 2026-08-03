import 'dart:async';
import 'dart:developer';

import 'package:my_pnl/database/powersync/app_schema.dart';
import 'package:my_pnl/database/powersync/supabase_connector.dart';
import 'package:my_pnl/env/app_env.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opens the local PowerSync database.
///
/// This always succeeds, backend or not — the local SQLite file is the app's
/// source of truth and every read and write goes through it. Syncing is a
/// separate step, started by [connectPowerSyncToSupabase] once a user is
/// signed in.
Future<PowerSyncDatabase> openPowerSyncDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final database = PowerSyncDatabase(
    schema: appSchema,
    path: p.join(directory.path, 'my_pnl.db'),
  );
  await database.initialize();
  return database;
}

/// Keeps the sync connection in step with the Supabase session.
///
/// Sync rules bucket on the user id from the JWT, so a connection is only
/// meaningful while signed in. Signing out disconnects and clears the local
/// copy, otherwise the next user would inherit the previous one's rows.
StreamSubscription<AuthState> connectPowerSyncToSupabase(
  PowerSyncDatabase database,
) {
  final auth = Supabase.instance.client.auth;

  Future<void> apply(Session? session) async {
    if (session == null) {
      await database.disconnectAndClear();
    } else {
      await database.connect(connector: SupabaseConnector(database));
    }
  }

  unawaited(
    apply(auth.currentSession).catchError((Object e, StackTrace s) {
      log('PowerSync connect failed', error: e, stackTrace: s);
    }),
  );

  return auth.onAuthStateChange.listen((state) async {
    try {
      await apply(state.session);
    } on Object catch (e, s) {
      log('PowerSync auth transition failed', error: e, stackTrace: s);
    }
  });
}

/// Initializes Supabase, if the backend is configured.
///
/// Returns false when [AppEnv.hasBackend] is false, which is the normal state
/// for a local-only development run.
Future<bool> initializeSupabase() async {
  if (!AppEnv.hasBackend) return false;
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    publishableKey: AppEnv.supabasePublishableKey,
  );
  return true;
}
