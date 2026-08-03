import 'package:equatable/equatable.dart';

/// A `major.minor.patch+build` version, comparable.
///
/// Deliberately not a plain string: `'1.10.0'` sorts before `'1.9.0'` as text,
/// which would let a stale client through the update gate. The numbers are
/// parsed once and compared as numbers.
class AppVersion extends Equatable implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  /// Reads `1.2.3` or `1.2.3+45`, or null when the text is not a version.
  ///
  /// Missing parts count as zero, so `'2'` is 2.0.0 — a store or a config row
  /// abbreviating a version should not stop the check working. Anything after
  /// a `-` is dropped: pre-release labels order by rules this app has no need
  /// for, and treating `1.2.0-beta` as 1.2.0 is the safe reading for a gate.
  static AppVersion? tryParse(String value) {
    final text = value.trim().split('-').first;
    if (text.isEmpty) return null;

    final parts = text.split('+');
    final numbers = parts.first.split('.');
    if (numbers.isEmpty) return null;

    final major = int.tryParse(numbers.first);
    if (major == null) return null;

    // A malformed later part is a malformed version, not a zero: silently
    // reading `1.x.0` as 1.0.0 would compare something nobody wrote.
    int? at(int index) {
      if (index >= numbers.length) return 0;
      return int.tryParse(numbers[index]);
    }

    final minor = at(1);
    final patch = at(2);
    final build = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (minor == null || patch == null || build == null) return null;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: build,
    );
  }

  final int major;
  final int minor;
  final int patch;

  /// The number after the `+`. Compared only when the three above tie, which is
  /// what makes a rebuild of the same version newer than the one before it.
  final int build;

  bool isOlderThan(AppVersion other) => compareTo(other) < 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return build.compareTo(other.build);
  }

  /// `1.2.3`, without the build — this is what a user recognises from a store
  /// listing, so it is what the update screen shows.
  String get label => '$major.$minor.$patch';

  @override
  String toString() => build == 0 ? label : '$label+$build';

  @override
  List<Object?> get props => [major, minor, patch, build];
}
