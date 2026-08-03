import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/app_update/data/datasources/app_requirement_source.dart';
import 'package:my_pnl/features/app_update/data/repositories/remote_app_update_repository.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';

const _current = AppVersion(major: 1, minor: 0, patch: 0, build: 5);

const _needsOnePointOne = UpdateRequirement(
  minVersion: AppVersion(major: 1, minor: 1, patch: 0),
  storeUrl: 'https://example.com/app',
);

void main() {
  group('RemoteAppUpdateRepository', () {
    late List<String> asked;

    setUp(() => asked = []);

    /// Builds a repository over a fetcher that records what it was asked and
    /// answers with [answer], or throws when [answer] throws.
    RemoteAppUpdateRepository build(
      Future<UpdateRequirement?> Function() answer, {
      String platform = 'ios',
    }) {
      return RemoteAppUpdateRepository(
        fetchRequirement: (platform) {
          asked.add(platform);
          return answer();
        },
        currentVersion: _current,
        platform: platform,
      );
    }

    test('requires nothing before the first check', () {
      final repository = build(() async => _needsOnePointOne);

      expect(repository.status.isUpdateRequired, isFalse);
      expect(repository.status.currentVersion, _current);
      expect(asked, isEmpty, reason: 'nothing asked until told to');
    });

    test('asks for its own platform', () async {
      final repository = build(() async => null, platform: 'android');

      await repository.checkForUpdate();

      expect(asked, ['android']);
    });

    test('blocks once the backend reports a newer minimum', () async {
      final repository = build(() async => _needsOnePointOne);
      addTearDown(repository.close);

      await repository.checkForUpdate();

      expect(repository.status.isUpdateRequired, isTrue);
      expect(repository.status.requirement, _needsOnePointOne);
    });

    test('announces the change to listeners', () async {
      final repository = build(() async => _needsOnePointOne);
      addTearDown(repository.close);

      final seen = <bool>[];
      final subscription = repository.watchStatus().listen(
        (status) => seen.add(status.isUpdateRequired),
      );
      addTearDown(subscription.cancel);

      await repository.checkForUpdate();
      await Future<void>.delayed(Duration.zero);

      expect(seen, [true]);
    });

    test('says nothing when the answer has not changed', () async {
      final repository = build(() async => _needsOnePointOne);
      addTearDown(repository.close);

      final seen = <bool>[];
      final subscription = repository.watchStatus().listen(
        (status) => seen.add(status.isUpdateRequired),
      );
      addTearDown(subscription.cancel);

      await repository.checkForUpdate();
      await repository.checkForUpdate();
      await Future<void>.delayed(Duration.zero);

      // Twice asked, once announced: a repeated answer would otherwise make the
      // router re-run its redirect for nothing.
      expect(seen, [true]);
      expect(asked, hasLength(2));
    });

    test('lifts the requirement when the row is withdrawn', () async {
      UpdateRequirement? answer = _needsOnePointOne;
      final repository = build(() async => answer);
      addTearDown(repository.close);

      await repository.checkForUpdate();
      expect(repository.status.isUpdateRequired, isTrue);

      answer = null;
      await repository.checkForUpdate();

      expect(repository.status.isUpdateRequired, isFalse);
      expect(repository.status.requirement, isNull);
    });

    test('fails open when the backend cannot be reached', () async {
      final repository = build(() async => throw Exception('offline'));
      addTearDown(repository.close);

      await expectLater(repository.checkForUpdate(), completes);

      expect(
        repository.status.isUpdateRequired,
        isFalse,
        reason: 'an unreachable backend must not lock anyone out',
      );
    });

    test('keeps a known requirement through a failed check', () async {
      var fail = false;
      final repository = build(() async {
        if (fail) throw Exception('offline');
        return _needsOnePointOne;
      });
      addTearDown(repository.close);

      await repository.checkForUpdate();
      fail = true;
      await repository.checkForUpdate();

      expect(repository.status.isUpdateRequired, isTrue);
    });
  });

  group('LocalOnlyAppUpdateRepository', () {
    // What startup falls back to with no backend, and — since a build that
    // cannot read its own version cannot judge whether it is too old — also
    // when the version lookup fails.
    test('never requires an update', () async {
      const repository = LocalOnlyAppUpdateRepository(_current);

      expect(repository.status.isUpdateRequired, isFalse);
      expect(repository.status.requirement, isNull);

      await repository.checkForUpdate();

      expect(repository.status.isUpdateRequired, isFalse);
    });

    test('holds to that even for a version of nothing', () async {
      // The placeholder startup uses when the platform will not say. It is
      // older than every requirement, so a gate built around it would lock
      // everyone out.
      const repository = LocalOnlyAppUpdateRepository(
        AppVersion(major: 0, minor: 0, patch: 0),
      );

      expect(repository.status.isUpdateRequired, isFalse);
    });

    test('reports no changes to watch', () {
      const repository = LocalOnlyAppUpdateRepository(_current);

      expect(repository.watchStatus(), emitsInOrder(<Object>[emitsDone]));
    });
  });

  group('SupabaseAppRequirementSource.requirementFromRow', () {
    test('reads a row, grafting the build column onto the version', () {
      final requirement = SupabaseAppRequirementSource.requirementFromRow({
        'min_version': '1.2.0',
        'min_build': 30,
        'store_url': 'https://example.com/app',
        'message': 'Accounts moved to a new format.',
      });

      expect(
        requirement?.minVersion,
        const AppVersion(major: 1, minor: 2, patch: 0, build: 30),
      );
      expect(requirement?.storeUrl, 'https://example.com/app');
      expect(requirement?.message, 'Accounts moved to a new format.');
    });

    test('takes a build number that arrived as text', () {
      final requirement = SupabaseAppRequirementSource.requirementFromRow({
        'min_version': '1.2.0',
        'min_build': '30',
      });

      expect(requirement?.minVersion.build, 30);
    });

    test('treats empty strings as not set', () {
      final requirement = SupabaseAppRequirementSource.requirementFromRow({
        'min_version': '1.2.0',
        'min_build': 0,
        'store_url': '  ',
        'message': '',
      });

      expect(requirement?.storeUrl, isNull);
      expect(requirement?.message, isNull);
    });

    test('ignores a row whose version makes no sense', () {
      // A typo in the dashboard must not lock every user out.
      expect(
        SupabaseAppRequirementSource.requirementFromRow({
          'min_version': 'soon',
          'min_build': 0,
        }),
        isNull,
      );
    });
  });
}
