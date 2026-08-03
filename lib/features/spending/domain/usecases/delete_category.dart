import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Removes a category.
///
/// The caller decides what happens to its transactions; there is no safe
/// default, so the mode is required rather than assumed.
class DeleteCategory {
  const DeleteCategory(this._repository);

  final CategoryRepository _repository;

  Future<void> call(String id, CategoryDeletion mode) =>
      _repository.deleteCategory(id, mode);
}
