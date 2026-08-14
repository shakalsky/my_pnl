import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/delete_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/currency_list/currency_list_bloc.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/base_currency_sheet.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_form_sheet.dart';
import 'package:my_pnl/i18n/strings.g.dart';

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
                        Text(t.currencies.title, style: theme.textTheme.titleLarge),
                        Text(
                          t.currencies.ratesAgainst(base: baseCurrency),
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
                    tooltip: t.currencies.addTooltip,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _BaseCurrencyTile(),
              const Divider(height: 1),
              const SizedBox(height: 4),
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
                  CurrencyListStatus.failure => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(t.currencies.loadFailed)),
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

/// The base currency, and the way to change it.
///
/// Kept at the top of this sheet rather than given a settings page of its own:
/// the base is what every rate below it is quoted against, so this is where
/// someone looking for it will be.
class _BaseCurrencyTile extends StatelessWidget {
  const _BaseCurrencyTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          baseCurrencySymbol,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(t.currencies.baseTitle),
      subtitle: Text(t.currencies.baseSubtitle(base: baseCurrency)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // Held before awaiting: this sheet is what closes, so it cannot be asked
        // for its own context afterwards.
        final navigator = Navigator.of(context);
        final changed = await BaseCurrencySheet.show(context) ?? false;

        // Every label here names the old base, and the list beneath has just
        // been emptied. Closing is clearer than redrawing an empty sheet around
        // a change the page behind already shows.
        //
        // Checked, because a base currency change rebuilds the pages: if that
        // has already happened, this sheet went with them and there is nothing
        // left to close.
        if (changed && navigator.mounted) navigator.pop();
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
            t.currencies.empty(base: baseCurrency),
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
            t.currencies.rateLine(
              ticker: currency.ticker,
              rate: formatRate(currency.exchangeRateScaled),
              base: baseCurrency,
            ),
          ),
          trailing: IconButton(
            onPressed: () async {
              final bloc = context.read<CurrencyListBloc>();
              if (await _confirmDelete(context, currency) ?? false) {
                bloc.add(CurrencyDeleted(currency.id));
              }
            },
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: t.currencies.removeTooltip(ticker: currency.ticker),
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
        title: Text(t.currencies.removeTitle(ticker: currency.ticker)),
        content: Text(t.currencies.removeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.common.remove),
          ),
        ],
      ),
    );
  }
}
