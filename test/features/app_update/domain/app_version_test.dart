import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('reads a plain version', () {
      expect(
        AppVersion.tryParse('1.2.3'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
    });

    test('reads a build number', () {
      expect(
        AppVersion.tryParse('1.2.3+45'),
        const AppVersion(major: 1, minor: 2, patch: 3, build: 45),
      );
    });

    test('fills missing parts with zero', () {
      expect(
        AppVersion.tryParse('2'),
        const AppVersion(major: 2, minor: 0, patch: 0),
      );
      expect(
        AppVersion.tryParse('2.1'),
        const AppVersion(major: 2, minor: 1, patch: 0),
      );
    });

    test('drops a pre-release label', () {
      expect(
        AppVersion.tryParse('1.2.0-beta.1'),
        const AppVersion(major: 1, minor: 2, patch: 0),
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(
        AppVersion.tryParse('  1.0.0  '),
        const AppVersion(major: 1, minor: 0, patch: 0),
      );
    });

    test('refuses text that is not a version', () {
      for (final input in ['', '  ', 'latest', 'v1.2.3', '1.x.0', '1.2.3+x']) {
        expect(AppVersion.tryParse(input), isNull, reason: input);
      }
    });
  });

  group('AppVersion comparison', () {
    test('compares numerically, not as text', () {
      const nine = AppVersion(major: 1, minor: 9, patch: 0);
      const ten = AppVersion(major: 1, minor: 10, patch: 0);

      // The bug this class exists to stop: '1.10.0' sorts before '1.9.0'.
      expect(nine.isOlderThan(ten), isTrue);
      expect(ten.isOlderThan(nine), isFalse);
    });

    test('takes major over minor over patch', () {
      expect(
        const AppVersion(major: 1, minor: 99, patch: 99).isOlderThan(
          const AppVersion(major: 2, minor: 0, patch: 0),
        ),
        isTrue,
      );
      expect(
        const AppVersion(major: 1, minor: 2, patch: 3).isOlderThan(
          const AppVersion(major: 1, minor: 2, patch: 4),
        ),
        isTrue,
      );
    });

    test('breaks a tie on the build number', () {
      const first = AppVersion(major: 1, minor: 0, patch: 0, build: 41);
      const second = AppVersion(major: 1, minor: 0, patch: 0, build: 42);

      expect(first.isOlderThan(second), isTrue);
      expect(second.isOlderThan(first), isFalse);
    });

    test('an equal version is not older', () {
      const version = AppVersion(major: 1, minor: 2, patch: 3, build: 4);
      expect(version.isOlderThan(version), isFalse);
    });

    test('labels without the build, prints with it', () {
      const version = AppVersion(major: 1, minor: 2, patch: 3, build: 4);
      expect(version.label, '1.2.3');
      expect(version.toString(), '1.2.3+4');
      expect(
        const AppVersion(major: 1, minor: 2, patch: 3).toString(),
        '1.2.3',
      );
    });
  });

  group('AppUpdateStatus', () {
    const current = AppVersion(major: 1, minor: 0, patch: 0, build: 5);

    test('requires nothing while the requirement is unknown', () {
      const status = AppUpdateStatus(currentVersion: current);
      expect(status.isUpdateRequired, isFalse);
    });

    test('requires an update for an older build', () {
      const status = AppUpdateStatus(
        currentVersion: current,
        requirement: UpdateRequirement(
          minVersion: AppVersion(major: 1, minor: 1, patch: 0),
        ),
      );

      expect(status.isUpdateRequired, isTrue);
    });

    test('lets the minimum itself through', () {
      const status = AppUpdateStatus(
        currentVersion: current,
        requirement: UpdateRequirement(
          minVersion: AppVersion(major: 1, minor: 0, patch: 0, build: 5),
        ),
      );

      expect(status.isUpdateRequired, isFalse);
    });

    test('blocks a build behind on the build number alone', () {
      const status = AppUpdateStatus(
        currentVersion: current,
        requirement: UpdateRequirement(
          minVersion: AppVersion(major: 1, minor: 0, patch: 0, build: 6),
        ),
      );

      expect(status.isUpdateRequired, isTrue);
    });
  });
}
