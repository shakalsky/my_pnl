import 'dart:async';

import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/data/datasources/ledger_invite_source.dart';
import 'package:my_pnl/features/ledgers/data/datasources/ledger_local_data_source.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/active_ledger_store.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Binds the ledger data sources to the domain contract.
///
/// Holds the one mutable piece of session state in the app: which ledger is
/// open. Every other repository reads that through [LedgerScope] at the moment
/// it runs a query, so switching is a matter of changing this value and letting
/// the app shell rebuild beneath itself — the same arrangement the base currency
/// uses. Nothing here re-subscribes on a switch, because everything watching is
/// torn down and asked again with the new scope.
class LedgerRepositoryImpl implements LedgerRepository {
  const LedgerRepositoryImpl({
    required LedgerLocalDataSource localDataSource,
    required LedgerInviteSource inviteSource,
    required ActiveLedgerStore activeLedgerStore,
    required SessionOwner sessionOwner,
    required ActiveLedger activeLedger,
  }) : _local = localDataSource,
       _invites = inviteSource,
       _store = activeLedgerStore,
       _owner = sessionOwner,
       _active = activeLedger;

  /// How long a join waits for the ledger it created on the server to arrive.
  ///
  /// Generous, because the alternative to waiting is a switcher that does not
  /// yet list the thing the reader has just joined. Exceeding it is not a
  /// failure — the membership exists either way — so what the reader is told
  /// says so.
  static const syncWait = Duration(seconds: 20);

  final LedgerLocalDataSource _local;
  final LedgerInviteSource _invites;
  final ActiveLedgerStore _store;
  final SessionOwner _owner;
  final ActiveLedger _active;

  @override
  String get activeId => _active.id;

  @override
  Stream<List<Ledger>> watchLedgers() => _local.watchLedgers(_owner.id);

  @override
  Future<String> resolveActive() async {
    final userId = _owner.id;

    final personal = await _local.ensurePersonalLedger(
      userId: userId,
      displayName: _owner.label,
    );

    final remembered = await _store.read();
    final known =
        remembered != null &&
        await _local.isMember(ledgerId: remembered, userId: userId);

    // The remembered choice is not written back over when it loses, and not
    // cleared either. On a cold start a family account's membership row may
    // simply not have synced yet, and forgetting the choice then would move the
    // reader out of their family account permanently. On a device somebody else
    // has signed into, the row never arrives and this quietly stays personal.
    final target = known ? remembered : personal;
    _active.switchTo(target);

    return target;
  }

  @override
  Future<void> select(String ledgerId) async {
    if (!await _local.isMember(ledgerId: ledgerId, userId: _owner.id)) {
      throw LedgerFailure(t.accounts.notYoursToOpen);
    }

    await _store.write(ledgerId);
    _active.switchTo(ledgerId);
  }

  @override
  Future<Ledger> createPersonalLedger(String name) =>
      _local.createPersonalLedger(
        ownerId: _owner.id,
        name: name,
        displayName: _owner.label,
      );

  @override
  Future<Ledger> createFamilyLedger(String name) => _local.createFamilyLedger(
    ownerId: _owner.id,
    name: name,
    displayName: _owner.label,
  );

  @override
  Future<Ledger> joinFamilyLedger(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw LedgerFailure(t.accounts.enterCode);
    }

    // Asked before the server is: redeeming first and refusing afterwards would
    // have already put the reader in a second household. The function in Postgres
    // makes the same check, because this one is only as good as the client.
    await _local.requireRoomForFamily(_owner.id);

    final ledgerId = await _invites(
      code: normalized,
      displayName: _owner.label,
    );

    // The membership was written on the server, so nothing is on this device
    // yet. Waiting rather than returning early: the caller's next move is to
    // open the ledger, and opening one the device has never heard of would show
    // an empty book.
    return _awaitLedger(ledgerId);
  }

  @override
  Future<String> rotateInviteCode(String ledgerId) =>
      _local.rotateInviteCode(ledgerId: ledgerId, ownerId: _owner.id);

  @override
  Future<void> leave(String ledgerId) async {
    if (ledgerId == personalLedgerId(_owner.id)) {
      throw LedgerFailure(t.accounts.cannotLeaveOwn);
    }

    await _local.leave(ledgerId: ledgerId, userId: _owner.id);

    if (_active.id == ledgerId) await _fallBackToFirstBook();
  }

  @override
  Future<void> deletePersonalLedger(String ledgerId) async {
    await _local.deletePersonalLedger(
      ledgerId: ledgerId,
      ownerId: _owner.id,
    );

    if (_active.id == ledgerId) await _fallBackToFirstBook();
  }

  @override
  Future<int> adoptUnscopedRows() => _local.adoptUnscopedRows(_owner.id);

  /// Opens the reader's first book, for when the one they were in has gone.
  ///
  /// Nothing would read from a ledger there is no longer any access to, so they
  /// are moved somewhere that exists rather than left looking at an empty one.
  Future<void> _fallBackToFirstBook() async {
    final first = personalLedgerId(_owner.id);
    await _store.write(first);
    _active.switchTo(first);
  }

  /// The ledger with this id, once sync has delivered it.
  Future<Ledger> _awaitLedger(String ledgerId) async {
    final arrived = Completer<Ledger>();

    final subscription = _local.watchLedger(ledgerId).listen((ledger) {
      // Not just the ledger row: until the membership row is here too, the
      // reader is not a member as far as this device is concerned, and `select`
      // would refuse to open it.
      final isMember = ledger?.members.any(
        (member) => member.userId == _owner.id,
      );

      if (ledger != null && (isMember ?? false) && !arrived.isCompleted) {
        arrived.complete(ledger);
      }
    }, onError: arrived.completeError);

    try {
      return await arrived.future.timeout(syncWait);
    } on TimeoutException {
      throw LedgerFailure(t.accounts.joinedPending);
    } finally {
      await subscription.cancel();
    }
  }
}
