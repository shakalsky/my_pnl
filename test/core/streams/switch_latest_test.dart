import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/streams/switch_latest.dart';

void main() {
  group('switchLatest', () {
    late StreamController<String> source;
    late Map<String, StreamController<int>> inners;
    late List<String> selected;

    setUp(() {
      // Broadcast, like the controller `ActiveLedger` announces switches on, and
      // so that `close()` in the tear-down completes whether or not anything is
      // still listening.
      source = StreamController<String>.broadcast();
      inners = {
        'a': StreamController<int>.broadcast(),
        'b': StreamController<int>.broadcast(),
      };
      selected = [];
    });

    tearDown(() async {
      await source.close();
      for (final inner in inners.values) {
        if (!inner.isClosed) await inner.close();
      }
    });

    Stream<int> build() => switchLatest(source.stream, (key) {
      selected.add(key);
      return inners[key]!.stream;
    });

    test('forwards the first inner stream', () async {
      final seen = <int>[];
      final subscription = build().listen(seen.add);

      source.add('a');
      await pumpEventQueue();
      inners['a']!.add(1);
      inners['a']!.add(2);
      await pumpEventQueue();

      expect(seen, [1, 2]);
      expect(selected, ['a']);
      await subscription.cancel();
    });

    test('moves to the new inner stream when the source emits', () async {
      final seen = <int>[];
      final subscription = build().listen(seen.add);

      source.add('a');
      await pumpEventQueue();
      inners['a']!.add(1);
      await pumpEventQueue();

      source.add('b');
      await pumpEventQueue();
      inners['b']!.add(2);
      await pumpEventQueue();

      expect(seen, [1, 2]);
      expect(selected, ['a', 'b']);
      await subscription.cancel();
    });

    test('stops listening to the one it left', () async {
      final seen = <int>[];
      final subscription = build().listen(seen.add);

      source.add('a');
      await pumpEventQueue();
      source.add('b');
      await pumpEventQueue();

      // The book the reader closed. A value arriving from it after the switch is
      // the bug this whole mechanism exists to prevent, so it must not come
      // through even if something is still producing them.
      inners['a']!.add(99);
      inners['b']!.add(2);
      await pumpEventQueue();

      expect(seen, [2]);
      await subscription.cancel();
    });

    test('does not wait for the inner stream to end', () async {
      final seen = <int>[];
      final subscription = build().listen(seen.add);

      source.add('a');
      await pumpEventQueue();
      // `a` is still open, and stays open. `asyncExpand` would block here
      // forever; a database watch stream never completes.
      source.add('b');
      await pumpEventQueue();
      inners['b']!.add(2);
      await pumpEventQueue();

      expect(seen, [2]);
      expect(inners['a']!.isClosed, isFalse);
      await subscription.cancel();
    });

    test('passes an inner error on without ending the stream', () async {
      final seen = <int>[];
      final errors = <Object>[];
      final subscription = build().listen(seen.add, onError: errors.add);

      source.add('a');
      await pumpEventQueue();
      inners['a']!.addError(StateError('query failed'));
      await pumpEventQueue();

      source.add('b');
      await pumpEventQueue();
      inners['b']!.add(2);
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(seen, [2], reason: 'the next book still reads');
      await subscription.cancel();
    });

    test('passes a source error on', () async {
      final errors = <Object>[];
      final subscription = build().listen(null, onError: errors.add);

      source.addError(StateError('scope failed'));
      await pumpEventQueue();

      expect(errors, hasLength(1));
      await subscription.cancel();
    });

    test('stays open when the source ends', () async {
      final seen = <int>[];
      var done = false;
      final subscription = build().listen(seen.add, onDone: () => done = true);

      source.add('a');
      await pumpEventQueue();
      await source.close();
      await pumpEventQueue();

      // The source is the open ledger, which outlives every page. Ending here
      // would close a subscription the page still expects to be live.
      expect(done, isFalse);
      inners['a']!.add(1);
      await pumpEventQueue();
      expect(seen, [1]);

      await subscription.cancel();
    });

    test('opens no query until something listens', () async {
      final stream = build();

      source.add('a');
      await pumpEventQueue();

      // Nothing is read for a stream nobody is reading — which is what makes it
      // safe for a repository to hand one back per call.
      expect(selected, isEmpty);

      final subscription = stream.listen(null);
      source.add('b');
      await pumpEventQueue();

      expect(selected, ['b']);
      await subscription.cancel();
    });

    test('cancelling releases both subscriptions', () async {
      final seen = <int>[];
      final subscription = build().listen(seen.add);

      source.add('a');
      await pumpEventQueue();
      await subscription.cancel();

      inners['a']!.add(1);
      source.add('b');
      await pumpEventQueue();

      expect(seen, isEmpty);
      expect(selected, ['a'], reason: 'no new query after cancelling');
    });
  });
}
