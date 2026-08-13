import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/data/datasources/ledger_local_data_source.dart';
import 'package:my_pnl/features/ledgers/data/repositories/ledger_repository_impl.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/active_ledger_store.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// A [SessionOwner] a test can move between users.
class _FakeOwner implements SessionOwner {
  _FakeOwner(this.id, {this.label});

  @override
  String id;

  @override
  String? label;
}

/// An [ActiveLedgerStore] held in memory.
class _FakeStore implements ActiveLedgerStore {
  String? stored;

  /// Every write, so a test can tell "left alone" from "written back the same".
  final writes = <String>[];

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String ledgerId) async {
    stored = ledgerId;
    writes.add(ledgerId);
  }
}

void main() {
  group('LedgerRepositoryImpl', () {
    late AppDatabase db;
    late LedgerLocalDataSource local;
    late _FakeOwner owner;
    late _FakeStore store;
    late ActiveLedger active;

    const userId = 'user-1';

    /// What the invite source hands back, or null to have it refuse.
    String? redeemable;
    late List<String> redeemedCodes;

    LedgerRepositoryImpl build() => LedgerRepositoryImpl(
      localDataSource: local,
      inviteSource: ({required code, displayName}) async {
        redeemedCodes.add(code);
        final target = redeemable;
        if (target == null) {
          throw const LedgerFailure('No family account with that code');
        }
        return target;
      },
      activeLedgerStore: store,
      sessionOwner: owner,
      activeLedger: active,
    );

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = LedgerLocalDataSource(db, random: Random(3));
      owner = _FakeOwner(userId, label: 'me@example.com');
      store = _FakeStore();
      active = ActiveLedger(personalLedgerId(userId));
      redeemable = null;
      redeemedCodes = [];
    });

    tearDown(() async {
      await active.close();
      await db.close();
    });

    group('settling which book to open', () {
      test('creates the personal one and opens it', () async {
        final repository = build();

        final opened = await repository.resolveActive();

        expect(opened, personalLedgerId(userId));
        expect(repository.activeId, opened);
        expect(await db.select(db.ledgers).get(), hasLength(1));
      });

      test('honours the book this device was left on', () async {
        final repository = build();
        final family = await local.createFamilyLedger(
          ownerId: userId,
          name: 'Home',
        );
        store.stored = family.id;

        expect(await repository.resolveActive(), family.id);
      });

      test('falls back when the remembered book is not the reader’s', () async {
        // A device somebody else signed into: the membership row never arrives,
        // so the remembered choice can never be honoured.
        final repository = build();
        store.stored = 'ledger-belonging-to-nobody-here';

        expect(await repository.resolveActive(), personalLedgerId(userId));
      });

      test('does not forget the remembered book when it falls back', () async {
        final repository = build();
        store.stored = 'ledger-not-synced-yet';

        await repository.resolveActive();

        // On a cold start the membership rows may simply not have arrived yet.
        // Overwriting the choice here would move a reader out of their family
        // account permanently, for a sync that was a second away.
        expect(store.stored, 'ledger-not-synced-yet');
        expect(store.writes, isEmpty);
      });

      test('settles again for a different user on the same device', () async {
        final repository = build();
        await repository.resolveActive();

        owner.id = 'user-2';
        expect(await repository.resolveActive(), personalLedgerId('user-2'));
      });
    });

    group('switching', () {
      test('moves the scope and remembers it', () async {
        final repository = build();
        final family = await local.createFamilyLedger(
          ownerId: userId,
          name: 'Home',
        );

        await repository.select(family.id);

        expect(repository.activeId, family.id);
        expect(store.stored, family.id);
      });

      test('announces the switch, so open reads re-run', () async {
        final repository = build();
        final family = await local.createFamilyLedger(
          ownerId: userId,
          name: 'Home',
        );

        // What every watch stream in the app is built over: this firing is what
        // makes a page already on screen read the book just opened.
        final seen = active.changes.take(2).toList();
        await repository.select(family.id);

        expect(await seen, [personalLedgerId(userId), family.id]);
      });

      test('refuses a book the reader is not in', () async {
        final repository = build();
        final theirs = await local.createFamilyLedger(
          ownerId: 'someone-else',
          name: 'Theirs',
        );

        // Writing there would produce rows the server refuses on upload, so the
        // refusal happens before anything is written rather than after.
        await expectLater(
          repository.select(theirs.id),
          throwsA(isA<LedgerFailure>()),
        );
        expect(repository.activeId, personalLedgerId(userId));
      });
    });

    group('creating a family account', () {
      test('names the creator as its member', () async {
        final repository = build();

        final created = await repository.createFamilyLedger('Home');

        expect(created.members.single.userId, userId);
        expect(created.members.single.label, 'me');
      });
    });

    group('joining', () {
      test('redeems the code upper-cased and trimmed', () async {
        final repository = build();
        final family = await local.createFamilyLedger(
          ownerId: 'someone-else',
          name: 'Theirs',
        );
        redeemable = family.id;

        // The membership is added *after* the call, because that is the order it
        // happens in: the server writes it and sync brings it down. Adding it
        // first would also make this reader look like someone already in a family
        // account, which is the one thing joining refuses.
        final joining = repository.joinFamilyLedger('  abc123 ');
        await local.ensureMembership(
          ledgerId: family.id,
          userId: userId,
          role: LedgerRole.member,
        );

        expect(redeemedCodes, ['ABC123']);
        expect((await joining).id, family.id);
      });

      test('refuses before asking the server when already in one', () async {
        final repository = build();
        final ours = await local.createFamilyLedger(
          ownerId: userId,
          name: 'Home',
        );
        redeemable = ours.id;

        await expectLater(
          repository.joinFamilyLedger('ABC123'),
          throwsA(isA<LedgerFailure>()),
        );
        // Redeeming first and refusing after would have put them in two
        // households before anyone noticed.
        expect(redeemedCodes, isEmpty);
      });

      test('refuses an empty code without asking the server', () async {
        final repository = build();

        await expectLater(
          repository.joinFamilyLedger('   '),
          throwsA(isA<LedgerFailure>()),
        );
        expect(redeemedCodes, isEmpty);
      });

      test('passes the failure on when the code matches nothing', () async {
        final repository = build();

        await expectLater(
          repository.joinFamilyLedger('NOPE12'),
          throwsA(isA<LedgerFailure>()),
        );
      });

      test('waits for the membership as well as the book', () async {
        final repository = build();
        // Sync has brought the ledger row but not the row admitting the reader.
        // Returning here would hand back a book `select` is about to refuse.
        final family = await local.createFamilyLedger(
          ownerId: 'someone-else',
          name: 'Theirs',
        );
        redeemable = family.id;

        final joining = repository.joinFamilyLedger('ABC123');

        await local.ensureMembership(
          ledgerId: family.id,
          userId: userId,
          role: LedgerRole.member,
          displayName: 'me@example.com',
        );

        final joined = await joining;
        expect(joined.members.map((member) => member.userId), contains(userId));
      });
    });

    group('leaving', () {
      test('moves the reader back to their own book', () async {
        final repository = build();
        final family = await local.createFamilyLedger(
          ownerId: userId,
          name: 'Home',
        );
        await repository.select(family.id);

        await repository.leave(family.id);

        expect(repository.activeId, personalLedgerId(userId));
        expect(store.stored, personalLedgerId(userId));
      });

      test('stays where it is when another book was open', () async {
        final repository = build();
        await repository.resolveActive();
        final family = await local.createFamilyLedger(
          ownerId: userId,
          name: 'Home',
        );

        await repository.leave(family.id);

        expect(repository.activeId, personalLedgerId(userId));
      });

      test('refuses to leave the personal book', () async {
        final repository = build();
        await repository.resolveActive();

        await expectLater(
          repository.leave(personalLedgerId(userId)),
          throwsA(isA<LedgerFailure>()),
        );
        expect(await db.select(db.ledgerMembers).get(), hasLength(1));
      });
    });
  });
}
