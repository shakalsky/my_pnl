import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a stream to [Listenable] so GoRouter can re-run its redirect.
///
/// GoRouter only re-evaluates `redirect` when it is told something changed;
/// without this, signing out leaves the user sitting on a page they are no
/// longer allowed to see.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<dynamic> stream) {
    // Fires once up front so the first redirect runs against current state.
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
