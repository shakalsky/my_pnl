/// Compile-time configuration.
///
/// The values below are the defaults baked into the binary. Override per build
/// with `--dart-define`, or `--dart-define-from-file=env.json`:
///
/// ```sh
/// flutter run --flavor development --target lib/main_development.dart \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
///   --dart-define=POWERSYNC_URL=https://xxxx.powersync.journeyapps.com
/// ```
///
/// The publishable key is public and RLS-scoped, so it is safe to ship in the
/// binary. A secret or service-role key never belongs here.
abstract final class AppEnv {
  // The argument to String.fromEnvironment is the NAME of the define to read.
  // A value passed there is looked up as a key, finds nothing, and silently
  // yields '' — which is why real values belong in defaultValue.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kdgchgzqvkxwlljsjrhc.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_FceSqIilowfWEe6LDpVGOA_8gWieULE',
  );

  static const powerSyncUrl = String.fromEnvironment(
    'POWERSYNC_URL',
    defaultValue: 'https://6a6f1b9e91ecf2aec48f7ae5.powersync.journeyapps.com',
  );

  /// Whether every backend value is present.
  ///
  /// When false the app still runs fully offline against the local database:
  /// it never connects to PowerSync, and sign-in is skipped entirely.
  static bool get hasBackend =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      powerSyncUrl.isNotEmpty;
}
