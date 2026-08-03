import 'package:my_pnl/env/app_env.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Postgres error classes that will never succeed on retry.
///
/// A constraint violation or a permission denial is a permanent rejection of
/// that change. Retrying it forever would wedge the upload queue and block
/// every later write, so the change is discarded instead.
const _fatalResponseCodes = {
  '22', // data exception, e.g. invalid text representation
  '23', // integrity constraint violation
  '42501', // insufficient privilege — usually a failing RLS policy
};

bool _isFatal(PostgrestException e) {
  final code = e.code;
  if (code == null) return false;
  return _fatalResponseCodes.any(code.startsWith);
}

/// Connects PowerSync to Supabase.
///
/// Reads reach the device through PowerSync's replication stream. Writes do
/// not: PowerSync hands them back here, and this connector applies them with
/// the ordinary Supabase client, so RLS, triggers and constraints all still
/// run server-side. The change then returns down the replication path like any
/// other.
class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector(this.db);

  final PowerSyncDatabase db;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not signed in — PowerSync stays disconnected and the app runs against
      // the local database only.
      return null;
    }

    return PowerSyncCredentials(
      endpoint: AppEnv.powerSyncUrl,
      token: session.accessToken,
      userId: session.user.id,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    final rest = Supabase.instance.client;

    try {
      for (final op in transaction.crud) {
        final table = rest.from(op.table);
        switch (op.op) {
          case UpdateType.put:
            await table.upsert({'id': op.id, ...?op.opData});
          case UpdateType.patch:
            await table.update(op.opData!).eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }

      // Only clears the queue once every op in the transaction landed, so a
      // partial failure replays the whole transaction. Upserts keyed on the
      // client-generated id make that replay idempotent.
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (_isFatal(e)) {
        // Drop the change rather than retry it forever. Worth logging to your
        // error reporter — it means local and remote have diverged.
        await transaction.complete();
        return;
      }
      // Transient: PowerSync retries after its configured delay.
      rethrow;
    }
  }
}
