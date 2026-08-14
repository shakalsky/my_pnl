import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:my_pnl/features/app_update/domain/usecases/check_for_update.dart';
import 'package:my_pnl/features/app_update/domain/usecases/watch_app_update_status.dart';
import 'package:my_pnl/features/app_update/presentation/bloc/app_update/app_update_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a store listing. Returns whether anything handled it.
typedef OpenStore = Future<bool> Function(Uri url);

/// The dead end an out-of-date build lands on.
///
/// Every route redirects here while the requirement stands, so this screen has
/// to be complete on its own: what is running, what is needed, and the one way
/// out. There is no navigation off it — see the [PopScope] below.
class RequiredUpdatePage extends StatelessWidget {
  const RequiredUpdatePage({this.openStore, super.key});

  /// Injectable so a test can see where the button points without a plugin.
  final OpenStore? openStore;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AppUpdateRepository>();

    return BlocProvider(
      create: (_) =>
          AppUpdateBloc(
            watchStatus: WatchAppUpdateStatus(repository),
            checkForUpdate: CheckForUpdate(repository),
            initialStatus: repository.status,
          )..add(const AppUpdateSubscriptionRequested()),
      child: RequiredUpdateView(openStore: openStore),
    );
  }
}

class RequiredUpdateView extends StatelessWidget {
  const RequiredUpdateView({this.openStore, super.key});

  final OpenStore? openStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocBuilder<AppUpdateBloc, AppUpdateState>(
      builder: (context, state) {
        final requirement = state.requirement;

        return PopScope(
          // The back button cannot dismiss this: on Android it would otherwise
          // pop the route and leave the user in an app the backend has stopped
          // supporting.
          canPop: false,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.system_update,
                        size: 56,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t.update.title,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        requirement?.message ?? t.update.defaultMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _VersionLine(
                        currentLabel: state.currentVersion.label,
                        requiredLabel: requirement?.minVersion.label,
                      ),
                      const SizedBox(height: 32),
                      if (requirement?.storeUrl case final url?)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _open(context, url),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(t.update.action),
                          ),
                        )
                      else
                        Text(
                          t.update.noStore,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 8),
                      // Deliberately not a way past the gate: it re-asks the
                      // backend, and the router lets the user through only if
                      // the answer has actually changed.
                      TextButton(
                        onPressed: state.isChecking
                            ? null
                            : () => context.read<AppUpdateBloc>().add(
                                const AppUpdateCheckRequested(),
                              ),
                        child: state.isChecking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(t.update.recheck),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    // Read before the await: the snackbar is shown after it.
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    final open = openStore ?? _launchExternally;

    var opened = false;
    if (uri != null) {
      try {
        opened = await open(uri);
      } on Object catch (e, s) {
        // A misconfigured url_launcher, or a URL nothing on the device claims.
        log('Opening $uri failed', error: e, stackTrace: s);
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.update.openFailed)),
      );
    }
  }

  static Future<bool> _launchExternally(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

/// What is running against what is needed, side by side.
class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.currentLabel, this.requiredLabel});

  final String currentLabel;

  /// Null while the requirement is unknown, which is the case for the blink
  /// between opening this screen and the check answering.
  final String? requiredLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final style = theme.textTheme.labelLarge;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(
          t.update.youHave(version: currentLabel),
          style: style?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (requiredLabel case final required?) ...[
          Icon(Icons.arrow_forward, size: 16, color: colors.outline),
          Text(
            t.update.needs(version: required),
            style: style?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
