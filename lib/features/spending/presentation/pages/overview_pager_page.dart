import 'package:flutter/material.dart';
import 'package:my_pnl/features/spending/presentation/pages/income_overview_page.dart';
import 'package:my_pnl/features/spending/presentation/pages/spending_overview_page.dart';

/// The two overviews side by side, spending showing first.
///
/// A pager rather than a pushed route: income is the other half of the same
/// ledger, not somewhere you go and come back from. A flick right brings it in,
/// a flick left puts spending back, and neither page sits on top of the other —
/// so there is no back stack to get out of step with what is on screen.
class OverviewPagerPage extends StatefulWidget {
  const OverviewPagerPage({super.key});

  @override
  State<OverviewPagerPage> createState() => _OverviewPagerPageState();
}

class _OverviewPagerPageState extends State<OverviewPagerPage> {
  /// Income sits to the left of spending, because a page is revealed from the
  /// side the finger comes from: dragging right brings in what is on the left.
  static const _income = 0;
  static const _spending = 1;

  /// Matches the length of a route transition, so arriving by the toolbar icon
  /// feels like the swipe it stands in for.
  static const _slide = Duration(milliseconds: 300);

  final _controller = PageController(initialPage: _spending);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _to(int page) =>
      _controller.animateToPage(page, duration: _slide, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return OverviewPager(
      showIncome: () => _to(_income),
      showSpending: () => _to(_spending),
      child: PageView(
        controller: _controller,
        // Keeps the page off screen built and subscribed, so swinging between
        // the two is instant rather than a spinner and a fresh set of queries
        // every time.
        allowImplicitScrolling: true,
        children: const [IncomeOverviewPage(), SpendingOverviewPage()],
      ),
    );
  }
}

/// Lets either overview move the pager without knowing where it sits in it.
///
/// The toolbar icon and the swipe end up doing the same thing, which is the
/// point: the icon is for finding the other page, the swipe is for living with
/// it.
class OverviewPager extends InheritedWidget {
  const OverviewPager({
    required this.showIncome,
    required this.showSpending,
    required super.child,
    super.key,
  });

  final VoidCallback showIncome;
  final VoidCallback showSpending;

  /// Null when a page is shown on its own rather than in the pager, which is
  /// every test that pumps one directly.
  static OverviewPager? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OverviewPager>();

  // The callbacks close over a controller that outlives every rebuild, so
  // nothing downstream ever needs to be told this changed.
  @override
  bool updateShouldNotify(OverviewPager oldWidget) => false;
}
