import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/record_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_spend.dart';
import 'package:my_pnl/features/spending/presentation/bloc/amount_entry/amount_entry_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';

/// Modal for booking an amount against a category.
class AmountEntrySheet extends StatelessWidget {
  const AmountEntrySheet({super.key});

  /// Books a new amount against [category].
  static Future<void> show(BuildContext context, Category category) =>
      _show(context, category, null);

  /// Corrects an existing entry.
  static Future<void> showEdit(
    BuildContext context,
    Category category,
    SpendEntry entry,
  ) => _show(context, category, entry);

  static Future<void> _show(
    BuildContext context,
    Category category,
    SpendEntry? entry,
  ) {
    final repository = context.read<TransactionRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => AmountEntryBloc(
          recordSpend: RecordSpend(repository),
          updateSpend: UpdateSpend(repository),
          category: category,
          entry: entry,
        ),
        child: const AmountEntrySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AmountEntryBloc, AmountEntryState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case AmountEntryStatus.success:
            Navigator.of(context).pop();
          case AmountEntryStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not save the amount')),
            );
          case AmountEntryStatus.editing:
          case AmountEntryStatus.submitting:
            break;
        }
      },
      child: const _AmountEntryForm(),
    );
  }
}

/// When the entry happened, and a tap to move it.
///
/// [occurredAt] is UTC, or null for an entry that has not been given a date and
/// will take the clock at save time. [onChanged] is handed a date in the
/// reader's own zone.
class _DateField extends StatelessWidget {
  const _DateField({required this.occurredAt, required this.onChanged});

  final DateTime? occurredAt;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.event_outlined, size: 18),
        label: Text(_label(context)),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  /// What the button reads. A date with no time of day: the time is carried
  /// over rather than chosen, so showing it would suggest it was.
  String _label(BuildContext context) {
    final at = occurredAt?.toLocal();
    // An entry still to be dated is being booked now, which the reader knows as
    // today — the same word a date picked today would earn below.
    if (at == null || _isToday(at)) return 'Today';

    return DateFormat.yMMMd().format(at);
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    // Whatever the entry already carries, read in the zone the picker works in.
    // A dateless entry is being booked now, so now is where the picker opens.
    final current = occurredAt?.toLocal() ?? now;

    // Five years back covers anything worth backdating by hand, but an entry
    // older than that has to stay openable — a range that excluded the date the
    // picker is opening on is an assertion, not a disabled button.
    final earliest = DateTime(now.year - 5);

    final picked = await showDatePicker(
      context: context,
      // Likewise at the top of the range: a row already dated ahead of now is
      // not this sheet's to refuse to open.
      initialDate: current.isAfter(now) ? now : current,
      firstDate: current.isBefore(earliest) ? current : earliest,
      // No future dates: the overview will not page past the month happening
      // now, so an entry booked ahead would be one the user cannot navigate to.
      lastDate: now,
    );

    if (picked == null) return;

    // The picker returns midnight. Keeping the entry's own time of day is what
    // holds its place in a day's history, which is ordered by it — and on a new
    // entry that time of day is now.
    final moved = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
    );

    // Moving a late-evening entry onto today can land it after the current time
    // even though the date itself is allowed. Nothing in the future, as above.
    onChanged(moved.isAfter(now) ? now : moved);
  }

  bool _isToday(DateTime local) {
    final now = DateTime.now();

    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }
}

class _AmountEntryForm extends StatefulWidget {
  const _AmountEntryForm();

  @override
  State<_AmountEntryForm> createState() => _AmountEntryFormState();
}

class _AmountEntryFormState extends State<_AmountEntryForm> {
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    // Seeded once from the bloc's initial state so editing opens with the
    // current amount already in the field.
    _amount = TextEditingController(
      text: context.read<AmountEntryBloc>().state.input,
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
    final bloc = context.read<AmountEntryBloc>();
    final state = context.watch<AmountEntryBloc>().state;
    final category = state.category;

    return AnimatedPadding(
      // Unlike the category sheet, this one does follow the keyboard. Its
      // whole point is a single field and the button under it, and both sit
      // in the bottom half of a short sheet — leaving the size fixed would
      // put them behind the keyboard with nothing worth scrolling to.
      // Animated so it rides up with the keyboard instead of jumping.
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
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(category.colorArgb),
                  ),
                  child: Icon(
                    iconForKey(category.iconKey),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(category.name, style: theme.textTheme.titleLarge),
                      Text(
                        state.isEditing ? 'Edit amount' : 'Add an amount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              // hold text that silently fails on submit.
              // No minus sign: the direction comes from the category's kind,
              // not from what is typed here.
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*[.,]?\d{0,2}'),
                ),
              ],
              style: theme.textTheme.headlineMedium,
              decoration: const InputDecoration(
                prefixText: r'$ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => bloc.add(AmountEntryChanged(value)),
              onSubmitted: (_) => bloc.add(const AmountEntrySubmitted()),
            ),
            const SizedBox(height: 8),
            Text(
              state.isEditing
                  ? 'Changing this entry to '
                        '${formatAmount(state.amountScaled ?? 0)}'
                  : 'Adding ${formatAmount(state.amountScaled ?? 0)} '
                        'to ${category.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _DateField(
              occurredAt: state.occurredAt,
              onChanged: (at) => bloc.add(AmountEntryDateChanged(at)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isValid && !state.isSubmitting
                    ? () => bloc.add(const AmountEntrySubmitted())
                    : null,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save amount'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
