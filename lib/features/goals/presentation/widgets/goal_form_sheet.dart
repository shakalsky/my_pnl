import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/goals/domain/usecases/save_goal.dart';
import 'package:my_pnl/features/goals/presentation/bloc/goal_form/goal_form_bloc.dart';

/// Modal for setting how much to save up.
class GoalFormSheet extends StatelessWidget {
  const GoalFormSheet({super.key});

  /// Opens seeded with [initial], or empty when no goal is set yet.
  static Future<void> show(BuildContext context, {SavingsGoal? initial}) {
    final repository = context.read<GoalRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) =>
            GoalFormBloc(saveGoal: SaveGoal(repository), initial: initial),
        child: const GoalFormSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GoalFormBloc, GoalFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == GoalFormStatus.success) {
          Navigator.of(context).pop();
        }
      },
      child: const _GoalForm(),
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm();

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    // Seeded once from the bloc so editing opens with the current figure.
    _amount = TextEditingController(
      text: context.read<GoalFormBloc>().state.amount,
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<GoalFormBloc>();
    final state = context.watch<GoalFormBloc>().state;

    return AnimatedPadding(
      // Follows the keyboard: one field and the button under it, both in the
      // bottom half of a short sheet, so a fixed height would hide them.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.isEditing ? 'Edit your goal' : 'Set a goal',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Every month you finish up adds to it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              // Blocks anything the parser would reject, so the field cannot
              // hold text that silently fails on submit. No minus: saving
              // towards a negative figure is not a goal.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
              ],
              style: theme.textTheme.headlineMedium,
              decoration: const InputDecoration(
                labelText: 'Target',
                prefixText: r'$ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => bloc.add(GoalAmountChanged(value)),
              onSubmitted: (_) => bloc.add(const GoalFormSubmitted()),
            ),
            const SizedBox(height: 8),
            Text(
              'Saving up ${formatAmount(state.amountScaled ?? 0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isValid && !state.isSubmitting
                    ? () => bloc.add(const GoalFormSubmitted())
                    : null,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(state.isEditing ? 'Save goal' : 'Set goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
