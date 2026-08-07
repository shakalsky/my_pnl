import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Saves edits to a category, applying the same name rule as creation.
class UpdateCategory {
  const UpdateCategory(this._repository);

  final CategoryRepository _repository;

  Future<Category> call(Category category) {
    final name = category.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(category.name, 'name', 'must not be blank');
    }

    // Every field is listed, for the same reason as in CreateCategory: an
    // omission here silently drops an edit rather than failing.
    return _repository.updateCategory(
      Category(
        id: category.id,
        name: name,
        colorArgb: category.colorArgb,
        iconKey: category.iconKey,
        kind: category.kind,
        recurring: category.recurring,
      ),
    );
  }
}
