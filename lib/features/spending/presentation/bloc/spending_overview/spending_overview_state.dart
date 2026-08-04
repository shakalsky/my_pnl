part of 'spending_overview_bloc.dart';

enum SpendingOverviewStatus { initial, loading, success, failure }

final class SpendingOverviewState extends Equatable {
  const SpendingOverviewState({
    required this.month,
    this.status = SpendingOverviewStatus.initial,
    this.categories = const [],
    this.netTotalScaled = 0,
    this.baselines = const {},
    this.settings = OverrunSettings.defaults,
  });

  final SpendingOverviewStatus status;
  final List<CategorySpend> categories;

  /// What each category usually costs in a month, keyed by category id.
  ///
  /// Empty until the baselines arrive, and empty for good on a page that does
  /// not ask for them — [overrunFor] then reports nothing unusual, which is
  /// what a page with no history to compare against should say.
  final Map<String, SpendBaseline> baselines;

  /// When to warn that a month has run past the usual — and whether to at all.
  ///
  /// The shipped defaults until the reader's own settings arrive, so the first
  /// frame flags what a later one would rather than changing its mind.
  final OverrunSettings settings;

  /// Which month every figure here is for.
  ///
  /// Required rather than defaulted: a default would have to be "now", and a
  /// state that quietly reads the clock is one whose figures cannot be pinned
  /// down in a test.
  final CalendarMonth month;

  /// Income minus spending across every category, scaled by `amountScale`.
  ///
  /// Not derived from [categories]: this page shows one kind, and the net has
  /// to count both.
  final int netTotalScaled;

  /// Everything booked across the categories on this page.
  ///
  /// Signed, so a spending page's total is negative.
  int get totalScaled =>
      categories.fold(0, (sum, entry) => sum + entry.totalScaled);

  /// How far past its usual month [spend] has gone.
  ///
  /// Answered here rather than in the widgets because all three parts of the
  /// comparison live on this state — the figure, the months before it and the
  /// thresholds — and a figure compared against the wrong month's baseline
  /// would be wrong in a way nothing on screen could show.
  SpendOverrun overrunFor(CategorySpend spend) => settings.overrunFor(
    spend.totalScaled,
    against: baselines[spend.category.id],
  );

  SpendingOverviewState copyWith({
    SpendingOverviewStatus? status,
    List<CategorySpend>? categories,
    CalendarMonth? month,
    int? netTotalScaled,
    Map<String, SpendBaseline>? baselines,
    OverrunSettings? settings,
  }) {
    return SpendingOverviewState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      month: month ?? this.month,
      netTotalScaled: netTotalScaled ?? this.netTotalScaled,
      baselines: baselines ?? this.baselines,
      settings: settings ?? this.settings,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    month,
    netTotalScaled,
    baselines,
    settings,
  ];
}
