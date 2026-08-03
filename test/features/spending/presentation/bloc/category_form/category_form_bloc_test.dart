import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/create_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_category.dart';
import 'package:my_pnl/features/spending/presentation/bloc/category_form/category_form_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _existing = Category(
  id: 'category-1',
  name: 'Groceries',
  colorArgb: 0xFF3B7A57,
  iconKey: 'groceries',
);

void main() {
  group('CategoryFormBloc', () {
    late FakeCategoryRepository repository;

    setUp(() => repository = FakeCategoryRepository());
    tearDown(() => repository.close());

    CategoryFormBloc build({Category? initial}) => CategoryFormBloc(
      createCategory: CreateCategory(repository),
      updateCategory: UpdateCategory(repository),
      deleteCategory: DeleteCategory(repository),
      defaultColorArgb: 0xFF3B7A57,
      defaultIconKey: 'groceries',
      initial: initial,
    );

    group('creating', () {
      blocTest<CategoryFormBloc, CategoryFormState>(
        'starts empty and invalid',
        build: build,
        verify: (bloc) {
          expect(bloc.state.isEditing, isFalse);
          expect(bloc.state.name, isEmpty);
          expect(bloc.state.isValid, isFalse);
        },
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'stays invalid for a blank name',
        build: build,
        act: (bloc) => bloc.add(const CategoryFormNameChanged('  ')),
        verify: (bloc) => expect(bloc.state.isValid, isFalse),
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'ignores submit while the name is blank',
        build: build,
        act: (bloc) => bloc.add(const CategoryFormSubmitted()),
        expect: () => const <CategoryFormState>[],
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'has nothing to delete',
        build: build,
        act: (bloc) => bloc.add(const CategoryFormDeleted(CategoryDeletion.keepTransactions)),
        expect: () => const <CategoryFormState>[],
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'inserts with the chosen color and icon',
        build: build,
        act: (bloc) => bloc
          ..add(const CategoryFormNameChanged('Utilities'))
          ..add(const CategoryFormIconSelected('utilities'))
          ..add(const CategoryFormColorSelected(0xFFB08A2E))
          ..add(const CategoryFormSubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, CategoryFormStatus.success);

          final spend = await repository
              .watchCategorySpend(CategoryKind.expense)
              .first;
          final created = spend.single.category;
          expect(created.name, 'Utilities');
          expect(created.iconKey, 'utilities');
          expect(created.colorArgb, 0xFFB08A2E);
        },
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'names the clash when the category name is taken',
        build: () {
          repository = FakeCategoryRepository(
            initial: const [
              CategorySpend(category: _existing, totalScaled: 0),
            ],
          );
          return build();
        },
        act: (bloc) => bloc
          ..add(const CategoryFormNameChanged('groceries'))
          ..add(const CategoryFormSubmitted()),
        verify: (bloc) {
          expect(
            bloc.state.errorMessage,
            'You already have a category called "groceries"',
          );
          expect(bloc.state.status, CategoryFormStatus.editing);
          expect(bloc.state.name, 'groceries', reason: 'input survives');
        },
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'clears the complaint once the name is edited',
        build: () {
          repository = FakeCategoryRepository(
            initial: const [
              CategorySpend(category: _existing, totalScaled: 0),
            ],
          );
          return build();
        },
        act: (bloc) async {
          bloc
            ..add(const CategoryFormNameChanged('Groceries'))
            ..add(const CategoryFormSubmitted());
          await pumpEventQueue();
          bloc.add(const CategoryFormNameChanged('Groceries 2'));
        },
        verify: (bloc) => expect(bloc.state.errorMessage, isNull),
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'returns to editing so a failed save can be retried',
        build: () {
          repository.writeError = Exception('offline');
          return build();
        },
        act: (bloc) => bloc
          ..add(const CategoryFormNameChanged('Utilities'))
          ..add(const CategoryFormSubmitted()),
        skip: 2,
        expect: () => const <CategoryFormState>[
          CategoryFormState(
            name: 'Utilities',
            colorArgb: 0xFF3B7A57,
            iconKey: 'groceries',
            status: CategoryFormStatus.failure,
          ),
          CategoryFormState(
            name: 'Utilities',
            colorArgb: 0xFF3B7A57,
            iconKey: 'groceries',
          ),
        ],
      );
    });

    group('editing', () {
      setUp(() async {
        repository = FakeCategoryRepository(
          initial: const [
            CategorySpend(category: _existing, totalScaled: 4235),
          ],
        );
      });

      blocTest<CategoryFormBloc, CategoryFormState>(
        'starts seeded from the category',
        build: () => build(initial: _existing),
        verify: (bloc) {
          expect(bloc.state.isEditing, isTrue);
          expect(bloc.state.categoryId, _existing.id);
          expect(bloc.state.name, 'Groceries');
          expect(bloc.state.iconKey, 'groceries');
          expect(bloc.state.isValid, isTrue);
        },
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'deletes the category',
        build: () => build(initial: _existing),
        act: (bloc) => bloc.add(const CategoryFormDeleted(CategoryDeletion.keepTransactions)),
        verify: (bloc) async {
          expect(bloc.state.status, CategoryFormStatus.success);
          expect(
            await repository.watchCategorySpend(CategoryKind.expense).first,
            isEmpty,
          );
        },
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'stays open so a failed delete can be retried',
        build: () {
          repository.writeError = Exception('offline');
          return build(initial: _existing);
        },
        act: (bloc) => bloc.add(const CategoryFormDeleted(CategoryDeletion.keepTransactions)),
        verify: (bloc) async {
          expect(bloc.state.status, CategoryFormStatus.editing);
          expect(
            await repository.watchCategorySpend(CategoryKind.expense).first,
            hasLength(1),
          );
        },
      );

      blocTest<CategoryFormBloc, CategoryFormState>(
        'updates the existing row rather than inserting a new one',
        build: () => build(initial: _existing),
        act: (bloc) => bloc
          ..add(const CategoryFormNameChanged('Food'))
          ..add(const CategoryFormIconSelected('dining'))
          ..add(const CategoryFormSubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, CategoryFormStatus.success);

          final spend = await repository
              .watchCategorySpend(CategoryKind.expense)
              .first;
          expect(spend, hasLength(1));
          expect(spend.single.category.id, _existing.id);
          expect(spend.single.category.name, 'Food');
          expect(spend.single.category.iconKey, 'dining');
          expect(spend.single.totalScaled, 4235, reason: 'total untouched');
        },
      );
    });
  });
}
