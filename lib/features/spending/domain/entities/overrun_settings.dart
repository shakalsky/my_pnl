import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';

/// When to warn that a month has run past what a category usually costs.
///
/// A device preference rather than user data: it says nothing about what was
/// spent, only how strict the reader wants the warnings to be. Held as whole
/// percentages of the usual month — 125 meaning "a quarter over" — so the same
/// figure means the same thing in any currency and at any scale.
class OverrunSettings extends Equatable {
  const OverrunSettings({
    this.enabled = true,
    this.mildPercent = 125,
    this.highPercent = 150,
    this.severePercent = 200,
  });

  /// What the app warns at until someone changes it.
  ///
  /// On by default: the flags are the point of recording the months at all, and
  /// a feature nobody knows is there is one nobody turns on.
  static const defaults = OverrunSettings();

  /// Tightest a threshold may be set to.
  ///
  /// Not 100: a month landing on its average to the cent is ordinary, and a
  /// threshold there would flag half of every grid every month.
  static const minPercent = 105;

  /// Loosest a threshold may be set to.
  ///
  /// Three times the usual month. Past that the warning has stopped being one —
  /// a figure that far out is obvious from the number itself.
  static const maxPercent = 300;

  /// How far apart the sliders step, and the smallest gap between two levels.
  static const percentStep = 5;

  /// Whether to draw the warning borders at all.
  final bool enabled;

  /// Percentage of the usual month at which each level starts.
  final int mildPercent;
  final int highPercent;
  final int severePercent;

  /// Which level [spentScaled] falls on against the months before it.
  ///
  /// Null [against] means there is no usual month on record, which is nothing
  /// to warn about rather than a warning of nothing — a category used for the
  /// first time is not overspending.
  ///
  /// Not pro-rated for how far through the month it is. On the third of the
  /// month a third of the usual has been spent, which is not an overrun and is
  /// not reported as one; the flag appears when the money has actually gone.
  SpendOverrun overrunFor(int spentScaled, {SpendBaseline? against}) {
    final percent = against?.percentOf(spentScaled);

    return percent == null ? SpendOverrun.none : levelFor(percent);
  }

  /// Which level a figure at [percent] of the usual month falls on.
  ///
  /// Read from the severest down, so a set of thresholds saved out of order can
  /// only make a level unreachable — never report the wrong one.
  SpendOverrun levelFor(int percent) {
    if (!enabled) return SpendOverrun.none;
    if (percent >= severePercent) return SpendOverrun.severe;
    if (percent >= highPercent) return SpendOverrun.high;
    if (percent >= mildPercent) return SpendOverrun.mild;
    return SpendOverrun.none;
  }

  /// What [level] is currently set to.
  int percentFor(SpendOverrun level) => switch (level) {
    SpendOverrun.none => minPercent,
    SpendOverrun.mild => mildPercent,
    SpendOverrun.high => highPercent,
    SpendOverrun.severe => severePercent,
  };

  /// The same settings with [level] moved to [percent].
  ///
  /// Normalized on the way out, so dragging one level past another pushes the
  /// looser ones along rather than leaving a set where the middle colour can
  /// never appear.
  OverrunSettings withLevel(SpendOverrun level, int percent) => switch (level) {
    SpendOverrun.none => this,
    SpendOverrun.mild => copyWith(mildPercent: percent),
    SpendOverrun.high => copyWith(highPercent: percent),
    SpendOverrun.severe => copyWith(severePercent: percent),
  }.normalized;

  /// The same settings with every figure in range and in order.
  ///
  /// Applied when reading from storage as well as when editing: the values come
  /// from a key-value store that an older or newer build may have written, and
  /// nothing downstream should have to defend itself against 0% or 90000%.
  OverrunSettings get normalized {
    final mild = mildPercent.clamp(minPercent, maxPercent);
    // Each level starts no lower than the one below it. Equal is allowed and
    // simply means the level in between never comes up.
    final high = highPercent.clamp(mild, maxPercent);
    final severe = severePercent.clamp(high, maxPercent);

    return OverrunSettings(
      enabled: enabled,
      mildPercent: mild,
      highPercent: high,
      severePercent: severe,
    );
  }

  OverrunSettings copyWith({
    bool? enabled,
    int? mildPercent,
    int? highPercent,
    int? severePercent,
  }) {
    return OverrunSettings(
      enabled: enabled ?? this.enabled,
      mildPercent: mildPercent ?? this.mildPercent,
      highPercent: highPercent ?? this.highPercent,
      severePercent: severePercent ?? this.severePercent,
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    mildPercent,
    highPercent,
    severePercent,
  ];
}
