import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/features/sync/domain/entities/sync_state.dart';
import 'package:my_pnl/features/sync/domain/repositories/sync_repository.dart';
import 'package:my_pnl/features/sync/domain/usecases/watch_sync_state.dart';
import 'package:my_pnl/features/sync/presentation/bloc/sync_indicator/sync_indicator_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// A coloured dot reporting sync, with the detail behind a tap.
///
/// Green synced, amber syncing, red failed, grey idle. Deliberately silent
/// until tapped: sync is background business, and a banner for every state
/// change would be noise.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SyncIndicatorBloc(
            watchSyncState: WatchSyncState(context.read<SyncRepository>()),
          )..add(const SyncIndicatorSubscriptionRequested()),
      child: const SyncIndicatorView(),
    );
  }
}

class SyncIndicatorView extends StatelessWidget {
  const SyncIndicatorView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SyncIndicatorBloc>().state;

    return Semantics(
      label: t.sync.semantics(state: _label(state.health)),
      button: true,
      child: InkResponse(
        onTap: () => _showDetail(context, state),
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color(context, state.health),
            ),
          ),
        ),
      ),
    );
  }

  static String _label(SyncHealth health) => switch (health) {
    SyncHealth.idle => t.sync.stateIdle,
    SyncHealth.syncing => t.sync.stateSyncing,
    SyncHealth.synced => t.sync.stateSynced,
    SyncHealth.failed => t.sync.stateFailed,
  };

  Color _color(BuildContext context, SyncHealth health) {
    final colors = Theme.of(context).colorScheme;

    return switch (health) {
      // Not the theme's primary/secondary: these are status colours and must
      // mean the same thing whatever the theme does.
      SyncHealth.synced => const Color(0xFF2E7D32),
      SyncHealth.syncing => const Color(0xFFF9A825),
      SyncHealth.failed => colors.error,
      SyncHealth.idle => colors.outlineVariant,
    };
  }

  void _showDetail(BuildContext context, SyncState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_detail(state)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _detail(SyncState state) {
    final format = DateFormat.yMMMd().add_jm();

    return switch (state.health) {
      SyncHealth.syncing => t.sync.detailSyncing,
      SyncHealth.synced => switch (state.lastSyncedAt) {
        // Stored UTC, shown in the reader's zone.
        final at? => t.sync.detailLastSynced(
          at: format.format(at.toLocal()),
        ),
        _ => t.sync.detailSynced,
      },
      SyncHealth.failed => switch (state.lastFailedAt) {
        final at? => t.sync.detailFailedAt(at: format.format(at.toLocal())),
        _ => t.sync.detailFailed,
      },
      SyncHealth.idle => t.sync.detailIdle,
    };
  }
}
