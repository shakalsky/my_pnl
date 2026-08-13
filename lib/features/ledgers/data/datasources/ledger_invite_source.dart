import 'dart:developer';

import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adds the signed-in user to the family account with this code, and returns its
/// id.
///
/// The one thing about ledgers that cannot be done on the device. Sync only ever
/// delivers ledgers the user is already a member of, so there is nothing locally
/// for a code to match against — the lookup has to happen where every ledger is
/// visible, which is the server.
///
/// A function rather than an interface, like `FetchRequirement`, so the
/// repository's rules around it — normalise the code, wait for the join to sync —
/// can be tested with a closure and no backend.
///
/// Idempotent: redeeming the same code twice lands on the same membership row.
/// Throws [LedgerFailure] with something worth showing when the code matches
/// nothing, or when there is no session or no connection.
typedef LedgerInviteSource =
    Future<String> Function({required String code, String? displayName});

/// Calls the `join_ledger_by_code` function in Postgres.
///
/// A function rather than an insert, because the client is not allowed to see
/// the ledger it is joining until it is in it — the function runs as its owner,
/// looks the code up, and hands back only the id.
class SupabaseLedgerInviteSource {
  const SupabaseLedgerInviteSource(this._client);

  /// The Postgres function this calls. Defined in supabase/schema.sql.
  static const functionName = 'join_ledger_by_code';

  final SupabaseClient _client;

  /// Matches [LedgerInviteSource], so it can be handed to the repository as-is.
  Future<String> redeem({required String code, String? displayName}) async {
    try {
      final result = await _client.rpc<dynamic>(
        functionName,
        params: {'code': code, 'member_name': displayName},
      );

      if (result is String && result.isNotEmpty) return result;

      // The function either returns an id or raises. Anything else means the
      // deployed schema is not the one this build expects.
      throw const LedgerFailure('That code could not be used');
    } on PostgrestException catch (e, s) {
      log('Redeeming an invite code failed', error: e, stackTrace: s);
      // The message comes from the function's own `raise`, which is written for
      // the reader — "No family account with that code" is the common one. A
      // fallback covers the codes it does not raise itself.
      throw LedgerFailure(
        e.message.isEmpty ? 'That code could not be used' : e.message,
      );
    } on LedgerFailure {
      rethrow;
    } on Object catch (e, s) {
      // Almost always the network. Worth saying so, because the fix is to try
      // again somewhere with a signal rather than to check the code.
      log('Redeeming an invite code failed', error: e, stackTrace: s);
      throw const LedgerFailure(
        'Could not reach the server. Joining a family account needs a '
        'connection.',
      );
    }
  }
}

/// Stands in when the app is running with no backend.
///
/// There is no session to join anything with, so this says so rather than
/// failing in a way that reads like a bad code. Matches [LedgerInviteSource].
Future<String> inviteSourceUnavailable({
  required String code,
  String? displayName,
}) async {
  throw const LedgerFailure('Sign in to share a family account with someone.');
}
