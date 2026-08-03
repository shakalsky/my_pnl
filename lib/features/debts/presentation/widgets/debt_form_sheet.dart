import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/debts/domain/usecases/save_debt.dart';
import 'package:my_pnl/features/debts/presentation/bloc/debt_form/debt_form_bloc.dart';

/// Modal for recording or editing a debt.
class DebtFormSheet extends StatelessWidget {
  const DebtFormSheet({super.key});

  /// Records a new debt, pointing whichever way [direction] says.
  static Future<void> showCreate(
    BuildContext context, {
    DebtDirection direction = DebtDirection.owedToMe,
  }) => _show(context, direction: direction, initial: null);

  static Future<void> showEdit(BuildContext context, Debt debt) =>
      _show(context, direction: debt.direction, initial: debt);

  static Future<void> _show(
    BuildContext context, {
    required DebtDirection direction,
    required Debt? initial,
  }) {
    final repository = context.read<DebtRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => DebtFormBloc(
          saveDebt: SaveDebt(repository),
          direction: direction,
          initial: initial,
        ),
        child: const DebtFormSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DebtFormBloc, DebtFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == DebtFormStatus.success) {
          Navigator.of(context).pop();
        }
      },
      child: const _DebtForm(),
    );
  }
}

class _DebtForm extends StatefulWidget {
  const _DebtForm();

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  late final TextEditingController _counterparty;
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    // Seeded once from the bloc so editing opens with the current values.
    final state = context.read<DebtFormBloc>().state;
    _counterparty = TextEditingController(text: state.counterparty);
    _amount = TextEditingController(text: state.amount);
    _note = TextEditingController(text: state.note);
  }

  @override
  void dispose() {
    _counterparty.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current?.toLocal() ?? now,
      // A debt can be dated in the past — one recorded late is still owed.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'Due date',
    );

    if (picked != null && mounted) {
      context.read<DebtFormBloc>().add(DebtDueDateChanged(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<DebtFormBloc>();
    final state = context.watch<DebtFormBloc>().state;
    final dateFormat = DateFormat.yMMMd();

    return AnimatedPadding(
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
              state.isEditing ? 'Edit debt' : 'New debt',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DebtDirection>(
                segments: const [
                  ButtonSegment(
                    value: DebtDirection.owedToMe,
                    label: Text('They owe me'),
                  ),
                  ButtonSegment(
                    value: DebtDirection.owedByMe,
                    label: Text('I owe'),
                  ),
                ],
                selected: {state.direction},
                onSelectionChanged: (selection) =>
                    bloc.add(DebtDirectionChanged(selection.first)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _counterparty,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              decoration: const InputDecoration(
                labelText: 'Who',
                hintText: 'Alex',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => bloc.add(DebtCounterpartyChanged(value)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // No minus sign: which way the money points is the segmented
              // button's job, not something typed into the amount.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: r'$ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => bloc.add(DebtAmountChanged(value)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'What for',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => bloc.add(DebtNoteChanged(value)),
              onSubmitted: (_) => bloc.add(const DebtFormSubmitted()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDueDate(state.dueAt),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      state.dueAt == null
                          ? 'Add a due date'
                          : 'Due ${dateFormat.format(state.dueAt!.toLocal())}',
                    ),
                  ),
                ),
                if (state.dueAt != null)
                  IconButton(
                    onPressed: () => bloc.add(const DebtDueDateChanged(null)),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear due date',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _summary(state),
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
                    ? () => bloc.add(const DebtFormSubmitted())
                    : null,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(state.isEditing ? 'Save' : 'Add debt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Says the debt back in a sentence, so the direction cannot be misread.
  String _summary(DebtFormState state) {
    final amount = formatAmount(state.amountScaled ?? 0);
    final who = state.counterparty.trim().isEmpty
        ? 'they'
        : state.counterparty.trim();

    return state.isOwedToMe ? '$who owes you $amount' : 'You owe $who $amount';
  }
}
