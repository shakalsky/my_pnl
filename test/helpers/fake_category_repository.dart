import 'dart:async';

import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// In-memory stand-in for the repositories.
///
/// Implements both ports so a test can hand the same instance to each and
/// still see a recorded amount show up in the watched totals — the behaviour
/// the real drift query gives you for free.
///
/// Widget and bloc tests depend on the domain interfaces, so none of them need
/// a database. That is the point of the layering.
class FakeCategoryRepository
    implements CategoryRepository, TransactionRepository {
  FakeCategoryRepository({
    List<CategorySpend> initial = const [],
    Map<String, SpendBaseline> baselines = const {},
  }) : _spend = List.of(initial),
       baselines = Map.of(baselines);

  final List<CategorySpend> _spend;

  /// What each category usually costs in a month, keyed by category id.
  ///
  /// Seeded rather than derived from the recorded entries: averaging months is
  /// the drift query's work and is covered against a real database in the data
  /// source tests. What a caller can check here is what the pages do with a
  /// baseline once they have one.
  final Map<String, SpendBaseline> baselines;
  final _controller = StreamController<List<CategorySpend>>.broadcast();
  final _history = <String, List<SpendEntry>>{};
  final _historyController = StreamController<String>.broadcast();

  /// Set to have any write fail.
  Exception? writeError;

  /// The month each watch was opened for, oldest first — null meaning all time.
  ///
  /// The totals themselves are not narrowed: a seeded [CategorySpend] is a
  /// figure with no date behind it, so there is nothing here to filter. Month
  /// scoping is the drift query's work and is covered against a real database
  /// in the data source tests; what a caller can check here is that it asked
  /// for the month it meant to.
  final requestedMonths = <CalendarMonth?>[];

  @override
  Stream<List<CategorySpend>> watchCategorySpend(
    CategoryKind kind, {
    CalendarMonth? month,
  }) async* {
    requestedMonths.add(month);

    List<CategorySpend> ofKind(List<CategorySpend> all) => List.unmodifiable(
      all.where((entry) => entry.category.kind == kind),
    );

    yield ofKind(_spend);
    yield* _controller.stream.map(ofKind);
  }

  /// The month each baseline watch was opened for, oldest first.
  final requestedBaselineMonths = <CalendarMonth>[];

  /// The lookback each baseline watch asked for, oldest first.
  final requestedLookbacks = <int>[];

  @override
  Stream<Map<String, SpendBaseline>> watchSpendBaselines(
    CategoryKind kind, {
    required CalendarMonth month,
    int lookbackMonths = SpendBaseline.lookbackMonths,
  }) async* {
    requestedBaselineMonths.add(month);
    requestedLookbacks.add(lookbackMonths);

    Map<String, SpendBaseline> ofKind() {
      final scoped = <String, SpendBaseline>{};

      for (final entry in _spend) {
        if (entry.category.kind != kind) continue;
        final baseline = baselines[entry.category.id];
        if (baseline != null) scoped[entry.category.id] = baseline;
      }

      return Map.unmodifiable(scoped);
    }

    yield ofKind();
    // A recorded amount does not change a seeded baseline, but a category
    // added or removed changes which ones are in scope.
    yield* _controller.stream.map((_) => ofKind());
  }

  /// Recurrence generation belongs to the drift query; the fake exists to let
  /// widget and bloc tests run without a database, and none of them exercise
  /// it. The data source is covered directly.
  @override
  Future<int> generateDueRecurringIncome({DateTime? now}) async => 0;

  @override
  Future<Category> createCategory(NewCategory category) async {
    if (writeError case final error?) throw error;
    _requireFreeName(category.name);

    // Every field carries over. Dropping kind here made a new income category
    // arrive as spending, and the income page then filtered out the row it had
    // just created — a bug in the double that looked like a bug in the page.
    final created = Category(
      id: newId(),
      name: category.name,
      colorArgb: category.colorArgb,
      iconKey: category.iconKey,
      kind: category.kind,
      recurring: category.recurring,
    );
    _spend.add(CategorySpend(category: created, totalScaled: 0));
    _emit();
    return created;
  }

  @override
  Future<Category> updateCategory(Category category) async {
    if (writeError case final error?) throw error;
    _requireFreeName(category.name, exceptId: category.id);

    _spend[_indexOf(category.id)] = CategorySpend(
      category: category,
      totalScaled: _spend[_indexOf(category.id)].totalScaled,
    );
    _emit();
    return category;
  }

  /// The arrangement each reorder was asked to save, oldest first.
  final savedOrders = <List<String>>[];

  @override
  Future<void> reorderCategories(List<String> orderedIds) async {
    if (writeError case final error?) throw error;

    savedOrders.add(List.unmodifiable(orderedIds));

    // Applied to the list the watch stream reads, the way the real ordered
    // query does: a page that only redrew from its own optimistic state would
    // look right here whether the write landed or not. Ids the fake does not
    // hold are ignored rather than fatal — the same race the data source skips.
    final byId = {for (final spend in _spend) spend.category.id: spend};
    final arranged = [for (final id in orderedIds) ?byId[id]];

    _spend
      ..removeWhere(arranged.contains)
      ..insertAll(0, arranged);
    _emit();
  }

  @override
  Future<void> deleteCategory(String id, CategoryDeletion mode) async {
    if (writeError case final error?) throw error;

    final removed = _spend.removeAt(_indexOf(id));
    // Either way the entries leave this category's history. Keeping them
    // detaches rather than deletes, which the net total reflects — but the
    // fake has no uncategorised bucket to hold them in, so it records only
    // what the pages can see.
    _history.remove(id);
    lastDeletion = mode;
    keptOnDelete = mode == CategoryDeletion.keepTransactions
        ? removed.totalScaled
        : 0;
    _emit();
  }

  /// How the last delete was asked to treat its transactions.
  CategoryDeletion? lastDeletion;

  /// The amount left in the ledger by the last delete.
  int keptOnDelete = 0;

  @override
  Stream<List<LedgerEntry>> watchAllEntries() async* {
    List<LedgerEntry> all() {
      final entries =
          [
              for (final spend in _spend)
                for (final entry
                    in _history[spend.category.id] ?? const <SpendEntry>[])
                  LedgerEntry(entry: entry, category: spend.category),
            ]
            // Newest first across every category, the way the drift query orders
            // them — which is what lets the sheet group a day's entries together
            // rather than meet the same day twice.
            ..sort((a, b) => b.entry.occurredAt.compareTo(a.entry.occurredAt));

      return List.unmodifiable(entries);
    }

    yield all();
    // Either controller can change the list, so both feed it.
    yield* _controller.stream.map((_) => all());
  }

  @override
  Stream<int> watchNetTotal({CalendarMonth? month}) async* {
    int net(List<CategorySpend> all) =>
        all.fold(0, (sum, entry) => sum + entry.totalScaled);

    yield net(_spend);
    yield* _controller.stream.map(net);
  }

  /// Groups the recorded entries by UTC month, newest first, the way the drift
  /// query does.
  @override
  Stream<List<MonthlyPnl>> watchMonthlyPnl() async* {
    List<MonthlyPnl> months() {
      final totals = <(int, int), int>{};

      for (final entries in _history.values) {
        for (final entry in entries) {
          final at = entry.occurredAt.toUtc();
          final key = (at.year, at.month);
          totals[key] = (totals[key] ?? 0) + entry.amountScaled;
        }
      }

      final sorted = totals.keys.toList()
        ..sort(
          (a, b) => a.$1 == b.$1 ? b.$2.compareTo(a.$2) : b.$1.compareTo(a.$1),
        );

      return List.unmodifiable([
        for (final key in sorted)
          MonthlyPnl(year: key.$1, month: key.$2, netScaled: totals[key]!),
      ]);
    }

    yield months();
    // Either controller can change the entries, so both feed it.
    yield* _controller.stream.map((_) => months());
  }

  /// The real repair pass reads and rewrites rows; nothing the fake backs
  /// needs it, and the data source covers it directly.
  @override
  Future<int> normalizeAmountSigns() async => 0;

  @override
  Future<void> recordSpend({
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) async {
    if (writeError case final error?) throw error;

    final index = _indexOf(categoryId);
    // Mirrors the data source: income positive, spending negative.
    final signed = _spend[index].category.isIncome
        ? amountScaled.abs()
        : -amountScaled.abs();

    _spend[index] = CategorySpend(
      category: _spend[index].category,
      totalScaled: _spend[index].totalScaled + signed,
    );
    (_history[categoryId] ??= []).insert(
      0,
      SpendEntry(
        id: newId(),
        amountScaled: signed,
        occurredAt: (occurredAt ?? DateTime(2026, 3, 14, 9, 30)).toUtc(),
        note: note,
      ),
    );
    _emit();
    _historyController.add(categoryId);
  }

  /// Books an entry as though a partner had recorded it in a shared ledger.
  ///
  /// The real data source works this out from `owner_id` and the membership
  /// list; there is nothing to join here, so a test says so directly. What
  /// matters below is the same either way: the entry counts towards the totals,
  /// carries a name, and refuses to be written.
  void recordPartnerSpend({
    required String categoryId,
    required int amountScaled,
    String authorName = 'kate',
    DateTime? occurredAt,
    String? note,
  }) {
    final index = _indexOf(categoryId);
    final signed = _spend[index].category.isIncome
        ? amountScaled.abs()
        : -amountScaled.abs();

    _spend[index] = CategorySpend(
      category: _spend[index].category,
      totalScaled: _spend[index].totalScaled + signed,
    );
    (_history[categoryId] ??= []).insert(
      0,
      SpendEntry(
        id: newId(),
        amountScaled: signed,
        occurredAt: (occurredAt ?? DateTime(2026, 3, 14, 9, 30)).toUtc(),
        note: note,
        isOwn: false,
        authorName: authorName,
      ),
    );
    _emit();
    _historyController.add(categoryId);
  }

  @override
  Future<void> updateSpend({
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) async {
    if (writeError case final error?) throw error;
    _requireOwn(id);

    final categoryId = _categoryIdForEntry(id);
    final entries = _history[categoryId]!;
    final index = entries.indexWhere((e) => e.id == id);
    final previous = entries[index];
    final signed = _spend[_indexOf(categoryId)].category.isIncome
        ? amountScaled.abs()
        : -amountScaled.abs();

    entries[index] = SpendEntry(
      id: previous.id,
      amountScaled: signed,
      occurredAt: occurredAt ?? previous.occurredAt,
      // Replaced rather than merged, the way the data source writes it: a
      // cleared field has to be able to empty the note.
      note: note,
    );
    _applyTotal(categoryId, signed - previous.amountScaled);
    _historyController.add(categoryId);
  }

  @override
  Future<void> deleteSpend(String id) async {
    if (writeError case final error?) throw error;
    _requireOwn(id);

    final categoryId = _categoryIdForEntry(id);
    final entries = _history[categoryId]!;
    final removed = entries.removeAt(entries.indexWhere((e) => e.id == id));

    _applyTotal(categoryId, -removed.amountScaled);
    _historyController.add(categoryId);
  }

  /// Refuses an entry the reader did not record, as the data source does.
  ///
  /// A shared ledger is read together and written separately, and this is what
  /// makes a UI that offered the write fail a test rather than a partner's
  /// history.
  void _requireOwn(String entryId) {
    for (final entries in _history.values) {
      for (final entry in entries) {
        if (entry.id != entryId) continue;
        if (entry.isOwn) return;
        throw StateError('Entry $entryId belongs to somebody else');
      }
    }
  }

  String _categoryIdForEntry(String entryId) {
    for (final entry in _history.entries) {
      if (entry.value.any((e) => e.id == entryId)) return entry.key;
    }
    throw StateError('No entry $entryId');
  }

  void _applyTotal(String categoryId, int delta) {
    final index = _indexOf(categoryId);
    _spend[index] = CategorySpend(
      category: _spend[index].category,
      totalScaled: _spend[index].totalScaled + delta,
    );
    _emit();
  }

  @override
  Stream<List<SpendEntry>> watchCategoryHistory(String categoryId) async* {
    yield List.unmodifiable(_history[categoryId] ?? const []);
    yield* _historyController.stream
        .where((id) => id == categoryId)
        .map((_) => List<SpendEntry>.unmodifiable(_history[categoryId]!));
  }

  void _requireFreeName(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    final clash = _spend.where(
      (e) =>
          e.category.name.trim().toLowerCase() == normalized &&
          e.category.id != exceptId,
    );

    if (clash.isNotEmpty) {
      throw CategoryFailure('You already have a category called "$name"');
    }
  }

  int _indexOf(String categoryId) {
    final index = _spend.indexWhere((e) => e.category.id == categoryId);
    if (index == -1) throw StateError('No category $categoryId');
    return index;
  }

  void _emit() => _controller.add(List.unmodifiable(_spend));

  Future<void> close() async {
    await _controller.close();
    await _historyController.close();
  }
}
