import 'package:my_pnl/features/settings/domain/repositories/language_store.dart';

/// Remembers a chosen language, or that the device is being followed again.
class SaveLanguage {
  const SaveLanguage(this._store);

  final LanguageStore _store;

  Future<void> call(String? languageTag) => _store.write(languageTag);
}
