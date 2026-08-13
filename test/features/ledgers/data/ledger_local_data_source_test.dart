import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/data/datasources/ledger_local_data_source.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

void main() {
  group('LedgerLocalDataSource', () {
    late AppDatabase db;
    late LedgerLocalDataSource dataSource;

    const owner = 'user-1';
    const partner = 'user-2';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Seeded rather than secure, so a code in an expectation is the code the
      // test will actually get.
      dataSource = LedgerLocalDataSource(db, random: Random(7));
    });

    tearDown(() async {
      await db.close();
    });

    group('the personal ledger', () {
      test('is created on first use, at an id derived from the user', () async {
        final id = await dataSource.ensurePersonalLedger(userId: owner);

        expect(id, personalLedgerId(owner));

        final row = await db.select(db.ledgers).getSingle();
        expect(row.name, LedgerLocalDataSource.personalLedgerName);
        expect(row.kind, LedgerKind.personal.storage);
        expect(row.inviteCode, isNull, reason: 'nobody can join it');
      });

      test('is not created twice', () async {
        // Two devices of the same user, neither having synced. Both work out the
        // same id, so the second is a no-op rather than a second book that can
        // never be merged.
        final first = await dataSource.ensurePersonalLedger(userId: owner);
        final second = await dataSource.ensurePersonalLedger(userId: owner);

        expect(second, first);
        expect(await db.select(db.ledgers).get(), hasLength(1));
        expect(await db.select(db.ledgerMembers).get(), hasLength(1));
      });

      test('admits its user as the owner', () async {
        await dataSource.ensurePersonalLedger(
          userId: owner,
          displayName: 'me@example.com',
        );

        final member = await db.select(db.ledgerMembers).getSingle();
        expect(member.userId, owner);
        expect(member.role, LedgerRole.owner.storage);
        expect(member.displayName, 'me@example.com');
      });

      test('refreshes the name on a later call', () async {
        await dataSource.ensurePersonalLedger(userId: owner);
        await dataSource.ensurePersonalLedger(
          userId: owner,
          displayName: 'me@example.com',
        );

        final member = await db.select(db.ledgerMembers).getSingle();
        expect(member.displayName, 'me@example.com');
      });

      test('gives a different user a different one', () async {
        final mine = await dataSource.ensurePersonalLedger(userId: owner);
        final theirs = await dataSource.ensurePersonalLedger(userId: partner);

        expect(theirs, isNot(mine));
      });
    });

    group('a family account', () {
      test('is created with a code and its creator inside', () async {
        final created = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
          displayName: 'me@example.com',
        );

        expect(created.name, 'Home');
        expect(created.kind, LedgerKind.family);
        expect(created.inviteCode, hasLength(6));
        expect(created.members.single.userId, owner);
        expect(created.members.single.isOwner, isTrue);
      });

      test('draws its code from an alphabet with no lookalikes', () async {
        final created = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );

        // These get read out loud and typed in by someone else, so the pairs
        // that look alike in most fonts are left out.
        expect(created.inviteCode, isNot(matches('[O0I1]')));
        for (final char in created.inviteCode!.split('')) {
          expect(LedgerLocalDataSource.inviteCodeAlphabet, contains(char));
        }
      });

      test('falls back to a name when given none', () async {
        final created = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: '   ',
        );

        expect(created.name, LedgerLocalDataSource.defaultFamilyName);
      });

      test('rotating replaces the code', () async {
        final created = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );

        final rotated = await dataSource.rotateInviteCode(
          ledgerId: created.id,
          ownerId: owner,
        );

        expect(rotated, isNot(created.inviteCode));
        final row = await db.select(db.ledgers).getSingle();
        expect(row.inviteCode, rotated);
      });

      test('only the creator may rotate the code', () async {
        final created = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );

        // A partner who could rotate it would be able to lock the creator's
        // other invites out of a book that is not theirs.
        await expectLater(
          dataSource.rotateInviteCode(ledgerId: created.id, ownerId: partner),
          throwsA(isA<LedgerFailure>()),
        );
      });
    });

    group('the list of books', () {
      test('holds only the ones the reader is a member of', () async {
        await dataSource.ensurePersonalLedger(userId: owner);
        final theirs = await dataSource.createFamilyLedger(
          ownerId: partner,
          name: 'Someone else',
        );

        final mine = await dataSource.watchLedgers(owner).first;

        expect(mine.map((ledger) => ledger.id), [personalLedgerId(owner)]);
        expect(
          mine.map((ledger) => ledger.id),
          isNot(contains(theirs.id)),
          reason: 'the data is on the device; the membership is not',
        );
      });

      test('puts the personal book first', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );
        await dataSource.ensurePersonalLedger(userId: owner);

        final mine = await dataSource.watchLedgers(owner).first;

        expect(mine.map((ledger) => ledger.id), [
          personalLedgerId(owner),
          family.id,
        ]);
      });

      test('carries every member, so a partner can be named', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );
        await dataSource.ensureMembership(
          ledgerId: family.id,
          userId: partner,
          role: LedgerRole.member,
          displayName: 'kate@example.com',
        );

        final mine = await dataSource.watchLedgers(owner).first;

        expect(mine.single.isShared, isTrue);
        expect(mine.single.partnersOf(owner).single.label, 'kate');
      });

      test('leaves out a tombstoned book', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );

        await (db.update(db.ledgers)..where((row) => row.id.equals(family.id)))
            .write(LedgersCompanion(deletedAt: Value(DateTime.now().toUtc())));

        expect(await dataSource.watchLedgers(owner).first, isEmpty);
      });
    });

    group('leaving', () {
      test('drops the membership row outright', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );
        await dataSource.ensureMembership(
          ledgerId: family.id,
          userId: partner,
          role: LedgerRole.member,
        );

        await dataSource.leave(ledgerId: family.id, userId: partner);

        // A hard delete, which nothing else in this app does: a tombstoned
        // access grant would go on matching the sync rule's bucket forever,
        // because a parameter query cannot filter on `deleted_at`.
        final members = await db.select(db.ledgerMembers).get();
        expect(members.map((row) => row.userId), [owner]);
      });

      test('leaves the other member reading the book', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );
        await dataSource.ensureMembership(
          ledgerId: family.id,
          userId: partner,
          role: LedgerRole.member,
        );

        await dataSource.leave(ledgerId: family.id, userId: partner);

        expect(
          (await dataSource.watchLedgers(owner).first).single.id,
          family.id,
        );
        expect(await dataSource.watchLedgers(partner).first, isEmpty);
      });
    });

    group('the limits', () {
      test('allows up to three books of the reader\'s own', () async {
        await dataSource.ensurePersonalLedger(userId: owner);
        await dataSource.createPersonalLedger(
          ownerId: owner,
          name: 'Side business',
        );
        await dataSource.createPersonalLedger(ownerId: owner, name: 'Travel');

        expect(
          await dataSource.personalLedgerCount(owner),
          LedgerLimits.personal,
        );

        await expectLater(
          dataSource.createPersonalLedger(ownerId: owner, name: 'One too many'),
          throwsA(isA<LedgerFailure>()),
        );
      });

      test('counts the first book against the three', () async {
        // It is one of the reader's own like any other. Not counting it would
        // quietly make the limit four.
        await dataSource.ensurePersonalLedger(userId: owner);

        expect(await dataSource.personalLedgerCount(owner), 1);
      });

      test('frees a slot when one is removed', () async {
        await dataSource.ensurePersonalLedger(userId: owner);
        final extra = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: 'Side business',
        );
        await dataSource.createPersonalLedger(ownerId: owner, name: 'Travel');

        await dataSource.deletePersonalLedger(
          ledgerId: extra.id,
          ownerId: owner,
        );

        expect(await dataSource.personalLedgerCount(owner), 2);
        await expectLater(
          dataSource.createPersonalLedger(ownerId: owner, name: 'Another'),
          completes,
        );
      });

      test("does not count another user's books", () async {
        await dataSource.createPersonalLedger(ownerId: partner, name: 'Theirs');

        expect(await dataSource.personalLedgerCount(owner), 0);
      });

      test('allows one family account', () async {
        await dataSource.createFamilyLedger(ownerId: owner, name: 'Home');

        await expectLater(
          dataSource.createFamilyLedger(ownerId: owner, name: 'Another home'),
          throwsA(isA<LedgerFailure>()),
        );
      });

      test('counts a family account joined rather than created', () async {
        // The limit is on being in one. Somebody else's, joined, fills the slot
        // exactly as one of your own does.
        final theirs = await dataSource.createFamilyLedger(
          ownerId: partner,
          name: 'Theirs',
        );
        await dataSource.ensureMembership(
          ledgerId: theirs.id,
          userId: owner,
          role: LedgerRole.member,
        );

        expect(await dataSource.familyLedgerCount(owner), 1);
        await expectLater(
          dataSource.createFamilyLedger(ownerId: owner, name: 'Mine'),
          throwsA(isA<LedgerFailure>()),
        );
      });

      test('leaving frees the family slot', () async {
        final theirs = await dataSource.createFamilyLedger(
          ownerId: partner,
          name: 'Theirs',
        );
        await dataSource.ensureMembership(
          ledgerId: theirs.id,
          userId: owner,
          role: LedgerRole.member,
        );

        await dataSource.leave(ledgerId: theirs.id, userId: owner);

        expect(await dataSource.familyLedgerCount(owner), 0);
        await expectLater(
          dataSource.createFamilyLedger(ownerId: owner, name: 'Mine'),
          completes,
        );
      });

      test('a tombstoned book stops counting', () async {
        final extra = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );
        await dataSource.leave(ledgerId: extra.id, userId: owner);

        expect(await dataSource.familyLedgerCount(owner), 0);
      });
    });

    group('extra personal books', () {
      test('take the name they were given', () async {
        final created = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: '  Side business  ',
        );

        expect(created.name, 'Side business');
        expect(created.kind, LedgerKind.personal);
        expect(created.members.single.userId, owner);
      });

      test('fall back to a name when given none', () async {
        final created = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: '   ',
        );

        expect(created.name, LedgerLocalDataSource.defaultPersonalName);
      });

      test('get no invite code', () async {
        final created = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: 'Side business',
        );

        // Nobody can join one, and a code would put it in the pool the join
        // function searches.
        expect(created.inviteCode, isNull);
      });

      test('are not the first book, so they can be removed', () async {
        final created = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: 'Side business',
        );

        expect(created.id, isNot(personalLedgerId(owner)));
        await expectLater(
          dataSource.deletePersonalLedger(
            ledgerId: created.id,
            ownerId: owner,
          ),
          completes,
        );
      });

      test('sort after the first book and before the family one', () async {
        await dataSource.ensurePersonalLedger(userId: owner);
        await dataSource.createPersonalLedger(ownerId: owner, name: 'Travel');
        await dataSource.createFamilyLedger(ownerId: owner, name: 'Home');

        final mine = await dataSource.watchLedgers(owner).first;

        // A fixed order, and the first book leads it: that is the one every
        // fallback in the app lands on.
        expect(mine.map((ledger) => ledger.name), [
          LedgerLocalDataSource.personalLedgerName,
          'Travel',
          'Home',
        ]);
      });
    });

    group('removing a book of the reader\'s own', () {
      test('takes it out of the list', () async {
        await dataSource.ensurePersonalLedger(userId: owner);
        final extra = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: 'Side business',
        );

        await dataSource.deletePersonalLedger(
          ledgerId: extra.id,
          ownerId: owner,
        );

        final mine = await dataSource.watchLedgers(owner).first;
        expect(mine.map((ledger) => ledger.id), [personalLedgerId(owner)]);
      });

      test('leaves what was in it on disk', () async {
        final extra = await dataSource.createPersonalLedger(
          ownerId: owner,
          name: 'Side business',
        );
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                ownerId: owner,
                ledgerId: Value(extra.id),
                name: 'Stock',
                colorArgb: 1,
                iconKey: 'g',
              ),
            );

        await dataSource.deletePersonalLedger(
          ledgerId: extra.id,
          ownerId: owner,
        );

        // Unreachable rather than erased — every read narrows to a ledger first —
        // which is what makes a mistake here recoverable by hand.
        expect(await db.select(db.categories).get(), hasLength(1));
      });

      test('refuses the first book', () async {
        final first = await dataSource.ensurePersonalLedger(userId: owner);

        await expectLater(
          dataSource.deletePersonalLedger(ledgerId: first, ownerId: owner),
          throwsA(isA<LedgerFailure>()),
        );
      });

      test('refuses a family account, which is left instead', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );

        // Removing it would take the book away from the partner too, along with
        // the history they are still reading.
        await expectLater(
          dataSource.deletePersonalLedger(
            ledgerId: family.id,
            ownerId: owner,
          ),
          throwsA(isA<LedgerFailure>()),
        );
      });

      test("refuses somebody else's book", () async {
        final theirs = await dataSource.createPersonalLedger(
          ownerId: partner,
          name: 'Theirs',
        );

        await expectLater(
          dataSource.deletePersonalLedger(
            ledgerId: theirs.id,
            ownerId: owner,
          ),
          throwsA(isA<LedgerFailure>()),
        );
      });
    });

    group('adopting rows written before ledgers existed', () {
      /// A row in each scoped table, with no ledger — which is how everything on
      /// a device looks on the first launch after the upgrade.
      Future<String> seedUnscoped({String ownerId = owner}) async {
        final account = await db
            .into(db.accounts)
            .insertReturning(
              AccountsCompanion.insert(
                ownerId: ownerId,
                name: 'Cash',
                currency: 'USD',
              ),
            );
        final category = await db
            .into(db.categories)
            .insertReturning(
              CategoriesCompanion.insert(
                ownerId: ownerId,
                name: 'Groceries',
                colorArgb: 1,
                iconKey: 'g',
              ),
            );
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                ownerId: ownerId,
                accountId: account.id,
                categoryId: Value(category.id),
                side: TradeSide.buy,
                amountScaled: -1250,
                currency: 'USD',
                executedAt: DateTime.utc(2026, 3, 14),
              ),
            );
        await db
            .into(db.currencies)
            .insert(
              CurrenciesCompanion.insert(
                ownerId: ownerId,
                ticker: 'EUR',
                exchangeRateScaled: 1080000,
              ),
            );
        await db
            .into(db.debts)
            .insert(
              DebtsCompanion.insert(
                ownerId: ownerId,
                counterparty: 'Alex',
                direction: 'owed_to_me',
                amountScaled: 2500,
              ),
            );
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                ownerId: ownerId,
                targetAmountScaled: 500000,
              ),
            );

        return category.id;
      }

      test('points every one of them at the personal ledger', () async {
        await seedUnscoped();

        final moved = await dataSource.adoptUnscopedRows(owner);

        expect(moved, 6, reason: 'one row in each scoped table');
        final ledgerId = personalLedgerId(owner);
        expect(
          (await db.select(db.transactions).getSingle()).ledgerId,
          ledgerId,
        );
        expect((await db.select(db.categories).getSingle()).ledgerId, ledgerId);
        expect((await db.select(db.accounts).getSingle()).ledgerId, ledgerId);
        expect((await db.select(db.currencies).getSingle()).ledgerId, ledgerId);
        expect((await db.select(db.debts).getSingle()).ledgerId, ledgerId);
        expect((await db.select(db.goals).getSingle()).ledgerId, ledgerId);
      });

      test('is a no-op the second time', () async {
        await seedUnscoped();

        expect(await dataSource.adoptUnscopedRows(owner), 6);
        expect(await dataSource.adoptUnscopedRows(owner), 0);
      });

      test('leaves a row that already has a ledger where it is', () async {
        final family = await dataSource.createFamilyLedger(
          ownerId: owner,
          name: 'Home',
        );
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                ownerId: owner,
                ledgerId: Value(family.id),
                name: 'Shared',
                colorArgb: 1,
                iconKey: 'g',
              ),
            );

        expect(await dataSource.adoptUnscopedRows(owner), 0);
        expect(
          (await db.select(db.categories).getSingle()).ledgerId,
          family.id,
        );
      });

      test("does not touch somebody else's unscoped rows", () async {
        await seedUnscoped(ownerId: partner);

        expect(await dataSource.adoptUnscopedRows(owner), 0);
        expect((await db.select(db.transactions).getSingle()).ledgerId, isNull);
      });

      test('bumps updated_at so the change uploads', () async {
        await seedUnscoped();
        final before = (await db.select(db.transactions).getSingle()).updatedAt;

        await dataSource.adoptUnscopedRows(owner);

        final after = (await db.select(db.transactions).getSingle()).updatedAt;
        expect(after.isBefore(before), isFalse);
      });
    });
  });
}
