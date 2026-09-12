import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';
import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';
import 'package:my_pnl/features/sync/presentation/widgets/sync_indicator.dart';

import '../../../../helpers/helpers.dart';

void main() {
  group('SyncIndicator', () {
    late FakeSyncRepository repository;

    setUp(() => repository = FakeSyncRepository());
    tearDown(() => repository.close());

    Future<void> pumpIndicator(WidgetTester tester, SyncState state) async {
      repository = FakeSyncRepository(initial: state);
      await tester.pumpApp(
        const Scaffold(body: Center(child: SyncIndicator())),
        syncRepository: repository,
      );
      await tester.pumpAndSettle();
    }

    Color dotColor(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SyncIndicator),
          matching: find.byType(Container),
        ),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('is green after a successful sync', (tester) async {
      await pumpIndicator(
        tester,
        SyncState(
          health: SyncHealth.synced,
          lastSyncedAt: DateTime.utc(2026, 8, 2, 14, 30),
        ),
      );

      expect(dotColor(tester), AppSemanticColors.light.positive);

      await tester.tap(find.byType(SyncIndicator));
      await tester.pumpAndSettle();

      expect(find.textContaining('Last synced'), findsOneWidget);
      expect(find.textContaining('Aug 2, 2026'), findsOneWidget);
    });

    testWidgets('is amber while syncing and says so', (tester) async {
      await pumpIndicator(tester, const SyncState(health: SyncHealth.syncing));

      expect(dotColor(tester), AppSemanticColors.light.caution);

      await tester.tap(find.byType(SyncIndicator));
      await tester.pumpAndSettle();

      expect(find.text('Syncing'), findsOneWidget);
    });

    testWidgets('is red after a failure and dates it', (tester) async {
      await pumpIndicator(
        tester,
        SyncState(
          health: SyncHealth.failed,
          lastFailedAt: DateTime.utc(2026, 8, 1, 9),
          lastError: 'PSYNC_S2101',
        ),
      );

      final colors = ThemeData(useMaterial3: true).colorScheme;
      expect(dotColor(tester), colors.error);

      await tester.tap(find.byType(SyncIndicator));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sync failed'), findsOneWidget);
      expect(find.textContaining('Aug 1, 2026'), findsOneWidget);
    });

    testWidgets('follows the state as it changes', (tester) async {
      await pumpIndicator(tester, const SyncState(health: SyncHealth.syncing));
      expect(dotColor(tester), AppSemanticColors.light.caution);

      repository.emit(
        SyncState(health: SyncHealth.synced, lastSyncedAt: DateTime.utc(2026)),
      );
      await tester.pumpAndSettle();

      expect(dotColor(tester), AppSemanticColors.light.positive);
    });

    testWidgets('is grey and quiet with no backend', (tester) async {
      await pumpIndicator(tester, const SyncState());

      await tester.tap(find.byType(SyncIndicator));
      await tester.pumpAndSettle();

      expect(find.text('Not syncing'), findsOneWidget);
    });
  });
}
