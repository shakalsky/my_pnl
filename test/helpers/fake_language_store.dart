import 'package:my_pnl/features/settings/domain/repositories/language_store.dart';

/// In-memory stand-in for [LanguageStore].
///
/// Starts empty, which is a device that has never chosen: the app is read in
/// whatever language the device is set to.
class FakeLanguageStore implements LanguageStore {
  FakeLanguageStore({String? remembered}) : _remembered = remembered;

  String? _remembered;

  /// Every tag written, in order, including the nulls that hand the choice
  /// back to the device.
  final writes = <String?>[];

  @override
  Future<String?> read() async => _remembered;

  @override
  Future<void> write(String? languageTag) async {
    _remembered = languageTag;
    writes.add(languageTag);
  }
}
