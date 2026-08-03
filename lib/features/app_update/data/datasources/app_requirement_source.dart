import 'dart:developer';

import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the requirement for a platform, or null when none is configured.
///
/// A function rather than an interface, so the repository's rules — fail open,
/// keep the last answer, only announce changes — can be tested with a closure
/// and no backend. Throws when the backend cannot be reached; the repository
/// decides what that means.
typedef FetchRequirement =
    Future<UpdateRequirement?> Function(String platform);

/// Reads the requirement straight from Postgres.
///
/// A direct select rather than a synced table: this has to answer on the
/// sign-in screen, where PowerSync has no JWT and therefore no data, and it has
/// to be current rather than whatever the last sync happened to bring down. The
/// row is world-readable, so the anon key is enough.
class SupabaseAppRequirementSource {
  const SupabaseAppRequirementSource(this._client);

  /// Table holding one row per platform.
  static const table = 'app_requirements';

  final SupabaseClient _client;

  /// Matches [FetchRequirement], so it can be handed to the repository as-is.
  Future<UpdateRequirement?> fetch(String platform) async {
    final row = await _client
        .from(table)
        .select('min_version, min_build, store_url, message')
        .eq('platform', platform)
        .maybeSingle();

    if (row == null) return null;
    return requirementFromRow(row);
  }

  /// Reads one row, or null when it does not describe a version.
  ///
  /// A row nobody can parse is treated as no requirement rather than as a
  /// block: a typo in the dashboard should not lock every user out of the app.
  static UpdateRequirement? requirementFromRow(Map<String, Object?> row) {
    final minVersion = AppVersion.tryParse('${row['min_version']}');
    if (minVersion == null) {
      log('Ignoring unparseable min_version "${row['min_version']}"');
      return null;
    }

    // The build number lives in its own column, so it is grafted onto the
    // version parsed above rather than expected inside the string.
    final build = switch (row['min_build']) {
      final int build => build,
      final String build => int.tryParse(build) ?? 0,
      _ => 0,
    };

    return UpdateRequirement(
      minVersion: AppVersion(
        major: minVersion.major,
        minor: minVersion.minor,
        patch: minVersion.patch,
        build: build,
      ),
      storeUrl: _text(row['store_url']),
      message: _text(row['message']),
    );
  }

  /// Empty strings become null, so callers have one way to say "not set".
  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
