import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/delete_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/currency_list/currency_list_bloc.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_form_sheet.dart';

/// Modal listing the user's currencies.
class CurrencyListSheet extends StatelessWidget {
  const CurrencyListSheet({super.key});

  static Future<void> show(BuildContext context) {
    final repository = context.read<CurrencyRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => CurrencyListBloc(
          watchCurrencies: WatchCurrencies(repository),
          deleteCurrency: DeleteCurrency(repository),
        )..add(const CurrencyListSubscriptionRequested()),
        child: const CurrencyListSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<CurrencyListBloc, CurrencyListState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.errorMessage case final message?) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Currencies', style: theme.textTheme.titleLarge),
                        Text(
                          'Rates are against $baseCurrency',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => CurrencyFormSheet.showCreate(context),
                    icon: const Icon(Icons.add),
                    tooltip: 'Add currency',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Capped so a long list scrolls inside the modal rather than
              // pushing it off the top.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: switch (state.status) {
                  CurrencyListStatus.initial ||
                  CurrencyListStatus.loading => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  CurrencyListStatus.failure => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Could not load currencies')),
                  ),
                  CurrencyListStatus.success => _CurrencyList(
                    currencies: state.currencies,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrencyList extends StatelessWidget {
  const _CurrencyList({required this.currencies});

  final List<Currency> currencies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (currencies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No currencies yet. Everything is in $baseCurrency.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: currencies.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final currency = currencies[index];

        return ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => CurrencyFormSheet.showEdit(context, currency),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              currency.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          title: Text(currency.ticker),
          subtitle: Text(
            '1 ${currency.ticker} = '
            '${formatRate(currency.exchangeRateScaled)} $baseCurrency',
          ),
          trailing: IconButton(
            onPressed: () async {
              final bloc = context.read<CurrencyListBloc>();
              if (await _confirmDelete(context, currency) ?? false) {
                bloc.add(CurrencyDeleted(currency.id));
              }
            },
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Remove ${currency.ticker}',
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, Currency currency) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${currency.ticker}?'),
        content: const Text(
          'Amounts already recorded keep the values they were saved with.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
