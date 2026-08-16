import 'dart:async';

import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

import 'fake_auth_repository.dart';

/// In-memory stand-in for [LedgerRepository].
///
/// Starts with one personal ledger, which is what a reader who has never made a
/// family account has — so a page pumped with the defaults behaves like the
/// ordinary case rather than like an empty switcher.
class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository({List<Ledger>? initial, String? activeId})
    : _ledgers = initial ?? [personal],
      _activeId = activeId ?? (initial?.firstOrNull ?? personal).id;

  /// The signed-in reader, matching the id [FakeAuthRepository] signs in as —
  /// the sheet asks the session who is reading, and a mismatch would describe
  /// the reader as their own partner.
  static const viewerId = 'user-1';

  /// The other person in [family].
  static const partnerId = 'user-2';

  /// What both family paths refuse with, so a test can match either.
  static const _alreadyInAFamily =
      'You are already in a family account. Leave it before joining or '
      'starting another.';

  /// The book a fresh reader opens into.
  ///
  /// `final` rather than `const` because its id is the one the app derives from
  /// the user id — the same value `personalLedgerId` produces. Anything that asks
  /// "is this the first book, the one that cannot be removed?" compares against
  /// that, so a made-up id here would make the fake disagree with the app.
  static final personal = Ledger(
    id: personalLedgerId(viewerId),
    name: 'Personal',
    kind: LedgerKind.personal,
    members: const [
      LedgerMember(userId: viewerId, role: LedgerRole.owner),
    ],
  );

  /// A family account with a partner in it, for the cases that need one.
  static const family = Ledger(
    id: 'ledger-family',
    name: 'Home',
    kind: LedgerKind.family,
    inviteCode: 'ABC123',
    members: [
      LedgerMember(userId: viewerId, role: LedgerRole.owner),
      LedgerMember(
        userId: partnerId,
        role: LedgerRole.member,
        displayName: 'kate@example.com',
      ),
    ],
  );

  List<Ledger> _ledgers;
  String _activeId;

  final _ledgersController = StreamController<List<Ledger>>.broadcast();
  final _activeIdController = StreamController<String>.broadcast();

  /// Set to have any write fail.
  Exception? writeError;

  /// What [joinFamilyLedger] hands back. Null makes it fail as an unknown code.
  Ledger? joinable;

  @override
  String get activeId => _activeId;

  @override
  Stream<List<Ledger>> watchLedgers() async* {
    yield _ledgers;
    yield* _ledgersController.stream;
  }

  @override
  Future<String> resolveActive() async => _activeId;

  @override
  Future<void> select(String ledgerId) async {
    if (writeError case final error?) throw error;
    if (!_ledgers.any((ledger) => ledger.id == ledgerId)) {
      throw const LedgerFailure('That account is not yours to open');
    }

    _activeId = ledgerId;
    _activeIdController.add(ledgerId);
    _ledgersController.add(_ledgers);
  }

  @override
  Future<Ledger> createPersonalLedger(String name) async {
    if (writeError case final error?) throw error;
    if (_personalCount >= LedgerLimits.personal) {
      throw const LedgerFailure(
        'You can have up to ${LedgerLimits.personal} accounts of your own. '
        'Remove one to make another.',
      );
    }

    final created = Ledger(
      id: newId(),
      name: name.trim().isEmpty ? 'Another account' : name.trim(),
      kind: LedgerKind.personal,
      members: const [LedgerMember(userId: viewerId, role: LedgerRole.owner)],
    );

    _ledgers = [..._ledgers, created];
    _ledgersController.add(_ledgers);
    return created;
  }

  @override
  Future<Ledger> createFamilyLedger(String name) async {
    if (writeError case final error?) throw error;
    if (_hasFamily) throw const LedgerFailure(_alreadyInAFamily);

    final created = Ledger(
      id: newId(),
      name: name.trim().isEmpty ? 'Family' : name.trim(),
      kind: LedgerKind.family,
      inviteCode: 'NEWCDE',
      members: const [LedgerMember(userId: viewerId, role: LedgerRole.owner)],
    );

    _ledgers = [..._ledgers, created];
    _ledgersController.add(_ledgers);
    return created;
  }

  @override
  Future<Ledger> joinFamilyLedger(String code) async {
    if (writeError case final error?) throw error;
    if (_hasFamily) throw const LedgerFailure(_alreadyInAFamily);

    final target = joinable;
    if (target == null) {
      throw const LedgerFailure('No family account with that code');
    }

    _ledgers = [..._ledgers, target];
    _ledgersController.add(_ledgers);
    return target;
  }

  @override
  Future<String> rotateInviteCode(String ledgerId) async {
    if (writeError case final error?) throw error;

    _ledgers = [
      for (final ledger in _ledgers)
        if (ledger.id == ledgerId)
          Ledger(
            id: ledger.id,
            name: ledger.name,
            kind: ledger.kind,
            inviteCode: 'ROTATE',
            members: ledger.members,
          )
        else
          ledger,
    ];
    _ledgersController.add(_ledgers);
    return 'ROTATE';
  }

  @override
  Future<void> leave(String ledgerId) async {
    if (writeError case final error?) throw error;
    if (ledgerId == personal.id) {
      throw const LedgerFailure('Your own account is not one you can leave');
    }

    _ledgers = _ledgers.where((ledger) => ledger.id != ledgerId).toList();
    if (_activeId == ledgerId) {
      _activeId = personal.id;
      _activeIdController.add(_activeId);
    }
    _ledgersController.add(_ledgers);
  }

  @override
  Future<void> deletePersonalLedger(String ledgerId) async {
    if (writeError case final error?) throw error;
    if (ledgerId == personal.id) {
      throw const LedgerFailure('Your first account has to stay');
    }

    _ledgers = _ledgers.where((ledger) => ledger.id != ledgerId).toList();
    if (_activeId == ledgerId) {
      _activeId = personal.id;
      _activeIdController.add(_activeId);
    }
    _ledgersController.add(_ledgers);
  }

  @override
  Future<int> adoptUnscopedRows() async => 0;

  int get _personalCount => _ledgers.where((l) => l.isPersonal).length;

  bool get _hasFamily => _ledgers.any((ledger) => ledger.isFamily);

  Future<void> close() async {
    await _ledgersController.close();
    await _activeIdController.close();
  }
}
