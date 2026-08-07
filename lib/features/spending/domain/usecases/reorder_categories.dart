import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Stores the order the grid shows its categories in.
class ReorderCategories {
  const ReorderCategories(this._repository);

  final CategoryRepository _repository;

  /// [orderedIds] is the whole list, first to last.
  ///
  /// Duplicates are rejected rather than written: two rows cannot hold the same
  /// place, and an id repeated in the list is a caller that has lost track of
  /// what it moved — writing it would silently drop whichever category the
  /// duplicate displaced.
  Future<void> call(List<String> orderedIds) {
    if (orderedIds.toSet().length != orderedIds.length) {
      throw ArgumentError.value(
        orderedIds,
        'orderedIds',
        'must not name a category twice',
      );
    }

    return _repository.reorderCategories(orderedIds);
  }
}
