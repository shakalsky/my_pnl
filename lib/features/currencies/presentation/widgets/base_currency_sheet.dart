import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/core/money/currency_catalog.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/change_base_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/read_base_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/base_currency/base_currency_bloc.dart';

/// Modal for choosing the currency everything is recorded and shown in.
class BaseCurrencySheet extends StatelessWidget {
  const BaseCurrencySheet({super.key});

  /// Resolves to true once the base has been changed, so the caller can close
  /// whatever was showing the old one.
  static Future<bool?> show(BuildContext context) {
    final repository = context.read<CurrencyRepository>();
    final store = context.read<BaseCurrencyStore>();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => BaseCurrencyBloc(
          readBaseCurrency: ReadBaseCurrency(store),
          watchCurrencies: WatchCurrencies(repository),
          changeBaseCurrency: ChangeBaseCurrency(
            repository: repository,
            store: store,
          ),
        )..add(const BaseCurrencySubscriptionRequested()),
        child: const BaseCurrencySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<BaseCurrencyBloc, BaseCurrencyState>(
      listenWhen: (previous, current) =>
          previous.changed != current.changed ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage case final message?) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        // Closed rather than left open showing the new base: the sheet beneath
        // is labelled with the old one, and the caller closes that on the way
        // out.
        if (state.changed) Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Base currency', style: theme.textTheme.titleLarge),
              Text(
                'What every amount is recorded in, and what rates are quoted '
                'against.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // Capped so the list scrolls inside the modal rather than pushing
              // it off the top.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: switch (state.status) {
                  BaseCurrencyStatus.initial ||
                  BaseCurrencyStatus.loading => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  // The list of what would be removed is part of what the reader
                  // agrees to, so without it there is nothing safe to offer.
                  BaseCurrencyStatus.failure => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Could not load your currencies'),
                    ),
                  ),
                  BaseCurrencyStatus.success => _CurrencyOptions(state: state),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyOptions extends StatelessWidget {
  const _CurrencyOptions({required this.state});

  final BaseCurrencyState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = state.options;

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final option = options[index];
        final isCurrent = option.ticker == state.base.ticker;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isCurrent
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.secondaryContainer,
            child: Text(
              option.symbol,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isCurrent
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          title: Text(option.ticker),
          subtitle: Text(option.name),
          trailing: isCurrent
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          // The one in force is not a choice, and nothing is submitted twice.
          enabled: !isCurrent && !state.isSubmitting,
          onTap: () async {
            final bloc = context.read<BaseCurrencyBloc>();
            if (await _confirm(context, option) ?? false) {
              bloc.add(BaseCurrencyChosen(option.asBase));
            }
          },
        );
      },
    );
  }

  Future<bool?> _confirm(BuildContext context, CatalogCurrency chosen) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Switch to ${chosen.ticker}?'),
        content: Text(
          _consequences(
            chosen: chosen,
            current: state.base,
            currencies: state.currencies,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Switch to ${chosen.ticker}'),
          ),
        ],
      ),
    );
  }

  /// What changing the base does, named specifically enough to agree to.
  ///
  /// The currencies are listed by ticker rather than counted: "3 currencies will
  /// be deleted" is not something anyone can check before agreeing to it.
  static String _consequences({
    required CatalogCurrency chosen,
    required BaseCurrency current,
    required List<Currency> currencies,
  }) {
    final kept =
        'Amounts already recorded keep the numbers they were saved '
        'with — they will be shown in ${chosen.ticker} from now on.';

    if (currencies.isEmpty) return kept;

    // The chosen currency may be one the reader added. It goes as well: it is
    // the base now, and nothing is quoted against itself.
    final adopted = currencies.where((c) => c.ticker == chosen.ticker).toList();
    final others = currencies.where((c) => c.ticker != chosen.ticker).toList();

    final buffer = StringBuffer();

    if (others.isNotEmpty) {
      buffer.write(
        'The currencies you added are quoted against ${current.ticker}, so '
        'they cannot be kept: ${_tickers(others)} will be deleted. ',
      );
    }
    if (adopted.isNotEmpty) {
      buffer.write(
        '${chosen.ticker} leaves your added currencies as well — it is the '
        'base now, so there is no rate left for it to hold. ',
      );
    }

    return '$buffer$kept';
  }

  /// `EUR`, `EUR and GBP`, `EUR, GBP and PLN`.
  static String _tickers(List<Currency> currencies) {
    final tickers = currencies.map((currency) => currency.ticker).toList();
    if (tickers.length == 1) return tickers.single;

    final last = tickers.removeLast();
    return '${tickers.join(', ')} and $last';
  }
}
