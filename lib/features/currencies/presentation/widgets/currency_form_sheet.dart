import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/save_currency.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/currency_form/currency_form_bloc.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Modal for adding or editing a currency.
class CurrencyFormSheet extends StatelessWidget {
  const CurrencyFormSheet({super.key});

  static Future<void> showCreate(BuildContext context) => _show(context, null);

  static Future<void> showEdit(BuildContext context, Currency currency) =>
      _show(context, currency);

  static Future<void> _show(BuildContext context, Currency? initial) {
    final repository = context.read<CurrencyRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => CurrencyFormBloc(
          saveCurrency: SaveCurrency(repository),
          initial: initial,
        ),
        child: const CurrencyFormSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CurrencyFormBloc, CurrencyFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CurrencyFormStatus.success) {
          Navigator.of(context).pop();
        }
      },
      child: const _CurrencyForm(),
    );
  }
}

class _CurrencyForm extends StatefulWidget {
  const _CurrencyForm();

  @override
  State<_CurrencyForm> createState() => _CurrencyFormState();
}

class _CurrencyFormState extends State<_CurrencyForm> {
  late final TextEditingController _ticker;
  late final TextEditingController _icon;
  late final TextEditingController _rate;

  @override
  void initState() {
    super.initState();
    // Seeded once from the bloc so editing opens with the current values.
    final state = context.read<CurrencyFormBloc>().state;
    _ticker = TextEditingController(text: state.ticker);
    _icon = TextEditingController(text: state.icon);
    _rate = TextEditingController(text: state.rate);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _icon.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CurrencyFormBloc>();
    final state = context.watch<CurrencyFormBloc>().state;

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
              state.isEditing
                  ? t.currencies.formEditTitle
                  : t.currencies.formCreateTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: AppInput.white(
                    controller: _icon,
                    label: t.currencies.sign,
                    inputHintText: '€',
                    textAlign: TextAlign.center,
                    textStyle: theme.textTheme.titleLarge,
                    // Counted in characters rather than code units, so a
                    // multi-part emoji is one of the four rather than several.
                    inputFormatters: [LengthLimitingTextInputFormatter(4)],
                    // Too narrow to give up room to a clear button.
                    showClearButton: false,
                    onChanged: (value) => bloc.add(CurrencyIconChanged(value)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInput.white(
                    controller: _ticker,
                    label: t.currencies.ticker,
                    inputHintText: 'EUR',
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    // Tickers are stored upper-case; forcing it here means the
                    // field matches what will be saved.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(10),
                      _UpperCaseFormatter(),
                    ],
                    onChanged: (value) =>
                        bloc.add(CurrencyTickerChanged(value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _SignSuggestions(
              selected: state.icon,
              onPicked: (sign) {
                // Straight into the field as well as the bloc, so the two do
                // not disagree about what is about to be saved.
                _icon.text = sign;
                bloc.add(CurrencyIconChanged(sign));
              },
            ),
            const SizedBox(height: 12),
            AppInput.white(
              controller: _rate,
              label: t.currencies.exchangeRate,
              hint: t.currencies.rateHint(
                unit: state.ticker.isEmpty ? t.currencies.unit : state.ticker,
                base: baseCurrency,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,6}')),
              ],
              onChanged: (value) => bloc.add(CurrencyRateChanged(value)),
              onFieldSubmitted: (_) => bloc.add(const CurrencyFormSubmitted()),
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
                    ? () => bloc.add(const CurrencyFormSubmitted())
                    : null,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        state.isEditing
                            ? t.common.save
                            : t.currencies.formCreate,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signs offered as one-tap alternatives to typing one.
///
/// Emoji sit alongside the currency symbols on purpose: the sign is only ever
/// displayed, never parsed, so anything that reads clearly in front of a figure
/// is fair game — and an emoji is easier to tell apart at a glance than two
/// similar symbols. The keyboard still works for anything not offered here.
const _suggestedSigns = ['€', '£', '¥', '₴', '₿', '🪙', '💵', '💰'];

class _SignSuggestions extends StatelessWidget {
  const _SignSuggestions({required this.selected, required this.onPicked});

  /// What the field holds now, so a matching suggestion reads as chosen.
  final String selected;

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final sign in _suggestedSigns)
          ChoiceChip(
            label: Text(sign),
            selected: selected == sign,
            visualDensity: VisualDensity.compact,
            // Picking the chosen one again clears it, which is the only way
            // back to showing the ticker without reaching for the keyboard.
            onSelected: (isSelected) => onPicked(isSelected ? sign : ''),
          ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
