import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// A currency the base can be switched to, with enough about it to be picked out
/// of a list.
class CatalogCurrency extends Equatable {
  const CatalogCurrency({
    required this.ticker,
    required this.symbol,
    required this.name,
  });

  final String ticker;
  final String symbol;

  /// What it is called, so a list of tickers is readable by someone who does not
  /// know them all by heart.
  final String name;

  BaseCurrency get asBase => BaseCurrency(ticker: ticker, symbol: symbol);

  @override
  List<Object?> get props => [ticker, symbol, name];
}

/// The currencies offered as a base, most widely used first and the rest by
/// ticker.
///
/// A fixed list rather than something fetched: this only decides what a figure
/// is labelled with, so it needs no rates and nothing to be up to date. Anything
/// missing can still be reached — a currency the user added themselves is
/// offered alongside these.
///
/// Built per read rather than held as a constant, because the names are
/// translated: a list settled at compile time would keep whichever language was
/// in force when it was first touched.
List<CatalogCurrency> get currencyCatalog => <CatalogCurrency>[
  CatalogCurrency(
    ticker: 'USD',
    symbol: r'$',
    name: t.currencies.names['USD']!,
  ),
  CatalogCurrency(
    ticker: 'EUR',
    symbol: '€',
    name: t.currencies.names['EUR']!,
  ),
  CatalogCurrency(
    ticker: 'GBP',
    symbol: '£',
    name: t.currencies.names['GBP']!,
  ),
  CatalogCurrency(
    ticker: 'CHF',
    symbol: 'CHF',
    name: t.currencies.names['CHF']!,
  ),
  CatalogCurrency(
    ticker: 'JPY',
    symbol: '¥',
    name: t.currencies.names['JPY']!,
  ),
  CatalogCurrency(
    ticker: 'PLN',
    symbol: 'zł',
    name: t.currencies.names['PLN']!,
  ),
  CatalogCurrency(
    ticker: 'UAH',
    symbol: '₴',
    name: t.currencies.names['UAH']!,
  ),
  CatalogCurrency(
    ticker: 'AED',
    symbol: 'د.إ',
    name: t.currencies.names['AED']!,
  ),
  CatalogCurrency(
    ticker: 'AUD',
    symbol: r'A$',
    name: t.currencies.names['AUD']!,
  ),
  CatalogCurrency(
    ticker: 'BGN',
    symbol: 'лв',
    name: t.currencies.names['BGN']!,
  ),
  CatalogCurrency(
    ticker: 'BRL',
    symbol: r'R$',
    name: t.currencies.names['BRL']!,
  ),
  CatalogCurrency(
    ticker: 'CAD',
    symbol: r'C$',
    name: t.currencies.names['CAD']!,
  ),
  CatalogCurrency(
    ticker: 'CNY',
    symbol: '¥',
    name: t.currencies.names['CNY']!,
  ),
  CatalogCurrency(
    ticker: 'CZK',
    symbol: 'Kč',
    name: t.currencies.names['CZK']!,
  ),
  CatalogCurrency(
    ticker: 'DKK',
    symbol: 'kr',
    name: t.currencies.names['DKK']!,
  ),
  CatalogCurrency(
    ticker: 'GEL',
    symbol: '₾',
    name: t.currencies.names['GEL']!,
  ),
  CatalogCurrency(
    ticker: 'HKD',
    symbol: r'HK$',
    name: t.currencies.names['HKD']!,
  ),
  CatalogCurrency(
    ticker: 'HUF',
    symbol: 'Ft',
    name: t.currencies.names['HUF']!,
  ),
  CatalogCurrency(
    ticker: 'ILS',
    symbol: '₪',
    name: t.currencies.names['ILS']!,
  ),
  CatalogCurrency(
    ticker: 'INR',
    symbol: '₹',
    name: t.currencies.names['INR']!,
  ),
  CatalogCurrency(
    ticker: 'KRW',
    symbol: '₩',
    name: t.currencies.names['KRW']!,
  ),
  CatalogCurrency(
    ticker: 'KZT',
    symbol: '₸',
    name: t.currencies.names['KZT']!,
  ),
  CatalogCurrency(
    ticker: 'MXN',
    symbol: r'MX$',
    name: t.currencies.names['MXN']!,
  ),
  CatalogCurrency(
    ticker: 'NOK',
    symbol: 'kr',
    name: t.currencies.names['NOK']!,
  ),
  CatalogCurrency(
    ticker: 'NZD',
    symbol: r'NZ$',
    name: t.currencies.names['NZD']!,
  ),
  CatalogCurrency(
    ticker: 'RON',
    symbol: 'lei',
    name: t.currencies.names['RON']!,
  ),
  CatalogCurrency(
    ticker: 'RSD',
    symbol: 'дин',
    name: t.currencies.names['RSD']!,
  ),
  CatalogCurrency(
    ticker: 'SEK',
    symbol: 'kr',
    name: t.currencies.names['SEK']!,
  ),
  CatalogCurrency(
    ticker: 'SGD',
    symbol: r'S$',
    name: t.currencies.names['SGD']!,
  ),
  CatalogCurrency(
    ticker: 'THB',
    symbol: '฿',
    name: t.currencies.names['THB']!,
  ),
  CatalogCurrency(
    ticker: 'TRY',
    symbol: '₺',
    name: t.currencies.names['TRY']!,
  ),
  CatalogCurrency(
    ticker: 'ZAR',
    symbol: 'R',
    name: t.currencies.names['ZAR']!,
  ),
];
