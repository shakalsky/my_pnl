import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/usecases/record_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_spend.dart';
import 'package:my_pnl/features/spending/presentation/bloc/amount_entry/amount_entry_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _groceries = Category(
  id: 'category-1',
  name: 'Groceries',
  colorArgb: 0xFF3B7A57,
  iconKey: 'groceries',
);

void main() {
  group('AmountEntryBloc', () {
    late FakeCategoryRepository repository;

    setUp(() {
      repository = FakeCategoryRepository(
        initial: const [CategorySpend(category: _groceries, totalScaled: 500)],
      );
    });

    tearDown(() => repository.close());

    AmountEntryBloc build({SpendEntry? entry}) => AmountEntryBloc(
      recordSpend: RecordSpend(repository),
      updateSpend: UpdateSpend(repository),
      category: _groceries,
      entry: entry,
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'is invalid until the input parses to a non-zero amount',
      build: build,
      act: (bloc) => bloc.add(const AmountEntryChanged('abc')),
      verify: (bloc) {
        expect(bloc.state.amountScaled, isNull);
        expect(bloc.state.isValid, isFalse);
      },
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'treats zero as nothing to record',
      build: build,
      act: (bloc) => bloc.add(const AmountEntryChanged('0')),
      verify: (bloc) => expect(bloc.state.isValid, isFalse),
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'ignores submit while the input is invalid',
      build: build,
      act: (bloc) => bloc.add(const AmountEntrySubmitted()),
      expect: () => const <AmountEntryState>[],
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'adds the parsed amount to the category total',
      build: build,
      act: (bloc) => bloc
        ..add(const AmountEntryChanged('12.50'))
        ..add(const AmountEntrySubmitted()),
      verify: (bloc) async {
        expect(bloc.state.status, AmountEntryStatus.success);

        final spend = await repository
            .watchCategorySpend(CategoryKind.expense)
            .first;
        // 5.00 seeded, then 12.50 booked as spending, which is negative.
        expect(spend.single.totalScaled, 500 - 1250);
      },
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'stores the description typed against this one entry',
      build: build,
      act: (bloc) => bloc
        ..add(const AmountEntryChanged('12.50'))
        ..add(const AmountEntryNoteChanged('  Weekly shop  '))
        ..add(const AmountEntrySubmitted()),
      verify: (bloc) async {
        final history = await repository
            .watchCategoryHistory(_groceries.id)
            .first;
        // Trimmed on the way in: the surrounding spaces are typing, not text.
        expect(history.single.note, 'Weekly shop');
      },
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'leaves an entry with no description rather than an empty one',
      build: build,
      act: (bloc) => bloc
        ..add(const AmountEntryChanged('12.50'))
        ..add(const AmountEntryNoteChanged('   '))
        ..add(const AmountEntrySubmitted()),
      verify: (bloc) async {
        final history = await repository
            .watchCategoryHistory(_groceries.id)
            .first;
        expect(history.single.note, isNull);
      },
    );

    group('editing an entry', () {
      late SpendEntry entry;

      setUp(() async {
        await repository.recordSpend(
          categoryId: _groceries.id,
          amountScaled: 1250,
          note: 'Weekly shop',
        );
        entry =
            (await repository.watchCategoryHistory(_groceries.id).first).single;
      });

      blocTest<AmountEntryBloc, AmountEntryState>(
        'opens with the current amount already entered',
        build: () => build(entry: entry),
        verify: (bloc) {
          expect(bloc.state.isEditing, isTrue);
          expect(bloc.state.input, '12.50');
          expect(bloc.state.isValid, isTrue);
        },
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'opens with the description the entry already carries',
        build: () => build(entry: entry),
        verify: (bloc) => expect(bloc.state.note, 'Weekly shop'),
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'empties the description when the field is cleared',
        build: () => build(entry: entry),
        act: (bloc) => bloc
          ..add(const AmountEntryNoteChanged(''))
          ..add(const AmountEntrySubmitted()),
        verify: (bloc) async {
          final history = await repository
              .watchCategoryHistory(_groceries.id)
              .first;
          expect(history.single.note, isNull);
        },
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'keeps the description when only the amount is corrected',
        build: () => build(entry: entry),
        act: (bloc) => bloc
          ..add(const AmountEntryChanged('9.99'))
          ..add(const AmountEntrySubmitted()),
        verify: (bloc) async {
          final history = await repository
              .watchCategoryHistory(_groceries.id)
              .first;
          expect(history.single.note, 'Weekly shop');
        },
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'opens on the date the entry already carries',
        build: () => build(entry: entry),
        verify: (bloc) =>
            expect(bloc.state.occurredAt, entry.occurredAt.toUtc()),
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'moves the entry to the date that was picked',
        build: () => build(entry: entry),
        act: (bloc) => bloc
          ..add(AmountEntryDateChanged(DateTime(2026, 1, 9, 18, 45)))
          ..add(const AmountEntrySubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, AmountEntryStatus.success);

          final history = await repository
              .watchCategoryHistory(_groceries.id)
              .first;

          // Stored as UTC, and still the same instant that was picked.
          expect(history.single.occurredAt.isUtc, isTrue);
          expect(
            history.single.occurredAt,
            DateTime(2026, 1, 9, 18, 45).toUtc(),
          );
          // The amount is untouched by a move: 12.50 booked as spending.
          expect(history.single.amountScaled, -1250);
        },
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'leaves the date alone when only the amount is corrected',
        build: () => build(entry: entry),
        act: (bloc) => bloc
          ..add(const AmountEntryChanged('9.99'))
          ..add(const AmountEntrySubmitted()),
        verify: (bloc) async {
          final history = await repository
              .watchCategoryHistory(_groceries.id)
              .first;

          expect(history.single.amountScaled, -999);
          expect(history.single.occurredAt, entry.occurredAt);
        },
      );

      blocTest<AmountEntryBloc, AmountEntryState>(
        'changes the entry instead of adding another',
        build: () => build(entry: entry),
        act: (bloc) => bloc
          ..add(const AmountEntryChanged('9.99'))
          ..add(const AmountEntrySubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, AmountEntryStatus.success);

          final history = await repository
              .watchCategoryHistory(_groceries.id)
              .first;
          expect(history, hasLength(1));
          expect(history.single.amountScaled, -999);

          // The category total moves with it: 5.00 seeded, 12.50 booked and
          // then corrected to 9.99.
          final spend = await repository
              .watchCategorySpend(CategoryKind.expense)
              .first;
          expect(spend.single.totalScaled, 500 - 999);
        },
      );
    });

    blocTest<AmountEntryBloc, AmountEntryState>(
      'leaves a new entry undated so the clock reads at save time',
      build: build,
      verify: (bloc) => expect(bloc.state.occurredAt, isNull),
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'books a new entry on a backdated day',
      build: build,
      act: (bloc) => bloc
        ..add(const AmountEntryChanged('12.50'))
        ..add(AmountEntryDateChanged(DateTime(2026, 2, 3, 8, 15)))
        ..add(const AmountEntrySubmitted()),
      verify: (bloc) async {
        expect(bloc.state.status, AmountEntryStatus.success);

        final history = await repository
            .watchCategoryHistory(_groceries.id)
            .first;
        expect(history.single.occurredAt, DateTime(2026, 2, 3, 8, 15).toUtc());
      },
    );

    blocTest<AmountEntryBloc, AmountEntryState>(
      'keeps the amount so a failed save can be retried',
      build: () {
        repository.writeError = Exception('offline');
        return build();
      },
      act: (bloc) => bloc
        ..add(const AmountEntryChanged('12.50'))
        ..add(const AmountEntrySubmitted()),
      verify: (bloc) {
        expect(bloc.state.status, AmountEntryStatus.editing);
        expect(bloc.state.input, '12.50');
        expect(bloc.state.isValid, isTrue);
      },
    );
  });
}
