import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_overview_body.dart';
import 'package:my_pnl/features/spending/presentation/widgets/total_circle.dart';

import '../../../../helpers/helpers.dart';

const _red = Color(0xFFFF0000);
const _green = Color(0xFF00FF00);
const _blue = Color(0xFF0000FF);

const double _fullTurn = 2 * math.pi;
const double _twelveOClock = -math.pi / 2;

const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000, // 1 EUR = 1.08 USD
);

/// No sign of its own, so its ticker is what a figure carries.
const _krona = Currency(
  id: 'currency-2',
  ticker: 'SEK',
  exchangeRateScaled: 92500, // 1 SEK = 0.0925 USD
);

/// The month these bodies are showing. A past one, so the forward arrow is
/// live — the current month has nothing after it to page to.
const _viewing = CalendarMonth(2026, 3);

/// One category worth $42.35, with the circle showing that same total.
const _oneCategoryBody = CategoryOverviewBody(
  state: SpendingOverviewState(
    month: _viewing,
    status: SpendingOverviewStatus.success,
    categories: [
      CategorySpend(
        category: Category(
          id: 'groceries',
          name: 'Groceries',
          colorArgb: 0xFFFF0000,
          iconKey: 'groceries',
        ),
        totalScaled: -4235,
      ),
    ],
  ),
  kind: CategoryKind.expense,
  totalLabel: 'Total spent',
  totalScaled: 4235,
);

void main() {
  group('ringArcs', () {
    test('has nothing to draw without segments', () {
      expect(ringArcs(const []), isEmpty);
    });

    test('has nothing to draw when every segment is empty', () {
      expect(
        ringArcs(const [
          TotalCircleSegment(color: _red, weightScaled: 0),
          // Signed amounts should never reach here, but a negative slice has no
          // length either way.
          TotalCircleSegment(color: _green, weightScaled: -500),
        ]),
        isEmpty,
      );
    });

    test('gives each segment its share of the circle', () {
      final arcs = ringArcs(
        const [
          TotalCircleSegment(color: _red, weightScaled: 7500),
          TotalCircleSegment(color: _green, weightScaled: 2500),
        ],
        gap: 0,
      );

      expect(arcs, hasLength(2));
      expect(arcs.first.color, _red);
      expect(arcs.first.sweep, closeTo(_fullTurn * 0.75, 0.0001));
      expect(arcs.last.color, _green);
      expect(arcs.last.sweep, closeTo(_fullTurn * 0.25, 0.0001));
    });

    test('starts at twelve o’clock and runs on from there', () {
      final arcs = ringArcs(
        const [
          TotalCircleSegment(color: _red, weightScaled: 100),
          TotalCircleSegment(color: _green, weightScaled: 100),
          TotalCircleSegment(color: _blue, weightScaled: 200),
        ],
        gap: 0,
      );

      expect(arcs.first.start, closeTo(_twelveOClock, 0.0001));
      // No overlaps and no holes: each picks up where the last left off.
      for (var i = 1; i < arcs.length; i++) {
        expect(
          arcs[i].start,
          closeTo(arcs[i - 1].start + arcs[i - 1].sweep, 0.0001),
          reason: 'arc $i',
        );
      }
    });

    test('fills the whole circle, gaps included', () {
      final arcs = ringArcs(const [
        TotalCircleSegment(color: _red, weightScaled: 1234),
        TotalCircleSegment(color: _green, weightScaled: 4321),
        TotalCircleSegment(color: _blue, weightScaled: 99),
      ]);

      final drawn = arcs.fold<double>(0, (sum, arc) => sum + arc.sweep);
      final last = arcs.last;

      // The drawn length is a full turn less the gaps between slices, and the
      // ring still closes where it started.
      expect(drawn, lessThan(_fullTurn));
      expect(drawn, greaterThan(_fullTurn * 0.9));
      expect(last.start + last.sweep, lessThan(_twelveOClock + _fullTurn));
    });

    test('leaves a lone segment unbroken', () {
      final arcs = ringArcs(const [
        TotalCircleSegment(color: _red, weightScaled: 4235),
      ]);

      // A gap here would be a notch in a circle with nothing to separate it
      // from.
      expect(arcs.single.sweep, closeTo(_fullTurn, 0.0001));
      expect(arcs.single.start, closeTo(_twelveOClock, 0.0001));
    });

    test('keeps a sliver of a tiny segment visible', () {
      final arcs = ringArcs(
        const [
          TotalCircleSegment(color: _red, weightScaled: 999900),
          TotalCircleSegment(color: _green, weightScaled: 100),
        ],
        // A gap far wider than the small slice, which would otherwise swallow
        // it whole.
        gap: 1,
      );

      expect(arcs.last.sweep, greaterThan(0));
    });

    test('skips a category with nothing booked against it', () {
      final arcs = ringArcs(
        const [
          TotalCircleSegment(color: _red, weightScaled: 100),
          TotalCircleSegment(color: _green, weightScaled: 0),
          TotalCircleSegment(color: _blue, weightScaled: 100),
        ],
        gap: 0,
      );

      expect(arcs.map((arc) => arc.color), [_red, _blue]);
      // The empty one takes up none of the ring rather than a third of it.
      expect(arcs.first.sweep, closeTo(math.pi, 0.0001));
    });
  });

  group('TotalCircle', () {
    testWidgets('shows the total and its label', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 200,
              child: TotalCircle(
                totalScaled: 4235,
                segments: [
                  TotalCircleSegment(color: _red, weightScaled: 4235),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text(r'$42.35'), findsOneWidget);
      expect(find.text('Total spent'), findsOneWidget);
    });

    testWidgets('renders with nothing to break down', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 200,
              child: TotalCircle(totalScaled: 0),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(r'$0.00'), findsOneWidget);
    });
  });

  group('CategoryOverviewBody currency cycling', () {
    late FakeCurrencyRepository currencies;

    setUp(() => currencies = FakeCurrencyRepository());
    tearDown(() => currencies.close());

    Future<void> openBody(
      WidgetTester tester, {
      FakeDisplayCurrencyStore? store,
    }) async {
      await tester.pumpApp(
        const Scaffold(body: _oneCategoryBody),
        currencyRepository: currencies,
        displayCurrencyStore: store,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('reads in the base currency to begin with', (tester) async {
      currencies = FakeCurrencyRepository(initial: const [_euro]);
      await openBody(tester);

      expect(find.text(r'$42.35'), findsOneWidget);
    });

    testWidgets('a tap converts the total, another brings it back', (
      tester,
    ) async {
      currencies = FakeCurrencyRepository(initial: const [_euro]);
      await openBody(tester);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();

      // $42.35 at 1.08 to the euro, with the euro's own sign.
      expect(find.text('€39.21'), findsOneWidget);
      expect(find.text(r'$42.35'), findsNothing);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();

      expect(find.text(r'$42.35'), findsOneWidget);
    });

    testWidgets('walks through every currency in turn', (tester) async {
      currencies = FakeCurrencyRepository(initial: const [_euro, _krona]);
      await openBody(tester);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();
      expect(find.text('€39.21'), findsOneWidget);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();
      // No sign on this one, so its ticker follows the figure instead.
      expect(find.text('457.84 SEK'), findsOneWidget);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();
      expect(find.text(r'$42.35'), findsOneWidget);
    });

    testWidgets('leaves the ring alone as the currency changes', (
      tester,
    ) async {
      currencies = FakeCurrencyRepository(initial: const [_euro]);
      await openBody(tester);

      final before = tester.widget<TotalCircle>(find.byType(TotalCircle));

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();

      final after = tester.widget<TotalCircle>(find.byType(TotalCircle));

      // A share of a whole is the same fraction in any currency.
      expect(after.segments, before.segments);
    });

    testWidgets('is inert with no currencies to switch to', (tester) async {
      await openBody(tester);

      final circle = tester.widget<TotalCircle>(find.byType(TotalCircle));
      expect(circle.onTap, isNull, reason: 'nothing to cycle through');

      // Tapping anyway changes nothing.
      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();
      expect(find.text(r'$42.35'), findsOneWidget);
    });

    testWidgets('converts the category totals with the circle', (tester) async {
      currencies = FakeCurrencyRepository(initial: const [_euro]);
      await openBody(tester);

      // The tile's own figure, spending being stored negative.
      expect(find.text(r'-$42.35'), findsOneWidget);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();

      // Circle and grid move together, or the page would contradict itself.
      expect(find.text('€39.21'), findsOneWidget);
      expect(find.text('-€39.21'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('opens in the currency chosen last time', (tester) async {
      currencies = FakeCurrencyRepository(initial: const [_euro]);

      // What the store holds after a tap on either page, or on a previous run.
      await openBody(
        tester,
        store: FakeDisplayCurrencyStore(remembered: _euro.id),
      );

      expect(find.text('€39.21'), findsOneWidget);
      expect(find.text('-€39.21'), findsOneWidget);
    });

    testWidgets('remembers a tap for the next page that asks', (tester) async {
      currencies = FakeCurrencyRepository(initial: const [_euro]);
      final store = FakeDisplayCurrencyStore();
      await openBody(tester, store: store);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();

      expect(store.writes, [_euro.id]);
      expect(await store.read(), _euro.id);
    });

    testWidgets('shows an emoji sign in front of the figure', (tester) async {
      currencies = FakeCurrencyRepository(
        initial: const [
          Currency(
            id: 'currency-3',
            ticker: 'GLD',
            icon: '🪙',
            exchangeRateScaled: 1000000,
          ),
        ],
      );
      await openBody(tester);

      await tester.tap(find.byType(TotalCircle));
      await tester.pumpAndSettle();

      expect(find.text('🪙42.35'), findsOneWidget);
    });
  });

  group('CategoryOverviewBody', () {
    late FakeCurrencyRepository currencies;

    setUp(() => currencies = FakeCurrencyRepository());
    tearDown(() => currencies.close());

    CategorySpend spend({
      required String id,
      required int colorArgb,
      required int totalScaled,
    }) => CategorySpend(
      category: Category(
        id: id,
        name: id,
        colorArgb: colorArgb,
        iconKey: 'groceries',
      ),
      totalScaled: totalScaled,
    );

    testWidgets('rings the total with one slice per category', (tester) async {
      final categories = [
        spend(id: 'groceries', colorArgb: 0xFFFF0000, totalScaled: -7500),
        spend(id: 'rent', colorArgb: 0xFF00FF00, totalScaled: -2500),
        // Nothing booked yet, so nothing to draw for it.
        spend(id: 'travel', colorArgb: 0xFF0000FF, totalScaled: 0),
      ];

      await tester.pumpApp(
        Scaffold(
          body: CategoryOverviewBody(
            state: SpendingOverviewState(
              month: _viewing,
              status: SpendingOverviewStatus.success,
              categories: categories,
            ),
            kind: CategoryKind.expense,
            totalLabel: 'Total spent',
          ),
        ),
        currencyRepository: currencies,
      );

      final circle = tester.widget<TotalCircle>(find.byType(TotalCircle));

      expect(circle.segments, [
        // Magnitudes: spending is stored negative, and the ring is drawn from
        // how much each category accounts for, not which way it points.
        const TotalCircleSegment(color: _red, weightScaled: 7500),
        const TotalCircleSegment(color: _green, weightScaled: 2500),
      ]);
    });

    testWidgets('rings the categories even when the middle shows a net', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          body: CategoryOverviewBody(
            state: SpendingOverviewState(
              month: _viewing,
              status: SpendingOverviewStatus.success,
              categories: [
                spend(id: 'rent', colorArgb: 0xFFFF0000, totalScaled: -2500),
              ],
            ),
            kind: CategoryKind.expense,
            totalLabel: 'Income − spending',
            // The spending page's headline: what is left, not what went out.
            totalScaled: 12000,
          ),
        ),
        currencyRepository: currencies,
      );

      final circle = tester.widget<TotalCircle>(find.byType(TotalCircle));

      expect(circle.totalScaled, 12000);
      expect(circle.segments, [
        const TotalCircleSegment(color: _red, weightScaled: 2500),
      ]);
      expect(find.text(r'$120.00'), findsOneWidget);
    });
  });
}
