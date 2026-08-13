import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/repositories/overrun_settings_store.dart';
import 'package:my_pnl/features/spending/domain/usecases/read_overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/usecases/save_overrun_settings.dart';
import 'package:my_pnl/features/spending/presentation/bloc/overrun_settings/overrun_settings_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/overrun_style.dart';

/// Modal for setting when a month counts as having run past the usual.
class OverrunSettingsSheet extends StatelessWidget {
  const OverrunSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final store = context.read<OverrunSettingsStore>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => OverrunSettingsBloc(
          readOverrunSettings: ReadOverrunSettings(store),
          saveOverrunSettings: SaveOverrunSettings(store),
        )..add(const OverrunSettingsRequested()),
        child: const OverrunSettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OverrunSettingsBloc, OverrunSettingsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == OverrunSettingsStatus.success) {
          Navigator.of(context).pop();
        }
      },
      child: const _OverrunSettingsForm(),
    );
  }
}

class _OverrunSettingsForm extends StatelessWidget {
  const _OverrunSettingsForm();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<OverrunSettingsBloc>();
    final state = context.watch<OverrunSettingsBloc>().state;
    final settings = state.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unusual months', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'A category is outlined when this month costs more than the '
            '${SpendBaseline.lookbackMonths} before it usually did.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.enabled,
            onChanged: (on) => bloc.add(OverrunWarningsToggled(on: on)),
            title: const Text('Warn me about unusual months'),
            contentPadding: EdgeInsets.zero,
          ),
          // The thresholds are only meaningful while the warnings are on, and a
          // row of live sliders under an off switch reads as though they still
          // do something.
          for (final level in SpendOverrun.values)
            if (level.isFlagged)
              _ThresholdSlider(
                level: level,
                percent: settings.percentFor(level),
                enabled: settings.enabled,
                onChanged: (percent) =>
                    bloc.add(OverrunThresholdChanged(level, percent)),
              ),
          if (state.errorMessage case final message?) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: state.isDefault || state.isSubmitting
                    ? null
                    : () => bloc.add(const OverrunSettingsRestored()),
                child: const Text('Reset'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => bloc.add(const OverrunSettingsSubmitted()),
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One level's threshold, with a swatch of the border it draws.
class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.level,
    required this.percent,
    required this.enabled,
    required this.onChanged,
  });

  final SpendOverrun level;
  final int percent;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = overrunBorderColor(level)!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The colour it will draw, shown as the border it will draw: the
              // setting is about a specific outline, and naming the level
              // without showing it leaves the reader to guess which is which.
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(color: color, width: overrunBorderWidth),
                ),
              ),
              const SizedBox(width: 8),
              Text(_labelFor(level), style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                '$percent% of usual',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: percent.toDouble(),
            min: OverrunSettings.minPercent.toDouble(),
            max: OverrunSettings.maxPercent.toDouble(),
            // Whole steps, so the figure beside the slider is one someone could
            // have chosen deliberately rather than 137%.
            divisions:
                (OverrunSettings.maxPercent - OverrunSettings.minPercent) ~/
                OverrunSettings.percentStep,
            label: '$percent%',
            activeColor: color,
            onChanged: enabled ? (value) => onChanged(value.round()) : null,
          ),
        ],
      ),
    );
  }

  /// What each level is called in the form.
  ///
  /// Worded as the reader's own scale rather than by colour name: the swatch
  /// beside it already says which colour, and "dark red" means nothing to
  /// someone who cannot see it.
  static String _labelFor(SpendOverrun level) => switch (level) {
    SpendOverrun.none => '',
    SpendOverrun.mild => 'Worth a look',
    SpendOverrun.high => 'Well over',
    SpendOverrun.severe => 'Far over',
  };
}
