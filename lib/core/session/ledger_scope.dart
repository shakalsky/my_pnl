import 'dart:async';

/// Supplies the `ledger_id` every read filters on and every write stamps.
///
/// The companion to `SessionOwner`, and the two answer different questions.
/// `SessionOwner` says who is writing; this says which book they are writing
/// into. Reads narrow on this alone, which is what lets a partner's spending
/// appear in the same totals as your own.
abstract interface class LedgerScope {
  /// The ledger on screen. Never empty: a user always has a personal ledger,
  /// and its id is derivable from theirs, so there is always something to fall
  /// back to.
  ///
  /// What a write stamps. A read cannot use this on its own — see [changes].
  String get id;

  /// [id], and every ledger it is switched to afterwards.
  ///
  /// Every watch stream in the app is built over this rather than over [id],
  /// because a query is built once and the scope can change while a page is
  /// looking at it. Reading [id] alone would leave the page showing the book it
  /// happened to subscribe against, which is the one mistake a switcher must not
  /// be able to cause.
  Stream<String> get changes;
}

/// The ledger in force for this run, and a way to be told when it changes.
///
/// Mutable, unlike `SessionOwner`: switching between a personal and a family
/// account is a thing the reader does while the app is open. The repositories
/// hold this as a [LedgerScope]: writes read [id] as they run, and reads are
/// built over [changes] so that a switch re-runs them. Nothing above the data
/// layer has to do anything about a switch — which is the point, because the
/// widget tree cannot be relied on for it. The router keeps its Navigator behind
/// a `GlobalKey`, so rebuilding the shell preserves the pages and the blocs
/// underneath, subscriptions and all.
class ActiveLedger implements LedgerScope {
  ActiveLedger(this._id);

  String _id;

  /// Broadcasts a switch to whatever is already reading.
  ///
  /// Broadcast because every open watch stream listens — one per page, and more
  /// than one per page in places. The same arrangement
  /// `PreferencesBaseCurrencyStore` uses, and for the same reason: there is one
  /// write path and it is what tells the readers.
  final _changes = StreamController<String>.broadcast();

  @override
  String get id => _id;

  @override
  Stream<String> get changes {
    // Not `async* { yield _id; yield* _changes.stream; }`, which is the obvious
    // shape and drops events: a generator suspends at its first `yield` and only
    // subscribes to what follows once that value has been taken. A switch landing
    // in that gap goes to a broadcast stream with no listener yet, and a
    // broadcast stream drops what nobody is listening for — leaving this reader
    // pinned to a book that is no longer open.
    //
    // Here the subscription is made *before* the current value goes out, and both
    // happen in one synchronous block, so there is no gap to lose anything in.
    late StreamController<String> controller;
    StreamSubscription<String>? subscription;

    controller = StreamController<String>(
      onListen: () {
        subscription = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        controller.add(_id);
      },
      onCancel: () => subscription?.cancel(),
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
    );

    return controller.stream;
  }

  /// Points the app at another ledger.
  ///
  /// Whether the user is a member of it is not checked here — [LedgerScope] is
  /// a value, not a gate. `LedgerRepository.select` is what refuses a ledger
  /// the user cannot write to, and writing to one anyway would have its uploads
  /// refused by the Postgres policies.
  void switchTo(String ledgerId) {
    if (ledgerId.isEmpty || ledgerId == _id) return;

    _id = ledgerId;
    if (!_changes.isClosed) _changes.add(ledgerId);
  }

  /// Stops broadcasting. For tests; the app holds one of these for its life.
  Future<void> close() => _changes.close();
}
