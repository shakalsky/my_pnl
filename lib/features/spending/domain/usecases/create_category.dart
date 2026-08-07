import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Creates a category, rejecting anything the domain considers invalid.
class CreateCategory {
  const CreateCategory(this._repository);

  final CategoryRepository _repository;

  Future<Category> call(NewCategory category) {
    final name = category.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(category.name, 'name', 'must not be blank');
    }

    // Every field is listed, because rebuilding the object just to trim the
    // name is how a new field silently stops being saved — kind was already
    // lost this way once, and income arrived as spending.
    return _repository.createCategory(
      NewCategory(
        name: name,
        colorArgb: category.colorArgb,
        iconKey: category.iconKey,
        kind: category.kind,
        recurring: category.recurring,
      ),
    );
  }
}
