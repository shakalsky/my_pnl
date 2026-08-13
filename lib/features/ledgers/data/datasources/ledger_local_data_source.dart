import 'dart:math';

import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Drift queries behind the ledger repository.
class LedgerLocalDataSource {
  LedgerLocalDataSource(this._db, {Random? random})
    : _random = random ?? Random.secure();

  final AppDatabase _db;

  /// Where invite codes come from. `Random.secure()` by default, because a
  /// guessable code is a way into someone's spending.
  final Random _random;

  /// The name a user's own ledger is created with.
  static const personalLedgerName = 'Personal';

  /// What a family account is called when the reader gives no name.
  static const defaultFamilyName = 'Family';

  /// What an extra personal book is called when the reader gives no name.
  static const defaultPersonalName = 'Another account';

  /// How long an invite code is.
  static const inviteCodeLength = 6;

  /// The alphabet invite codes are drawn from.
  ///
  /// No `O`, `0`, `I` or `1`: these get read out loud and typed in by someone
  /// else, and the pairs that look alike in most fonts are the ones that turn a
  /// working code into "no family account with that code".
  static const inviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// How many times to re-roll a code that is already taken locally.
  ///
  /// A collision needs 32^6 to line up, so this is a guard against a broken
  /// [Random] rather than something anyone will hit. Postgres has the real
  /// unique index.
  static const _codeAttempts = 8;

  /// Ledgers [userId] is a member of, with everyone in them.
  ///
  /// Driven from the membership table rather than from `ledgers`: a membership
  /// row is what grants access, so joining from this side means a ledger cannot
  /// appear before the row that admits the reader to it. One query rather than
  /// one per ledger, because the members are wanted for every row anyway — they
  /// are what labels a partner's entries.
  Stream<List<Ledger>> watchLedgers(String userId) {
    final query = _db.select(_db.ledgerMembers).join([
      innerJoin(
        _db.ledgers,
        _db.ledgers.id.equalsExp(_db.ledgerMembers.ledgerId) &
            _db.ledgers.deletedAt.isNull(),
      ),
    ]);

    return query.watch().map((rows) {
      final ledgers = <String, LedgerRow>{};
      final members = <String, List<LedgerMember>>{};

      for (final row in rows) {
        final ledger = row.readTable(_db.ledgers);
        final member = row.readTable(_db.ledgerMembers);

        ledgers[ledger.id] = ledger;
        (members[ledger.id] ??= []).add(
          LedgerMember(
            userId: member.userId,
            role: LedgerRole.fromStorage(member.role),
            displayName: member.displayName,
          ),
        );
      }

      final mine = <Ledger>[];

      for (final ledger in ledgers.values) {
        final inIt = members[ledger.id] ?? const <LedgerMember>[];
        // A ledger whose membership row for this reader has not arrived — or has
        // been removed — is not theirs to open, however much of its data is
        // still sitting on the device.
        if (inIt.any((member) => member.userId == userId)) {
          mine.add(_toEntity(ledger, inIt));
        }
      }

      // The reader's first book, then their others by name, then the family
      // account. A fixed order rather than one that depends on when rows arrived,
      // so the switcher does not reshuffle as memberships sync in — and the first
      // book leads because it is the one every fallback in the app lands on.
      final firstId = personalLedgerId(userId);

      mine.sort((a, b) {
        if (a.id != b.id) {
          if (a.id == firstId) return -1;
          if (b.id == firstId) return 1;
        }
        if (a.isFamily != b.isFamily) return a.isFamily ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return mine;
    });
  }

  /// One ledger with its members, or null when it is not on this device.
  Stream<Ledger?> watchLedger(String ledgerId) {
    final query = _db.select(_db.ledgers).join([
      leftOuterJoin(
        _db.ledgerMembers,
        _db.ledgerMembers.ledgerId.equalsExp(_db.ledgers.id),
      ),
    ])..where(_db.ledgers.id.equals(ledgerId) & _db.ledgers.deletedAt.isNull());

    return query.watch().map((rows) {
      if (rows.isEmpty) return null;

      return _toEntity(rows.first.readTable(_db.ledgers), [
        for (final row in rows)
          if (row.readTableOrNull(_db.ledgerMembers) case final member?)
            LedgerMember(
              userId: member.userId,
              role: LedgerRole.fromStorage(member.role),
              displayName: member.displayName,
            ),
      ]);
    });
  }

  /// Creates [userId]'s own ledger if they have none, and returns its id.
  ///
  /// The id is derived from the user id, so this is safe to call from every
  /// device at once: they all compute the same id and the second insert is an
  /// upsert on a known key rather than a second personal ledger nobody can
  /// merge.
  Future<String> ensurePersonalLedger({
    required String userId,
    String? displayName,
  }) async {
    final id = personalLedgerId(userId);

    // Tombstones are not filtered out: a personal ledger is not something the
    // app deletes, and reviving one that somehow was beats writing a second row
    // at an id that is already taken.
    final existing =
        await (_db.select(_db.ledgers)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.ledgers)
          .insert(
            LedgersCompanion.insert(
              id: Value(id),
              ownerId: userId,
              name: personalLedgerName,
              kind: LedgerKind.personal.storage,
            ),
          );
    }

    await ensureMembership(
      ledgerId: id,
      userId: userId,
      role: LedgerRole.owner,
      displayName: displayName,
    );

    return id;
  }

  /// Creates another book of [ownerId]'s own, at a random id.
  ///
  /// Random rather than derived, unlike [ensurePersonalLedger]: only one book has
  /// to be worked out the same way on every device, and this is not it. A second
  /// device that has not synced cannot know which of the reader's extra books
  /// this was meant to be, so a UUIDv7 is the honest answer — two devices
  /// creating one at once make two books, which is what happened.
  Future<Ledger> createPersonalLedger({
    required String ownerId,
    required String name,
    String? displayName,
  }) async {
    await requireRoomForPersonal(ownerId);

    final trimmed = name.trim();

    final row = await _db
        .into(_db.ledgers)
        .insertReturning(
          LedgersCompanion.insert(
            ownerId: ownerId,
            name: trimmed.isEmpty ? defaultPersonalName : trimmed,
            kind: LedgerKind.personal.storage,
            // No invite code: a personal book is not one anybody else can join,
            // and giving it one would put it in the pool `join_ledger_by_code`
            // searches.
          ),
        );

    await ensureMembership(
      ledgerId: row.id,
      userId: ownerId,
      role: LedgerRole.owner,
      displayName: displayName,
    );

    return _toEntity(row, [
      LedgerMember(
        userId: ownerId,
        role: LedgerRole.owner,
        displayName: displayName,
      ),
    ]);
  }

  /// How many live books of their own [ownerId] has.
  ///
  /// Counted by owner rather than by membership, which for a personal book is the
  /// same set — nobody else is ever in one — and is the count the Postgres policy
  /// makes too.
  Future<int> personalLedgerCount(String ownerId) async {
    final rows =
        await (_db.select(_db.ledgers)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.kind.equals(LedgerKind.personal.storage) &
                  row.deletedAt.isNull(),
            ))
            .get();

    return rows.length;
  }

  /// How many live family accounts [userId] is in.
  ///
  /// By membership rather than by owner: one they joined counts against the limit
  /// exactly as one they made does.
  Future<int> familyLedgerCount(String userId) async {
    final rows = await (_db.select(_db.ledgerMembers).join([
      innerJoin(
        _db.ledgers,
        _db.ledgers.id.equalsExp(_db.ledgerMembers.ledgerId) &
            _db.ledgers.kind.equals(LedgerKind.family.storage) &
            _db.ledgers.deletedAt.isNull(),
      ),
    ])..where(_db.ledgerMembers.userId.equals(userId))).get();

    return rows.length;
  }

  /// Throws unless [ownerId] has room for another book of their own.
  Future<void> requireRoomForPersonal(String ownerId) async {
    if (await personalLedgerCount(ownerId) < LedgerLimits.personal) return;

    throw const LedgerFailure(
      'You can have up to ${LedgerLimits.personal} accounts of your own. '
      'Remove one to make another.',
    );
  }

  /// Throws unless [userId] has room to be in a family account.
  ///
  /// Public, unlike its personal counterpart's usual shape, because joining has
  /// to ask before it goes to the server: adding the reader and then telling them
  /// it was not allowed would leave them in two households.
  Future<void> requireRoomForFamily(String userId) async {
    if (await familyLedgerCount(userId) < LedgerLimits.family) return;

    throw const LedgerFailure(
      'You are already in a family account. Leave it before joining or '
      'starting another.',
    );
  }

  /// Creates a family account owned by [ownerId], with a code to share.
  Future<Ledger> createFamilyLedger({
    required String ownerId,
    required String name,
    String? displayName,
  }) async {
    await requireRoomForFamily(ownerId);

    final trimmed = name.trim();

    final row = await _db
        .into(_db.ledgers)
        .insertReturning(
          LedgersCompanion.insert(
            ownerId: ownerId,
            name: trimmed.isEmpty ? defaultFamilyName : trimmed,
            kind: LedgerKind.family.storage,
            inviteCode: Value(await _freeInviteCode()),
          ),
        );

    await ensureMembership(
      ledgerId: row.id,
      userId: ownerId,
      role: LedgerRole.owner,
      displayName: displayName,
    );

    final member = LedgerMember(
      userId: ownerId,
      role: LedgerRole.owner,
      displayName: displayName,
    );

    return _toEntity(row, [member]);
  }

  /// Writes the membership row admitting [userId] to [ledgerId].
  ///
  /// At an id derived from the pair, so calling it twice — or from two devices —
  /// is one row. [displayName] is refreshed when it is given, which is how a
  /// member's own device keeps the name their partner sees up to date.
  Future<void> ensureMembership({
    required String ledgerId,
    required String userId,
    required LedgerRole role,
    String? displayName,
  }) async {
    final id = ledgerMemberId(ledgerId: ledgerId, userId: userId);

    final existing =
        await (_db.select(_db.ledgerMembers)
              ..where((row) => row.id.equals(id))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.ledgerMembers)
          .insert(
            LedgerMembersCompanion.insert(
              id: Value(id),
              ledgerId: ledgerId,
              userId: userId,
              role: role.storage,
              displayName: Value(displayName),
            ),
          );
      return;
    }

    if (displayName == null || displayName == existing.displayName) return;

    await (_db.update(
      _db.ledgerMembers,
    )..where((row) => row.id.equals(id))).write(
      LedgerMembersCompanion(
        displayName: Value(displayName),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Whether [userId] may read and write [ledgerId].
  Future<bool> isMember({
    required String ledgerId,
    required String userId,
  }) async {
    final row =
        await (_db.select(_db.ledgerMembers)
              ..where(
                (row) =>
                    row.ledgerId.equals(ledgerId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();

    return row != null;
  }

  /// Replaces the invite code, revoking every invite not yet used.
  ///
  /// Scoped to the creator: a partner who could rotate the code would be able
  /// to lock the creator's other invites out of a book that is not theirs.
  Future<String> rotateInviteCode({
    required String ledgerId,
    required String ownerId,
  }) async {
    final row =
        await (_db.select(_db.ledgers)..where(
              (row) =>
                  row.id.equals(ledgerId) &
                  row.ownerId.equals(ownerId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) {
      throw const LedgerFailure('Only whoever created it can change the code');
    }

    final code = await _freeInviteCode();

    await (_db.update(_db.ledgers)..where((r) => r.id.equals(ledgerId))).write(
      LedgersCompanion(
        inviteCode: Value(code),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    return code;
  }

  /// Drops [userId]'s access to [ledgerId].
  ///
  /// A hard delete, which nothing else in this app does. A membership row is an
  /// access grant rather than history: a tombstone that still matched the sync
  /// rule's parameter query would go on granting access forever, and the
  /// parameter query cannot filter on `deleted_at`. The entries the leaver wrote
  /// are untouched — they are part of a history the other member is still
  /// reading.
  /// Leaving as the last member tombstones the ledger too. A book nobody is in
  /// is one nobody can open again, and its invite code would otherwise stay live
  /// — a partner could redeem it and find an empty account.
  Future<void> leave({
    required String ledgerId,
    required String userId,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.ledgerMembers)..where(
            (row) => row.ledgerId.equals(ledgerId) & row.userId.equals(userId),
          ))
          .go();

      final remaining =
          await (_db.select(_db.ledgerMembers)
                ..where((row) => row.ledgerId.equals(ledgerId))
                ..limit(1))
              .getSingleOrNull();

      if (remaining != null) return;

      final now = DateTime.now().toUtc();
      await (_db.update(_db.ledgers)..where(
            (row) => row.id.equals(ledgerId) & row.deletedAt.isNull(),
          ))
          .write(
            LedgersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
    });
  }

  /// Tombstones one of [ownerId]'s own books, and their membership of it.
  ///
  /// The rows inside it are left alone. Every read starts by narrowing to a
  /// ledger, so a tombstoned one takes its contents out of sight without a sweep
  /// that could half-finish — and if this was a mistake, the data is still there.
  ///
  /// Refuses the reader's first book: [ensurePersonalLedger] hands its id out as
  /// the answer to "which book, when nothing else is open", and the app leans on
  /// that always being there.
  Future<void> deletePersonalLedger({
    required String ledgerId,
    required String ownerId,
  }) async {
    if (ledgerId == personalLedgerId(ownerId)) {
      throw const LedgerFailure('Your first account has to stay');
    }

    final row =
        await (_db.select(_db.ledgers)..where(
              (row) =>
                  row.id.equals(ledgerId) &
                  row.ownerId.equals(ownerId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) {
      throw const LedgerFailure('That account is not yours to remove');
    }
    if (LedgerKind.fromStorage(row.kind) == LedgerKind.family) {
      // Removing it would take it away from the partner as well, and their
      // history with it. Leaving is the operation that only affects the leaver.
      throw const LedgerFailure(
        'Leave a family account rather than removing it',
      );
    }

    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await (_db.update(
        _db.ledgers,
      )..where((r) => r.id.equals(ledgerId))).write(
        LedgersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );

      // The membership goes for the same reason it does on leaving: it is an
      // access grant, and one to a book that no longer exists is worse than
      // untidy — the sync rule buckets on it.
      await (_db.delete(_db.ledgerMembers)..where(
            (r) => r.ledgerId.equals(ledgerId) & r.userId.equals(ownerId),
          ))
          .go();
    });
  }

  /// Points rows written before ledgers existed at their owner's personal
  /// ledger, and returns how many moved.
  ///
  /// Only [userId]'s own rows, because those are the only unscoped ones that can
  /// be here: a partner's row reaches this device by way of a ledger bucket, so
  /// it has a ledger by definition.
  Future<int> adoptUnscopedRows(String userId) async {
    final ledgerId = personalLedgerId(userId);
    final now = DateTime.now().toUtc();
    var moved = 0;

    // One transaction: a half-adopted device is one where some of the reader's
    // history is visible and the rest is not, which looks exactly like data
    // loss.
    await _db.transaction(() async {
      moved += await _stamp(
        _db.accounts,
        (row) => row.ledgerId.isNull() & row.ownerId.equals(userId),
        AccountsCompanion(ledgerId: Value(ledgerId), updatedAt: Value(now)),
      );
      moved += await _stamp(
        _db.categories,
        (row) => row.ledgerId.isNull() & row.ownerId.equals(userId),
        CategoriesCompanion(ledgerId: Value(ledgerId), updatedAt: Value(now)),
      );
      moved += await _stamp(
        _db.currencies,
        (row) => row.ledgerId.isNull() & row.ownerId.equals(userId),
        CurrenciesCompanion(ledgerId: Value(ledgerId), updatedAt: Value(now)),
      );
      moved += await _stamp(
        _db.debts,
        (row) => row.ledgerId.isNull() & row.ownerId.equals(userId),
        DebtsCompanion(ledgerId: Value(ledgerId), updatedAt: Value(now)),
      );
      moved += await _stamp(
        _db.goals,
        (row) => row.ledgerId.isNull() & row.ownerId.equals(userId),
        GoalsCompanion(ledgerId: Value(ledgerId), updatedAt: Value(now)),
      );
      moved += await _stamp(
        _db.transactions,
        (row) => row.ledgerId.isNull() & row.ownerId.equals(userId),
        TransactionsCompanion(ledgerId: Value(ledgerId), updatedAt: Value(now)),
      );
    });

    return moved;
  }

  /// Writes [values] over every row of [table] matching [filter], and returns
  /// how many that was.
  ///
  /// Counted with a SELECT first rather than from what the update reports:
  /// PowerSync's tables are views written through INSTEAD OF triggers, and
  /// SQLite does not count rows changed by such a trigger, so `write()` returns
  /// 0 even on success.
  Future<int> _stamp<T extends Table, D>(
    TableInfo<T, D> table,
    Expression<bool> Function(T row) filter,
    Insertable<D> values,
  ) async {
    final pending = await (_db.select(table)..where(filter)).get();
    if (pending.isEmpty) return 0;

    await (_db.update(table)..where(filter)).write(values);
    return pending.length;
  }

  /// A code no ledger on this device is using.
  Future<String> _freeInviteCode() async {
    for (var attempt = 0; attempt < _codeAttempts; attempt++) {
      final code = _inviteCode();

      final clash =
          await (_db.select(_db.ledgers)
                ..where(
                  (row) => row.inviteCode.equals(code) & row.deletedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();

      if (clash == null) return code;
    }

    throw const LedgerFailure('Could not come up with an invite code');
  }

  String _inviteCode() => String.fromCharCodes([
    for (var i = 0; i < inviteCodeLength; i++)
      inviteCodeAlphabet.codeUnitAt(_random.nextInt(inviteCodeAlphabet.length)),
  ]);

  Ledger _toEntity(LedgerRow row, List<LedgerMember> members) => Ledger(
    id: row.id,
    name: row.name,
    kind: LedgerKind.fromStorage(row.kind),
    inviteCode: row.inviteCode,
    members: members,
  );
}
