import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pnl/app/routing/stream_listenable.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/app_update/presentation/pages/required_update_page.dart';
import 'package:my_pnl/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_pnl/features/auth/presentation/pages/sign_in_page.dart';
import 'package:my_pnl/features/debts/presentation/pages/debts_page.dart';
import 'package:my_pnl/features/goals/presentation/pages/goal_page.dart';
import 'package:my_pnl/features/spending/presentation/pages/overview_pager_page.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Every route in the app.
///
/// Navigate by name (`context.goNamed(AppRoute.spending.name)`) rather than by
/// path string, so a path change is a one-line edit here.
enum AppRoute {
  /// Spending and income both, as one pager. No route of its own for income:
  /// the two are peers on one screen, and a second path to half of it could
  /// only land somewhere the swipe could not get back from.
  spending('/'),
  debts('/debts'),
  goal('/goal'),
  signIn('/sign-in'),
  update('/update');

  const AppRoute(this.path);

  final String path;
}

/// Builds the router.
///
/// Takes the repository rather than reading it from a context: the router
/// outlives any single build, and its redirect has to answer synchronously.
/// Call once and hold the result — a [GoRouter] owns navigation state, so
/// rebuilding it resets the stack.
GoRouter createAppRouter({
  required AuthRepository authRepository,
  required AppUpdateRepository appUpdateRepository,
}) {
  return GoRouter(
    initialLocation: AppRoute.spending.path,
    // Both gates below depend on state that changes outside navigation, so the
    // router has to be told when either moves.
    refreshListenable: Listenable.merge([
      StreamListenable(authRepository.watchUser()),
      StreamListenable(appUpdateRepository.watchStatus()),
    ]),
    redirect: (context, state) {
      final atUpdate = state.matchedLocation == AppRoute.update.path;

      // Checked before sign-in: a build the backend has stopped supporting has
      // no business signing anyone in, and the screen has to be reachable
      // whether or not there is a session.
      if (appUpdateRepository.status.isUpdateRequired) {
        return atUpdate ? null : AppRoute.update.path;
      }
      // The requirement was lifted, or the user really did update.
      if (atUpdate) return AppRoute.spending.path;

      final signedIn = authRepository.currentUser != null;
      final atSignIn = state.matchedLocation == AppRoute.signIn.path;

      if (!signedIn && !atSignIn) return AppRoute.signIn.path;
      if (signedIn && atSignIn) return AppRoute.spending.path;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.spending.path,
        name: AppRoute.spending.name,
        builder: (context, state) => const OverviewPagerPage(),
      ),
      GoRoute(
        path: AppRoute.debts.path,
        name: AppRoute.debts.name,
        builder: (context, state) => const DebtsPage(),
      ),
      GoRoute(
        path: AppRoute.goal.path,
        name: AppRoute.goal.name,
        builder: (context, state) => const GoalPage(),
      ),
      GoRoute(
        path: AppRoute.signIn.path,
        name: AppRoute.signIn.name,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoute.update.path,
        name: AppRoute.update.name,
        builder: (context, state) => const RequiredUpdatePage(),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(
          body: Center(child: Text(t.router.noRoute(uri: state.uri))),
        ),
  );
}
