import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/base_currency.dart';

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
const currencyCatalog = <CatalogCurrency>[
  CatalogCurrency(ticker: 'USD', symbol: r'$', name: 'US dollar'),
  CatalogCurrency(ticker: 'EUR', symbol: '€', name: 'Euro'),
  CatalogCurrency(ticker: 'GBP', symbol: '£', name: 'Pound sterling'),
  CatalogCurrency(ticker: 'CHF', symbol: 'CHF', name: 'Swiss franc'),
  CatalogCurrency(ticker: 'JPY', symbol: '¥', name: 'Japanese yen'),
  CatalogCurrency(ticker: 'PLN', symbol: 'zł', name: 'Polish złoty'),
  CatalogCurrency(ticker: 'UAH', symbol: '₴', name: 'Ukrainian hryvnia'),
  CatalogCurrency(ticker: 'AED', symbol: 'د.إ', name: 'UAE dirham'),
  CatalogCurrency(ticker: 'AUD', symbol: r'A$', name: 'Australian dollar'),
  CatalogCurrency(ticker: 'BGN', symbol: 'лв', name: 'Bulgarian lev'),
  CatalogCurrency(ticker: 'BRL', symbol: r'R$', name: 'Brazilian real'),
  CatalogCurrency(ticker: 'CAD', symbol: r'C$', name: 'Canadian dollar'),
  CatalogCurrency(ticker: 'CNY', symbol: '¥', name: 'Chinese yuan'),
  CatalogCurrency(ticker: 'CZK', symbol: 'Kč', name: 'Czech koruna'),
  CatalogCurrency(ticker: 'DKK', symbol: 'kr', name: 'Danish krone'),
  CatalogCurrency(ticker: 'GEL', symbol: '₾', name: 'Georgian lari'),
  CatalogCurrency(ticker: 'HKD', symbol: r'HK$', name: 'Hong Kong dollar'),
  CatalogCurrency(ticker: 'HUF', symbol: 'Ft', name: 'Hungarian forint'),
  CatalogCurrency(ticker: 'ILS', symbol: '₪', name: 'Israeli shekel'),
  CatalogCurrency(ticker: 'INR', symbol: '₹', name: 'Indian rupee'),
  CatalogCurrency(ticker: 'KRW', symbol: '₩', name: 'South Korean won'),
  CatalogCurrency(ticker: 'KZT', symbol: '₸', name: 'Kazakhstani tenge'),
  CatalogCurrency(ticker: 'MXN', symbol: r'MX$', name: 'Mexican peso'),
  CatalogCurrency(ticker: 'NOK', symbol: 'kr', name: 'Norwegian krone'),
  CatalogCurrency(ticker: 'NZD', symbol: r'NZ$', name: 'New Zealand dollar'),
  CatalogCurrency(ticker: 'RON', symbol: 'lei', name: 'Romanian leu'),
  CatalogCurrency(ticker: 'RSD', symbol: 'дин', name: 'Serbian dinar'),
  CatalogCurrency(ticker: 'SEK', symbol: 'kr', name: 'Swedish krona'),
  CatalogCurrency(ticker: 'SGD', symbol: r'S$', name: 'Singapore dollar'),
  CatalogCurrency(ticker: 'THB', symbol: '฿', name: 'Thai baht'),
  CatalogCurrency(ticker: 'TRY', symbol: '₺', name: 'Turkish lira'),
  CatalogCurrency(ticker: 'ZAR', symbol: 'R', name: 'South African rand'),
];
