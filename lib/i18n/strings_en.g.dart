///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  );

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$router$en router = Translations$router$en.internal(_root);
	late final Translations$spending$en spending = Translations$spending$en.internal(_root);
	late final Translations$income$en income = Translations$income$en.internal(_root);
	late final Translations$account$en account = Translations$account$en.internal(_root);
	late final Translations$entries$en entries = Translations$entries$en.internal(_root);
	late final Translations$amountEntry$en amountEntry = Translations$amountEntry$en.internal(_root);
	late final Translations$categoryForm$en categoryForm = Translations$categoryForm$en.internal(_root);
	late final Translations$overrun$en overrun = Translations$overrun$en.internal(_root);
	late final Translations$goal$en goal = Translations$goal$en.internal(_root);
	late final Translations$debts$en debts = Translations$debts$en.internal(_root);
	late final Translations$currencies$en currencies = Translations$currencies$en.internal(_root);
	late final Translations$accounts$en accounts = Translations$accounts$en.internal(_root);
	late final Translations$auth$en auth = Translations$auth$en.internal(_root);
	late final Translations$sync$en sync = Translations$sync$en.internal(_root);
	late final Translations$update$en update = Translations$update$en.internal(_root);
	late final Translations$settings$en settings = Translations$settings$en.internal(_root);
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Create'
	String get create => 'Create';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Join'
	String get join => 'Join';

	/// en: 'Leave'
	String get leave => 'Leave';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Amount'
	String get amount => 'Amount';

	/// en: 'Optional'
	String get optional => 'Optional';

	/// en: 'Today'
	String get today => 'Today';

	/// en: 'Yesterday'
	String get yesterday => 'Yesterday';

	/// en: 'and'
	String get listAnd => 'and';
}

// Path: router
class Translations$router$en {
	Translations$router$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'No route for $uri'
	String noRoute({required Object uri}) => 'No route for ${uri}';
}

// Path: spending
class Translations$spending$en {
	Translations$spending$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Could not load your spending'
	String get loadFailed => 'Could not load your spending';

	/// en: 'Spending'
	String get totalLabel => 'Spending';

	/// en: 'All transactions'
	String get allTransactions => 'All transactions';

	/// en: 'Debts'
	String get debts => 'Debts';

	/// en: 'Goal'
	String get goal => 'Goal';

	/// en: 'Currencies'
	String get currencies => 'Currencies';

	/// en: 'Unusual months'
	String get unusualMonths => 'Unusual months';

	/// en: 'Previous month'
	String get previousMonth => 'Previous month';

	/// en: 'Next month'
	String get nextMonth => 'Next month';

	/// en: '$name settings'
	String categorySettings({required Object name}) => '${name} settings';
}

// Path: income
class Translations$income$en {
	Translations$income$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Could not load your income'
	String get loadFailed => 'Could not load your income';

	/// en: 'Total income'
	String get totalLabel => 'Total income';
}

// Path: account
class Translations$account$en {
	Translations$account$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sign out'
	String get signOut => 'Sign out';

	/// en: 'Sign out?'
	String get signOutTitle => 'Sign out?';

	/// en: 'Your synced data stays on the server. Anything not yet uploaded will be removed from this device.'
	String get signOutBody => 'Your synced data stays on the server. Anything not yet uploaded will be removed from this device.';
}

// Path: entries
class Translations$entries$en {
	Translations$entries$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'All transactions'
	String get allTitle => 'All transactions';

	/// en: 'Newest first'
	String get newestFirst => 'Newest first';

	/// en: 'Could not load transactions'
	String get loadFailed => 'Could not load transactions';

	/// en: 'Nothing recorded yet'
	String get empty => 'Nothing recorded yet';

	/// en: 'History'
	String get historyTitle => 'History';

	/// en: 'Could not load the history'
	String get historyLoadFailed => 'Could not load the history';

	/// en: 'Nothing booked here yet'
	String get historyEmpty => 'Nothing booked here yet';

	/// en: 'Uncategorised'
	String get uncategorised => 'Uncategorised';

	/// en: 'Delete entry'
	String get deleteTooltip => 'Delete entry';

	/// en: 'Only $who can change this'
	String onlyAuthorCanChange({required Object who}) => 'Only ${who} can change this';

	/// en: 'they'
	String get authorFallback => 'they';

	/// en: 'Delete this entry?'
	String get deleteTitle => 'Delete this entry?';

	/// en: '$amount will be removed from $category.'
	String deleteBodyCategory({required Object amount, required Object category}) => '${amount} will be removed from ${category}.';

	/// en: '$amount will be removed from your totals.'
	String deleteBodyTotals({required Object amount}) => '${amount} will be removed from your totals.';

	/// en: 'Could not delete that entry'
	String get deleteFailed => 'Could not delete that entry';
}

// Path: amountEntry
class Translations$amountEntry$en {
	Translations$amountEntry$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Could not save the amount'
	String get saveFailed => 'Could not save the amount';

	/// en: 'Edit amount'
	String get editSubtitle => 'Edit amount';

	/// en: 'Add an amount'
	String get createSubtitle => 'Add an amount';

	/// en: 'Changing this entry to $amount'
	String changingTo({required Object amount}) => 'Changing this entry to ${amount}';

	/// en: 'Adding $amount to $category'
	String addingTo({required Object amount, required Object category}) => 'Adding ${amount} to ${category}';

	/// en: 'Description'
	String get description => 'Description';

	/// en: 'Optional. What this one was for.'
	String get descriptionHint => 'Optional. What this one was for.';

	/// en: 'Save amount'
	String get submit => 'Save amount';
}

// Path: categoryForm
class Translations$categoryForm$en {
	Translations$categoryForm$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Could not save the category'
	String get saveFailed => 'Could not save the category';

	/// en: 'Edit income'
	String get editIncome => 'Edit income';

	/// en: 'Edit category'
	String get editExpense => 'Edit category';

	/// en: 'New income'
	String get newIncome => 'New income';

	/// en: 'New category'
	String get newExpense => 'New category';

	/// en: 'Transactions'
	String get transactions => 'Transactions';

	/// en: 'Recurring'
	String get recurring => 'Recurring';

	/// en: 'Book this income once a month'
	String get recurringSubtitle => 'Book this income once a month';

	/// en: 'Day'
	String get day => 'Day';

	/// en: 'Months shorter than the chosen day use their last day. Missed months are booked the next time you open the app.'
	String get recurringNote => 'Months shorter than the chosen day use their last day. Missed months are booked the next time you open the app.';

	/// en: 'Color'
	String get color => 'Color';

	/// en: 'Icon'
	String get icon => 'Icon';

	/// en: 'Delete category'
	String get delete => 'Delete category';

	/// en: 'Delete $name?'
	String deleteTitleNamed({required Object name}) => 'Delete ${name}?';

	/// en: 'Delete this category?'
	String get deleteTitleUnnamed => 'Delete this category?';

	/// en: 'What should happen to the amounts recorded against it? Keep them and the money stays in your totals, without a category. Delete them and it leaves your totals too.'
	String get deleteBody => 'What should happen to the amounts recorded against it?\n\nKeep them and the money stays in your totals, without a category. Delete them and it leaves your totals too.';

	/// en: 'Keep entries'
	String get keepEntries => 'Keep entries';

	/// en: 'Delete entries'
	String get deleteEntries => 'Delete entries';

	/// en: 'You already have a category called "$name"'
	String nameTaken({required Object name}) => 'You already have a category called "${name}"';
}

// Path: overrun
class Translations$overrun$en {
	Translations$overrun$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Unusual months'
	String get title => 'Unusual months';

	/// en: 'A category is outlined when this month costs more than the $months before it usually did.'
	String description({required Object months}) => 'A category is outlined when this month costs more than the ${months} before it usually did.';

	/// en: '(one) {1 month} (other) {$n months}'
	String monthsBack({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '1 month',
		other: '${n} months',
	);

	/// en: 'Warn me about unusual months'
	String get toggle => 'Warn me about unusual months';

	/// en: '$percent% of usual'
	String percentOfUsual({required Object percent}) => '${percent}% of usual';

	/// en: 'Could not save your warning settings'
	String get saveFailed => 'Could not save your warning settings';

	/// en: 'Worth a look'
	String get levelMild => 'Worth a look';

	/// en: 'Well over'
	String get levelHigh => 'Well over';

	/// en: 'Far over'
	String get levelSevere => 'Far over';

	/// en: 'Above its usual month'
	String get semanticsMild => 'Above its usual month';

	/// en: 'Well above its usual month'
	String get semanticsHigh => 'Well above its usual month';

	/// en: 'Far above its usual month'
	String get semanticsSevere => 'Far above its usual month';
}

// Path: goal
class Translations$goal$en {
	Translations$goal$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Goal'
	String get title => 'Goal';

	/// en: 'Remove goal'
	String get removeTooltip => 'Remove goal';

	/// en: 'Could not load your months'
	String get loadFailed => 'Could not load your months';

	/// en: 'Could not load your goal'
	String get loadGoalFailed => 'Could not load your goal';

	/// en: 'Could not remove your goal'
	String get removeFailed => 'Could not remove your goal';

	/// en: 'Remove your goal?'
	String get removeTitle => 'Remove your goal?';

	/// en: 'Your months stay exactly as they are — only the target goes.'
	String get removeBody => 'Your months stay exactly as they are — only the target goes.';

	/// en: 'Saved from good months'
	String get saved => 'Saved from good months';

	/// en: 'of $amount'
	String ofTarget({required Object amount}) => 'of ${amount}';

	/// en: 'Goal reached'
	String get reached => 'Goal reached';

	/// en: '$amount to go'
	String toGo({required Object amount}) => '${amount} to go';

	/// en: 'Edit goal'
	String get edit => 'Edit goal';

	/// en: 'If invested'
	String get ifInvested => 'If invested';

	/// en: 'a day'
	String get aDay => 'a day';

	/// en: '$years on, with $amount in the pot'
	String projection({required Object years, required Object amount}) => '${years} on, with ${amount} in the pot';

	/// en: '(one) {1 year} (other) {$n years}'
	String years({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '1 year',
		other: '${n} years',
	);

	/// en: 'Return'
	String get returnLabel => 'Return';

	/// en: '$percent% a year'
	String returnValue({required Object percent}) => '${percent}% a year';

	/// en: 'Left alone for'
	String get leftAloneFor => 'Left alone for';

	/// en: 'Set a target and this becomes progress towards it.'
	String get noGoalWithSavings => 'Set a target and this becomes progress towards it.';

	/// en: 'Set a target, then every month you finish up counts towards it.'
	String get noGoalEmpty => 'Set a target, then every month you finish up counts towards it.';

	/// en: 'Set a goal'
	String get setGoal => 'Set a goal';

	/// en: 'Months you finished up'
	String get monthsHeader => 'Months you finished up';

	/// en: 'Income over spending'
	String get incomeOverSpending => 'Income over spending';

	/// en: 'No month has finished up yet. A month counts once its income beats its spending.'
	String get noPositiveMonths => 'No month has finished up yet. A month counts once its income beats its spending.';

	/// en: '$months ended down, $amount in total. Those are left out of the figure above.'
	String negativeNote({required Object months, required Object amount}) => '${months} ended down, ${amount} in total. Those are left out of the figure above.';

	/// en: '(one) {1 month} (other) {$n months}'
	String negativeMonths({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '1 month',
		other: '${n} months',
	);

	/// en: 'Edit your goal'
	String get formEditTitle => 'Edit your goal';

	/// en: 'Set a goal'
	String get formCreateTitle => 'Set a goal';

	/// en: 'Every month you finish up adds to it.'
	String get formSubtitle => 'Every month you finish up adds to it.';

	/// en: 'Target'
	String get target => 'Target';

	/// en: 'Saving up $amount'
	String savingUp({required Object amount}) => 'Saving up ${amount}';

	/// en: 'Save goal'
	String get formSave => 'Save goal';

	/// en: 'Set goal'
	String get formCreate => 'Set goal';

	/// en: 'Could not save your goal'
	String get saveFailed => 'Could not save your goal';

	/// en: 'Enter an amount above zero'
	String get amountAboveZero => 'Enter an amount above zero';

	/// en: 'Enter an amount up to 1,000,000,000,000'
	String get amountTooLarge => 'Enter an amount up to 1,000,000,000,000';
}

// Path: debts
class Translations$debts$en {
	Translations$debts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Debts'
	String get title => 'Debts';

	/// en: 'Add debt'
	String get addTooltip => 'Add debt';

	/// en: 'Could not load your debts'
	String get loadFailed => 'Could not load your debts';

	/// en: 'They owe you'
	String get sectionOwedToMe => 'They owe you';

	/// en: 'You owe'
	String get sectionOwedByMe => 'You owe';

	/// en: 'Settled'
	String get sectionSettled => 'Settled';

	/// en: 'Owed to you'
	String get figureOwedToYou => 'Owed to you';

	/// en: 'Owed by you'
	String get figureOwedByYou => 'Owed by you';

	/// en: 'You are square'
	String get netSquare => 'You are square';

	/// en: 'You are owed $amount overall'
	String netOwedToYou({required Object amount}) => 'You are owed ${amount} overall';

	/// en: 'You owe $amount overall'
	String netOwedByYou({required Object amount}) => 'You owe ${amount} overall';

	/// en: 'Settled $date'
	String settledOn({required Object date}) => 'Settled ${date}';

	/// en: 'Overdue $date'
	String overdueOn({required Object date}) => 'Overdue ${date}';

	/// en: 'Due $date'
	String dueOn({required Object date}) => 'Due ${date}';

	/// en: 'Owes you'
	String get owesYou => 'Owes you';

	/// en: 'You owe them'
	String get youOweThem => 'You owe them';

	/// en: 'Actions for $name'
	String actionsFor({required Object name}) => 'Actions for ${name}';

	/// en: 'Reopen'
	String get reopen => 'Reopen';

	/// en: 'Mark settled'
	String get markSettled => 'Mark settled';

	/// en: 'Delete the debt with $name?'
	String deleteTitle({required Object name}) => 'Delete the debt with ${name}?';

	/// en: '$amount will stop being tracked. Nothing in your spending changes — a debt was never part of it.'
	String deleteBody({required Object amount}) => '${amount} will stop being tracked. Nothing in your spending changes — a debt was never part of it.';

	/// en: 'No debts yet'
	String get emptyTitle => 'No debts yet';

	/// en: 'Add what you owe and what people owe you. Debts are tracked here only — they never move your spending totals.'
	String get emptyBody => 'Add what you owe and what people owe you. Debts are tracked here only — they never move your spending totals.';

	/// en: 'Edit debt'
	String get formEditTitle => 'Edit debt';

	/// en: 'New debt'
	String get formCreateTitle => 'New debt';

	/// en: 'They owe me'
	String get directionOwedToMe => 'They owe me';

	/// en: 'I owe'
	String get directionOwedByMe => 'I owe';

	/// en: 'Who'
	String get who => 'Who';

	/// en: 'Alex'
	String get whoHint => 'Alex';

	/// en: 'What for'
	String get whatFor => 'What for';

	/// en: 'Due date'
	String get dueDate => 'Due date';

	/// en: 'Add a due date'
	String get addDueDate => 'Add a due date';

	/// en: 'Due $date'
	String due({required Object date}) => 'Due ${date}';

	/// en: 'Clear due date'
	String get clearDueDate => 'Clear due date';

	/// en: '$who owes you $amount'
	String summaryOwedToMe({required Object who, required Object amount}) => '${who} owes you ${amount}';

	/// en: 'You owe $who $amount'
	String summaryOwedByMe({required Object who, required Object amount}) => 'You owe ${who} ${amount}';

	/// en: 'they'
	String get whoFallback => 'they';

	/// en: 'Add debt'
	String get formCreate => 'Add debt';

	/// en: 'Enter who the debt is with'
	String get enterCounterparty => 'Enter who the debt is with';

	/// en: 'That name is too long'
	String get nameTooLong => 'That name is too long';

	/// en: 'Enter an amount above zero'
	String get amountAboveZero => 'Enter an amount above zero';

	/// en: 'Could not save that debt'
	String get saveFailed => 'Could not save that debt';

	/// en: 'Could not update that debt'
	String get updateFailed => 'Could not update that debt';

	/// en: 'Could not remove that debt'
	String get removeFailed => 'Could not remove that debt';
}

// Path: currencies
class Translations$currencies$en {
	Translations$currencies$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Currencies'
	String get title => 'Currencies';

	/// en: 'Rates are against $base'
	String ratesAgainst({required Object base}) => 'Rates are against ${base}';

	/// en: 'Add currency'
	String get addTooltip => 'Add currency';

	/// en: 'Could not load currencies'
	String get loadFailed => 'Could not load currencies';

	/// en: 'No currencies yet. Everything is in $base.'
	String empty({required Object base}) => 'No currencies yet. Everything is in ${base}.';

	/// en: '1 $ticker = $rate $base'
	String rateLine({required Object ticker, required Object rate, required Object base}) => '1 ${ticker} = ${rate} ${base}';

	/// en: 'Remove $ticker'
	String removeTooltip({required Object ticker}) => 'Remove ${ticker}';

	/// en: 'Remove $ticker?'
	String removeTitle({required Object ticker}) => 'Remove ${ticker}?';

	/// en: 'Amounts already recorded keep the values they were saved with.'
	String get removeBody => 'Amounts already recorded keep the values they were saved with.';

	/// en: 'Base currency'
	String get baseTitle => 'Base currency';

	/// en: 'Everything is recorded in $base'
	String baseSubtitle({required Object base}) => 'Everything is recorded in ${base}';

	/// en: 'What every amount is recorded in, and what rates are quoted against.'
	String get baseSheetSubtitle => 'What every amount is recorded in, and what rates are quoted against.';

	/// en: 'Could not load your currencies'
	String get baseLoadFailed => 'Could not load your currencies';

	/// en: 'Switch to $ticker?'
	String switchTitle({required Object ticker}) => 'Switch to ${ticker}?';

	/// en: 'Switch to $ticker'
	String switchAction({required Object ticker}) => 'Switch to ${ticker}';

	/// en: 'Amounts already recorded keep the numbers they were saved with — they will be shown in $ticker from now on.'
	String switchKept({required Object ticker}) => 'Amounts already recorded keep the numbers they were saved with — they will be shown in ${ticker} from now on.';

	/// en: 'The currencies you added are quoted against $base, so they cannot be kept: $tickers will be deleted. '
	String switchDeletes({required Object base, required Object tickers}) => 'The currencies you added are quoted against ${base}, so they cannot be kept: ${tickers} will be deleted. ';

	/// en: '$ticker leaves your added currencies as well — it is the base now, so there is no rate left for it to hold. '
	String switchAdopts({required Object ticker}) => '${ticker} leaves your added currencies as well — it is the base now, so there is no rate left for it to hold. ';

	/// en: 'Your base currency'
	String get optionYourBase => 'Your base currency';

	/// en: 'One you added'
	String get optionYouAdded => 'One you added';

	/// en: 'Edit currency'
	String get formEditTitle => 'Edit currency';

	/// en: 'New currency'
	String get formCreateTitle => 'New currency';

	/// en: 'Sign'
	String get sign => 'Sign';

	/// en: 'Ticker'
	String get ticker => 'Ticker';

	/// en: 'Exchange rate'
	String get exchangeRate => 'Exchange rate';

	/// en: 'What 1 $unit is worth in $base'
	String rateHint({required Object unit, required Object base}) => 'What 1 ${unit} is worth in ${base}';

	/// en: 'unit'
	String get unit => 'unit';

	/// en: 'Add currency'
	String get formCreate => 'Add currency';

	/// en: 'Enter a ticker'
	String get enterTicker => 'Enter a ticker';

	/// en: '$ticker is the base currency'
	String tickerIsBase({required Object ticker}) => '${ticker} is the base currency';

	/// en: 'Tickers are 2 to 10 letters or digits'
	String get tickerFormat => 'Tickers are 2 to 10 letters or digits';

	/// en: 'The exchange rate must be above zero'
	String get rateAboveZero => 'The exchange rate must be above zero';

	/// en: '$ticker is already in your list'
	String alreadyListed({required Object ticker}) => '${ticker} is already in your list';

	/// en: '$ticker is not a currency'
	String notACurrency({required Object ticker}) => '${ticker} is not a currency';

	/// en: 'Could not save that currency'
	String get saveFailed => 'Could not save that currency';

	/// en: 'Could not remove that currency'
	String get removeFailed => 'Could not remove that currency';

	/// en: 'Could not change the base currency'
	String get baseChangeFailed => 'Could not change the base currency';

	Map<String, String> get names => {
		'USD': 'US dollar',
		'EUR': 'Euro',
		'GBP': 'Pound sterling',
		'CHF': 'Swiss franc',
		'JPY': 'Japanese yen',
		'PLN': 'Polish złoty',
		'UAH': 'Ukrainian hryvnia',
		'AED': 'UAE dirham',
		'AUD': 'Australian dollar',
		'BGN': 'Bulgarian lev',
		'BRL': 'Brazilian real',
		'CAD': 'Canadian dollar',
		'CNY': 'Chinese yuan',
		'CZK': 'Czech koruna',
		'DKK': 'Danish krone',
		'GEL': 'Georgian lari',
		'HKD': 'Hong Kong dollar',
		'HUF': 'Hungarian forint',
		'ILS': 'Israeli shekel',
		'INR': 'Indian rupee',
		'KRW': 'South Korean won',
		'KZT': 'Kazakhstani tenge',
		'MXN': 'Mexican peso',
		'NOK': 'Norwegian krone',
		'NZD': 'New Zealand dollar',
		'RON': 'Romanian leu',
		'RSD': 'Serbian dinar',
		'SEK': 'Swedish krona',
		'SGD': 'Singapore dollar',
		'THB': 'Thai baht',
		'TRY': 'Turkish lira',
		'ZAR': 'South African rand',
	};
}

// Path: accounts
class Translations$accounts$en {
	Translations$accounts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Accounts'
	String get title => 'Accounts';

	/// en: 'Accounts'
	String get tooltip => 'Accounts';

	/// en: 'Up to $count accounts of your own, and one family account you and your partner both record into.'
	String subtitle({required Object count}) => 'Up to ${count} accounts of your own, and one family account you and your partner both record into.';

	/// en: 'Personal'
	String get firstAccountName => 'Personal';

	/// en: 'Another account'
	String get extraAccountName => 'Another account';

	/// en: 'Family'
	String get defaultFamilyName => 'Family';

	/// en: 'Partner'
	String get partnerFallback => 'Partner';

	/// en: 'Remove $name'
	String removeTooltip({required Object name}) => 'Remove ${name}';

	/// en: 'Remove $name?'
	String removeTitle({required Object name}) => 'Remove ${name}?';

	/// en: 'Its categories and entries stop showing anywhere in the app. Nothing is erased, but there is no way back to them from here.'
	String get removeBody => 'Its categories and entries stop showing anywhere in the app. Nothing is erased, but there is no way back to them from here.';

	/// en: 'New account'
	String get newAccount => 'New account';

	/// en: 'You have $count accounts of your own and a family account. Remove one to make another.'
	String noRoom({required Object count}) => 'You have ${count} accounts of your own and a family account. Remove one to make another.';

	/// en: 'Invite code'
	String get inviteCode => 'Invite code';

	/// en: 'Code copied'
	String get codeCopied => 'Code copied';

	/// en: 'Copy code'
	String get copyCode => 'Copy code';

	/// en: 'New code'
	String get newCode => 'New code';

	/// en: 'Anyone with this code can join and see these totals.'
	String get inviteWarning => 'Anyone with this code can join and see these totals.';

	/// en: 'New invite code?'
	String get rotateTitle => 'New invite code?';

	/// en: 'The old code stops working. Anyone who has already joined stays.'
	String get rotateBody => 'The old code stops working. Anyone who has already joined stays.';

	/// en: 'Members'
	String get members => 'Members';

	/// en: '$label (you)'
	String memberYou({required Object label}) => '${label} (you)';

	/// en: 'Created this account'
	String get memberOwner => 'Created this account';

	/// en: 'Records their own entries'
	String get memberPartner => 'Records their own entries';

	/// en: 'Leave this account'
	String get leaveAction => 'Leave this account';

	/// en: 'Leave $name?'
	String leaveTitle({required Object name}) => 'Leave ${name}?';

	/// en: 'You stop seeing these totals, and your partner stops seeing yours. The entries you have already recorded here stay in this account.'
	String get leaveBody => 'You stop seeing these totals, and your partner stops seeing yours. The entries you have already recorded here stay in this account.';

	/// en: 'Join with a code'
	String get joinLabel => 'Join with a code';

	/// en: 'ABC123'
	String get joinHint => 'ABC123';

	/// en: 'Leave the family account you are in to join another.'
	String get joinBlocked => 'Leave the family account you are in to join another.';

	/// en: 'New account'
	String get formTitle => 'New account';

	/// en: 'Just me'
	String get kindPersonal => 'Just me';

	/// en: 'Family'
	String get kindFamily => 'Family';

	/// en: 'You already have $count of your own. Remove one to make another.'
	String formPersonalLimit({required Object count}) => 'You already have ${count} of your own. Remove one to make another.';

	/// en: 'You are already in a family account. Leave it before starting another.'
	String get formFamilyLimit => 'You are already in a family account. Leave it before starting another.';

	/// en: 'Its own categories and totals, kept separate from your other accounts.'
	String get formPersonalAbout => 'Its own categories and totals, kept separate from your other accounts.';

	/// en: 'One set of categories and totals that you and your partner both record into.'
	String get formFamilyAbout => 'One set of categories and totals that you and your partner both record into.';

	/// en: 'Side business'
	String get formHintPersonal => 'Side business';

	/// en: 'Home'
	String get formHintFamily => 'Home';

	/// en: 'Nobody has joined yet'
	String get tileNobodyJoined => 'Nobody has joined yet';

	/// en: 'Only you'
	String get tileOnlyYou => 'Only you';

	/// en: 'Shared with $name'
	String tileSharedWith({required Object name}) => 'Shared with ${name}';

	/// en: 'Shared with $count others'
	String tileSharedWithOthers({required Object count}) => 'Shared with ${count} others';

	/// en: 'Could not open that account'
	String get openFailed => 'Could not open that account';

	/// en: 'Could not create that account'
	String get createFailed => 'Could not create that account';

	/// en: 'Could not create that family account'
	String get createFamilyFailed => 'Could not create that family account';

	/// en: 'Could not remove that account'
	String get removeFailed => 'Could not remove that account';

	/// en: 'Could not use that code'
	String get codeFailed => 'Could not use that code';

	/// en: 'Could not leave that account'
	String get leaveFailed => 'Could not leave that account';

	/// en: 'Could not change the code'
	String get rotateFailed => 'Could not change the code';

	/// en: 'That account is not yours to open'
	String get notYoursToOpen => 'That account is not yours to open';

	/// en: 'That account is not yours to remove'
	String get notYoursToRemove => 'That account is not yours to remove';

	/// en: 'Enter the code your partner shared with you'
	String get enterCode => 'Enter the code your partner shared with you';

	/// en: 'Your own account is not one you can leave'
	String get cannotLeaveOwn => 'Your own account is not one you can leave';

	/// en: 'Your first account has to stay'
	String get firstMustStay => 'Your first account has to stay';

	/// en: 'Leave a family account rather than removing it'
	String get leaveRatherThanRemove => 'Leave a family account rather than removing it';

	/// en: 'Only whoever created it can change the code'
	String get onlyOwnerRotates => 'Only whoever created it can change the code';

	/// en: 'You're in. It will show up here once syncing catches up.'
	String get joinedPending => 'You\'re in. It will show up here once syncing catches up.';

	/// en: 'You can have up to $count accounts of your own. Remove one to make another.'
	String personalLimitReached({required Object count}) => 'You can have up to ${count} accounts of your own. Remove one to make another.';

	/// en: 'You are already in a family account. Leave it before joining or starting another.'
	String get familyLimitReached => 'You are already in a family account. Leave it before joining or starting another.';

	/// en: 'That code could not be used'
	String get codeUnusable => 'That code could not be used';

	/// en: 'Could not reach the server. Joining a family account needs a connection.'
	String get codeOffline => 'Could not reach the server. Joining a family account needs a connection.';

	/// en: 'Sign in to share a family account with someone.'
	String get codeNeedsAccount => 'Sign in to share a family account with someone.';

	/// en: 'Could not come up with an invite code'
	String get noFreeCode => 'Could not come up with an invite code';
}

// Path: auth
class Translations$auth$en {
	Translations$auth$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Create an account'
	String get signUpTitle => 'Create an account';

	/// en: 'Welcome back'
	String get signInTitle => 'Welcome back';

	/// en: 'Your spending syncs across devices once you sign in.'
	String get blurb => 'Your spending syncs across devices once you sign in.';

	/// en: 'Email'
	String get email => 'Email';

	/// en: 'Password'
	String get password => 'Password';

	/// en: 'Show password'
	String get showPassword => 'Show password';

	/// en: 'Hide password'
	String get hidePassword => 'Hide password';

	/// en: 'Confirm your email address to finish creating your account.'
	String get confirmSnack => 'Confirm your email address to finish creating your account.';

	/// en: 'Account created. Check your inbox to confirm your email address, then sign in.'
	String get confirmNote => 'Account created. Check your inbox to confirm your email address, then sign in.';

	/// en: 'Create account'
	String get signUpAction => 'Create account';

	/// en: 'Sign in'
	String get signInAction => 'Sign in';

	/// en: 'I already have an account'
	String get toSignIn => 'I already have an account';

	/// en: 'Create an account'
	String get toSignUp => 'Create an account';

	/// en: 'Version $label ($build)'
	String version({required Object label, required Object build}) => 'Version ${label} (${build})';

	/// en: 'Enter a valid email address'
	String get invalidEmail => 'Enter a valid email address';

	/// en: 'Enter your password'
	String get enterPassword => 'Enter your password';

	/// en: 'Password must be at least $count characters'
	String passwordTooShort({required Object count}) => 'Password must be at least ${count} characters';

	/// en: 'Could not reach the server. Try again.'
	String get unreachable => 'Could not reach the server. Try again.';

	/// en: 'This build has no backend configured'
	String get noBackend => 'This build has no backend configured';
}

// Path: sync
class Translations$sync$en {
	Translations$sync$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sync status: $state'
	String semantics({required Object state}) => 'Sync status: ${state}';

	/// en: 'not syncing'
	String get stateIdle => 'not syncing';

	/// en: 'syncing'
	String get stateSyncing => 'syncing';

	/// en: 'synced'
	String get stateSynced => 'synced';

	/// en: 'failed'
	String get stateFailed => 'failed';

	/// en: 'Syncing'
	String get detailSyncing => 'Syncing';

	/// en: 'Synced'
	String get detailSynced => 'Synced';

	/// en: 'Last synced $at'
	String detailLastSynced({required Object at}) => 'Last synced ${at}';

	/// en: 'Sync failed'
	String get detailFailed => 'Sync failed';

	/// en: 'Sync failed $at'
	String detailFailedAt({required Object at}) => 'Sync failed ${at}';

	/// en: 'Not syncing'
	String get detailIdle => 'Not syncing';
}

// Path: update
class Translations$update$en {
	Translations$update$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Update required'
	String get title => 'Update required';

	/// en: 'This version of My Pnl is no longer supported. Update to keep using it.'
	String get defaultMessage => 'This version of My Pnl is no longer supported. Update to keep using it.';

	/// en: 'You have $version'
	String youHave({required Object version}) => 'You have ${version}';

	/// en: 'Needs $version'
	String needs({required Object version}) => 'Needs ${version}';

	/// en: 'Update now'
	String get action => 'Update now';

	/// en: 'Get the latest version from your app store.'
	String get noStore => 'Get the latest version from your app store.';

	/// en: 'I have updated'
	String get recheck => 'I have updated';

	/// en: 'Could not open the store'
	String get openFailed => 'Could not open the store';
}

// Path: settings
class Translations$settings$en {
	Translations$settings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Settings'
	String get title => 'Settings';

	/// en: 'Settings'
	String get tooltip => 'Settings';

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'How the app is drawn. Kept on this device.'
	String get appearanceSubtitle => 'How the app is drawn. Kept on this device.';

	/// en: 'Match the device'
	String get themeSystem => 'Match the device';

	/// en: 'Light'
	String get themeLight => 'Light';

	/// en: 'Dark'
	String get themeDark => 'Dark';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'What the app is read in. Kept on this device.'
	String get languageSubtitle => 'What the app is read in. Kept on this device.';

	/// en: 'Match the device'
	String get languageSystem => 'Match the device';
}
