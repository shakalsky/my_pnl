import 'dart:async';

/// Follows [source], replacing the inner stream every time it emits.
///
/// A `switchMap`, which the app needs in exactly one place: every read is
/// narrowed to the ledger currently open, and the reader can switch books while a
/// page is watching. Without this the page goes on reading the book it
/// subscribed against — the query was built once, and nothing about it changes
/// when the scope does.
///
/// It cannot be `asyncExpand`, which is the obvious thing to reach for and the
/// wrong one: that waits for the inner stream to *complete* before taking the
/// next outer event, and a database watch stream never completes. A switch would
/// simply never be noticed.
///
/// The previous inner subscription is cancelled before the next one is made, so
/// no value from the book just closed can arrive after one from the book just
/// opened. `cancel()` stops delivery synchronously; the future it returns is only
/// for cleanup, which is why it does not have to be awaited here.
Stream<T> switchLatest<S, T>(Stream<S> source, Stream<T> Function(S) select) {
  StreamSubscription<S>? outer;
  StreamSubscription<T>? inner;
  late StreamController<T> controller;

  void listenInner(S value) {
    final previous = inner;
    inner = null;
    unawaited(previous?.cancel());

    inner = select(value).listen(controller.add, onError: controller.addError);
  }

  Future<void> stop() async {
    final pending = [inner?.cancel(), outer?.cancel()];
    inner = null;
    outer = null;
    await Future.wait(pending.whereType<Future<void>>());
  }

  controller = StreamController<T>(
    onListen: () {
      outer = source.listen(
        listenInner,
        onError: controller.addError,
        // Deliberately not closing the controller: the source here is the open
        // ledger, which outlives every page, and a `done` on it would end a
        // subscription the page still expects to be live.
      );
    },
    onCancel: stop,
    onPause: () {
      inner?.pause();
      outer?.pause();
    },
    onResume: () {
      inner?.resume();
      outer?.resume();
    },
  );

  return controller.stream;
}
