import 'package:my_pnl/features/settings/domain/repositories/language_store.dart';

/// Reads the language tag last chosen, or null while the device is followed.
class ReadLanguage {
  const ReadLanguage(this._store);

  final LanguageStore _store;

  Future<String?> call() => _store.read();
}
