import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/usecases/save_debt.dart';
import 'package:my_pnl/features/debts/presentation/bloc/debt_form/debt_form_bloc.dart';

import '../../../../../helpers/helpers.dart';

final _lentToAlex = Debt(
  id: 'debt-1',
  counterparty: 'Alex',
  direction: DebtDirection.owedToMe,
  amountScaled: 2500,
  note: 'Concert ticket',
  dueAt: DateTime.utc(2026, 9),
);

void main() {
  group('DebtFormBloc', () {
    late FakeDebtRepository repository;

    setUp(() => repository = FakeDebtRepository());
    tearDown(() => repository.close());

    DebtFormBloc build({
      Debt? initial,
      DebtDirection direction = DebtDirection.owedToMe,
    }) => DebtFormBloc(
      saveDebt: SaveDebt(repository),
      direction: direction,
      initial: initial,
    );

    group('adding', () {
      blocTest<DebtFormBloc, DebtFormState>(
        'needs both a name and an amount above zero',
        build: build,
        act: (bloc) => bloc.add(const DebtCounterpartyChanged('Alex')),
        verify: (bloc) => expect(bloc.state.isValid, isFalse),
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'rejects a zero amount',
        build: build,
        act: (bloc) => bloc
          ..add(const DebtCounterpartyChanged('Alex'))
          ..add(const DebtAmountChanged('0')),
        verify: (bloc) => expect(bloc.state.isValid, isFalse),
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'parses the amount to two decimal places',
        build: build,
        act: (bloc) => bloc.add(const DebtAmountChanged('25,50')),
        verify: (bloc) => expect(bloc.state.amountScaled, 2550),
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'opens on the direction it was asked for',
        build: () => build(direction: DebtDirection.owedByMe),
        verify: (bloc) => expect(bloc.state.isOwedToMe, isFalse),
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'saves what someone owes the user',
        build: build,
        act: (bloc) => bloc
          ..add(const DebtCounterpartyChanged('  Alex  '))
          ..add(const DebtAmountChanged('25'))
          ..add(const DebtNoteChanged('Concert ticket'))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, DebtFormStatus.success);

          final saved = (await repository.watchDebts().first).single;
          expect(saved.counterparty, 'Alex', reason: 'trimmed on save');
          expect(saved.direction, DebtDirection.owedToMe);
          expect(saved.amountScaled, 2500);
          expect(saved.note, 'Concert ticket');
          expect(saved.isSettled, isFalse);
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'saves what the user owes',
        build: build,
        act: (bloc) => bloc
          ..add(const DebtDirectionChanged(DebtDirection.owedByMe))
          ..add(const DebtCounterpartyChanged('Landlord'))
          ..add(const DebtAmountChanged('900'))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          final saved = (await repository.watchDebts().first).single;
          expect(saved.direction, DebtDirection.owedByMe);
          // A magnitude either way: the direction carries the sign.
          expect(saved.amountScaled, 90000);
          expect(saved.signedAmountScaled, -90000);
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'stores a blank note as none',
        build: build,
        act: (bloc) => bloc
          ..add(const DebtCounterpartyChanged('Alex'))
          ..add(const DebtAmountChanged('25'))
          ..add(const DebtNoteChanged('   '))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          final saved = (await repository.watchDebts().first).single;
          expect(saved.note, isNull);
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'keeps a cleared due date cleared',
        build: build,
        act: (bloc) => bloc
          ..add(const DebtCounterpartyChanged('Alex'))
          ..add(const DebtAmountChanged('25'))
          ..add(DebtDueDateChanged(DateTime.utc(2026, 9)))
          ..add(const DebtDueDateChanged(null))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          final saved = (await repository.watchDebts().first).single;
          expect(saved.dueAt, isNull);
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'says who is missing rather than saving a nameless debt',
        build: build,
        act: (bloc) => bloc
          ..add(const DebtCounterpartyChanged('   '))
          ..add(const DebtAmountChanged('25'))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, DebtFormStatus.editing);
          expect(await repository.watchDebts().first, isEmpty);
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'reports a failed write and keeps the input',
        build: () {
          repository.writeError = Exception('offline');
          return build();
        },
        act: (bloc) => bloc
          ..add(const DebtCounterpartyChanged('Alex'))
          ..add(const DebtAmountChanged('25'))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) {
          expect(bloc.state.errorMessage, 'Could not save that debt');
          expect(bloc.state.status, DebtFormStatus.editing);
          expect(bloc.state.counterparty, 'Alex', reason: 'input survives');
        },
      );
    });

    group('editing', () {
      setUp(() => repository = FakeDebtRepository(initial: [_lentToAlex]));

      blocTest<DebtFormBloc, DebtFormState>(
        'opens with the current values',
        build: () => build(initial: _lentToAlex),
        verify: (bloc) {
          expect(bloc.state.isEditing, isTrue);
          expect(bloc.state.counterparty, 'Alex');
          expect(bloc.state.amount, '25.00');
          expect(bloc.state.note, 'Concert ticket');
          expect(bloc.state.dueAt, DateTime.utc(2026, 9));
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'changes the existing debt rather than adding one',
        build: () => build(initial: _lentToAlex),
        act: (bloc) => bloc
          ..add(const DebtAmountChanged('30'))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          final debts = await repository.watchDebts().first;
          expect(debts, hasLength(1));
          expect(debts.single.id, _lentToAlex.id);
          expect(debts.single.amountScaled, 3000);
        },
      );

      blocTest<DebtFormBloc, DebtFormState>(
        'leaves a settled debt settled',
        build: () {
          final settled = _lentToAlex.copyWith(settledAt: DateTime.utc(2026));
          repository = FakeDebtRepository(initial: [settled]);
          return build(initial: settled);
        },
        act: (bloc) => bloc
          ..add(const DebtAmountChanged('30'))
          ..add(const DebtFormSubmitted()),
        verify: (bloc) async {
          final debts = await repository.watchDebts().first;
          expect(debts.single.settledAt, DateTime.utc(2026));
        },
      );
    });
  });
}
