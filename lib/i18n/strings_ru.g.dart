///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsRu extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsRu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ru,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <ru>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	late final TranslationsRu _root = this; // ignore: unused_field

	@override 
	TranslationsRu $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsRu(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ru common = _Translations$common$ru._(_root);
	@override late final _Translations$router$ru router = _Translations$router$ru._(_root);
	@override late final _Translations$spending$ru spending = _Translations$spending$ru._(_root);
	@override late final _Translations$income$ru income = _Translations$income$ru._(_root);
	@override late final _Translations$account$ru account = _Translations$account$ru._(_root);
	@override late final _Translations$entries$ru entries = _Translations$entries$ru._(_root);
	@override late final _Translations$amountEntry$ru amountEntry = _Translations$amountEntry$ru._(_root);
	@override late final _Translations$categoryForm$ru categoryForm = _Translations$categoryForm$ru._(_root);
	@override late final _Translations$overrun$ru overrun = _Translations$overrun$ru._(_root);
	@override late final _Translations$goal$ru goal = _Translations$goal$ru._(_root);
	@override late final _Translations$debts$ru debts = _Translations$debts$ru._(_root);
	@override late final _Translations$currencies$ru currencies = _Translations$currencies$ru._(_root);
	@override late final _Translations$accounts$ru accounts = _Translations$accounts$ru._(_root);
	@override late final _Translations$auth$ru auth = _Translations$auth$ru._(_root);
	@override late final _Translations$sync$ru sync = _Translations$sync$ru._(_root);
	@override late final _Translations$update$ru update = _Translations$update$ru._(_root);
	@override late final _Translations$settings$ru settings = _Translations$settings$ru._(_root);
}

// Path: common
class _Translations$common$ru extends Translations$common$en {
	_Translations$common$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get cancel => 'Отмена';
	@override String get delete => 'Удалить';
	@override String get remove => 'Убрать';
	@override String get save => 'Сохранить';
	@override String get create => 'Создать';
	@override String get edit => 'Изменить';
	@override String get join => 'Войти';
	@override String get leave => 'Выйти';
	@override String get add => 'Добавить';
	@override String get select => 'Выбрать';
	@override String get reset => 'Сбросить';
	@override String get name => 'Название';
	@override String get amount => 'Сумма';
	@override String get optional => 'Необязательно';
	@override String get today => 'Сегодня';
	@override String get yesterday => 'Вчера';
	@override String get listAnd => 'и';
}

// Path: router
class _Translations$router$ru extends Translations$router$en {
	_Translations$router$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String noRoute({required Object uri}) => 'Нет маршрута для ${uri}';
}

// Path: spending
class _Translations$spending$ru extends Translations$spending$en {
	_Translations$spending$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get loadFailed => 'Не удалось загрузить расходы';
	@override String get totalLabel => 'Расходы';
	@override String get allTransactions => 'Все операции';
	@override String get debts => 'Долги';
	@override String get goal => 'Цель';
	@override String get currencies => 'Валюты';
	@override String get unusualMonths => 'Необычные месяцы';
	@override String get previousMonth => 'Предыдущий месяц';
	@override String get nextMonth => 'Следующий месяц';
	@override String get selectMonth => 'Выберите месяц';
	@override String get previousYear => 'Предыдущий год';
	@override String get nextYear => 'Следующий год';
	@override String categorySettings({required Object name}) => 'Настройки категории «${name}»';
}

// Path: income
class _Translations$income$ru extends Translations$income$en {
	_Translations$income$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get loadFailed => 'Не удалось загрузить доходы';
	@override String get totalLabel => 'Всего доходов';
}

// Path: account
class _Translations$account$ru extends Translations$account$en {
	_Translations$account$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get signOut => 'Выйти';
	@override String get signOutTitle => 'Выйти из аккаунта?';
	@override String get signOutBody => 'Синхронизированные данные останутся на сервере. Всё, что ещё не загружено, будет удалено с этого устройства.';
}

// Path: entries
class _Translations$entries$ru extends Translations$entries$en {
	_Translations$entries$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get allTitle => 'Все операции';
	@override String get newestFirst => 'Сначала новые';
	@override String get loadFailed => 'Не удалось загрузить операции';
	@override String get empty => 'Пока ничего не записано';
	@override String get historyTitle => 'История';
	@override String categoryHistory({required Object name}) => 'История категории «${name}»';
	@override String get historyLoadFailed => 'Не удалось загрузить историю';
	@override String get historyEmpty => 'Здесь пока ничего не записано';
	@override String get uncategorised => 'Без категории';
	@override String get deleteTooltip => 'Удалить запись';
	@override String onlyAuthorCanChange({required Object who}) => 'Изменить может только ${who}';
	@override String get authorFallback => 'автор записи';
	@override String get deleteTitle => 'Удалить эту запись?';
	@override String deleteBodyCategory({required Object amount, required Object category}) => '${amount} перестанет учитываться в категории «${category}».';
	@override String deleteBodyTotals({required Object amount}) => '${amount} перестанет учитываться в ваших итогах.';
	@override String get deleteFailed => 'Не удалось удалить запись';
}

// Path: amountEntry
class _Translations$amountEntry$ru extends Translations$amountEntry$en {
	_Translations$amountEntry$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get saveFailed => 'Не удалось сохранить сумму';
	@override String get editSubtitle => 'Изменить сумму';
	@override String get createSubtitle => 'Добавить сумму';
	@override String changingTo({required Object amount}) => 'Новая сумма записи — ${amount}';
	@override String addingTo({required Object amount, required Object category}) => 'Добавляем ${amount} в «${category}»';
	@override String get details => 'Детали';
	@override String get description => 'Описание';
	@override String get descriptionHint => 'Необязательно. На что именно.';
	@override String get submit => 'Сохранить сумму';
}

// Path: categoryForm
class _Translations$categoryForm$ru extends Translations$categoryForm$en {
	_Translations$categoryForm$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get saveFailed => 'Не удалось сохранить категорию';
	@override String get editIncome => 'Изменить доход';
	@override String get editExpense => 'Изменить категорию';
	@override String get newIncome => 'Новый доход';
	@override String get newExpense => 'Новая категория';
	@override String get transactions => 'Операции';
	@override String get recurring => 'Регулярный';
	@override String get recurringSubtitle => 'Записывать этот доход раз в месяц';
	@override String get day => 'День';
	@override String get recurringNote => 'В месяцах короче выбранного дня используется последний день месяца. Пропущенные месяцы записываются при следующем запуске приложения.';
	@override String get color => 'Цвет';
	@override String get customColor => 'Больше цветов';
	@override String get pickColor => 'Выберите цвет';
	@override String get icon => 'Значок';
	@override String get moreIcons => 'Больше значков';
	@override String get pickIcon => 'Выберите значок';
	@override String get delete => 'Удалить категорию';
	@override String deleteTitleNamed({required Object name}) => 'Удалить «${name}»?';
	@override String get deleteTitleUnnamed => 'Удалить эту категорию?';
	@override String get deleteBody => 'Что сделать с суммами, записанными в неё?\n\nОставить — деньги останутся в ваших итогах, но без категории. Удалить — они уйдут и из итогов.';
	@override String get keepEntries => 'Оставить записи';
	@override String get deleteEntries => 'Удалить записи';
	@override String nameTaken({required Object name}) => 'У вас уже есть категория «${name}»';
}

// Path: overrun
class _Translations$overrun$ru extends Translations$overrun$en {
	_Translations$overrun$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Необычные месяцы';
	@override String description({required Object months}) => 'Категория обводится, когда этот месяц обходится дороже, чем обычно за предыдущие ${months}.';
	@override String monthsBack({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} месяц',
		few: '${n} месяца',
		many: '${n} месяцев',
		other: '${n} месяца',
	);
	@override String get toggle => 'Предупреждать о необычных месяцах';
	@override String percentOfUsual({required Object percent}) => '${percent}% от обычного';
	@override String get saveFailed => 'Не удалось сохранить настройки предупреждений';
	@override String get levelMild => 'Стоит взглянуть';
	@override String get levelHigh => 'Заметно больше';
	@override String get levelSevere => 'Намного больше';
	@override String get semanticsMild => 'Выше обычного месяца';
	@override String get semanticsHigh => 'Заметно выше обычного месяца';
	@override String get semanticsSevere => 'Намного выше обычного месяца';
}

// Path: goal
class _Translations$goal$ru extends Translations$goal$en {
	_Translations$goal$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Цель';
	@override String get removeTooltip => 'Убрать цель';
	@override String get loadFailed => 'Не удалось загрузить месяцы';
	@override String get loadGoalFailed => 'Не удалось загрузить цель';
	@override String get removeFailed => 'Не удалось убрать цель';
	@override String get removeTitle => 'Убрать цель?';
	@override String get removeBody => 'Месяцы останутся как есть — уйдёт только сама цель.';
	@override String get saved => 'Накоплено за удачные месяцы';
	@override String get savedTotal => 'Накоплено';
	@override String includesStarting({required Object starting, required Object months}) => '${starting} уже было, ${months} за удачные месяцы';
	@override String ofTarget({required Object amount}) => 'из ${amount}';
	@override String get reached => 'Цель достигнута';
	@override String toGo({required Object amount}) => 'осталось ${amount}';
	@override String get edit => 'Изменить цель';
	@override String get ifInvested => 'Если вложить';
	@override String get aDay => 'в день';
	@override String projection({required Object years, required Object amount}) => 'через ${years}, в копилке ${amount}';
	@override String years({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} год',
		few: '${n} года',
		many: '${n} лет',
		other: '${n} года',
	);
	@override String get returnLabel => 'Доходность';
	@override String returnValue({required Object percent}) => '${percent}% годовых';
	@override String get leftAloneFor => 'Не трогать';
	@override String get noGoalWithSavings => 'Задайте цель — и это станет прогрессом к ней.';
	@override String get noGoalEmpty => 'Задайте цель, и каждый месяц, закрытый в плюс, будет её приближать.';
	@override String get setGoal => 'Задать цель';
	@override String get monthsHeader => 'Месяцы, закрытые в плюс';
	@override String get incomeOverSpending => 'Доходы выше расходов';
	@override String get noPositiveMonths => 'Пока ни один месяц не закрыт в плюс. Месяц засчитывается, когда доходы превышают расходы.';
	@override String negativeNote({required Object months, required Object amount}) => '${months} закрыто в минус, всего ${amount}. Они не учтены в сумме выше.';
	@override String negativeMonths({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} месяц',
		few: '${n} месяца',
		many: '${n} месяцев',
		other: '${n} месяца',
	);
	@override String get formEditTitle => 'Изменить цель';
	@override String get formCreateTitle => 'Задать цель';
	@override String get formSubtitle => 'Каждый месяц, закрытый в плюс, её приближает.';
	@override String get target => 'Цель';
	@override String savingUp({required Object amount}) => 'Копим ${amount}';
	@override String get alreadySaved => 'Уже накоплено';
	@override String get alreadySavedHint => 'Необязательно. Сколько было отложено до этого приложения.';
	@override String startingFrom({required Object amount}) => 'Начинаем с ${amount}';
	@override String get formSave => 'Сохранить цель';
	@override String get formCreate => 'Задать цель';
	@override String get saveFailed => 'Не удалось сохранить цель';
	@override String get amountAboveZero => 'Введите сумму больше нуля';
	@override String get startingBelowZero => 'Введите сумму не меньше нуля';
	@override String get amountTooLarge => 'Введите сумму не больше 1 000 000 000 000';
}

// Path: debts
class _Translations$debts$ru extends Translations$debts$en {
	_Translations$debts$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Долги';
	@override String get addTooltip => 'Добавить долг';
	@override String get loadFailed => 'Не удалось загрузить долги';
	@override String get sectionOwedToMe => 'Вам должны';
	@override String get sectionOwedByMe => 'Вы должны';
	@override String get sectionSettled => 'Закрытые';
	@override String get figureOwedToYou => 'Вам должны';
	@override String get figureOwedByYou => 'Вы должны';
	@override String get netSquare => 'Вы в расчёте';
	@override String netOwedToYou({required Object amount}) => 'В итоге вам должны ${amount}';
	@override String netOwedByYou({required Object amount}) => 'В итоге вы должны ${amount}';
	@override String settledOn({required Object date}) => 'Закрыт ${date}';
	@override String overdueOn({required Object date}) => 'Просрочен ${date}';
	@override String dueOn({required Object date}) => 'Срок ${date}';
	@override String get owesYou => 'Должен вам';
	@override String get youOweThem => 'Вы должны';
	@override String actionsFor({required Object name}) => 'Действия: ${name}';
	@override String get reopen => 'Открыть снова';
	@override String get markSettled => 'Отметить закрытым';
	@override String deleteTitle({required Object name}) => 'Удалить долг с ${name}?';
	@override String deleteBody({required Object amount}) => '${amount} перестанет отслеживаться. На расходы это не влияет — долг никогда в них не входил.';
	@override String get emptyTitle => 'Долгов пока нет';
	@override String get emptyBody => 'Добавьте, что должны вы и что должны вам. Долги учитываются только здесь и не меняют итоги по расходам.';
	@override String get formEditTitle => 'Изменить долг';
	@override String get formCreateTitle => 'Новый долг';
	@override String get directionOwedToMe => 'Мне должны';
	@override String get directionOwedByMe => 'Я должен';
	@override String get who => 'Кто';
	@override String get whoHint => 'Алекс';
	@override String get whatFor => 'За что';
	@override String get dueDate => 'Срок';
	@override String get addDueDate => 'Добавить срок';
	@override String due({required Object date}) => 'Срок ${date}';
	@override String get clearDueDate => 'Убрать срок';
	@override String summaryOwedToMe({required Object who, required Object amount}) => '${who} должен вам ${amount}';
	@override String summaryOwedByMe({required Object who, required Object amount}) => 'Вы должны ${who} ${amount}';
	@override String get whoFallback => 'этот человек';
	@override String get formCreate => 'Добавить долг';
	@override String get enterCounterparty => 'Укажите, с кем долг';
	@override String get nameTooLong => 'Слишком длинное имя';
	@override String get amountAboveZero => 'Введите сумму больше нуля';
	@override String get saveFailed => 'Не удалось сохранить долг';
	@override String get updateFailed => 'Не удалось обновить долг';
	@override String get removeFailed => 'Не удалось удалить долг';
}

// Path: currencies
class _Translations$currencies$ru extends Translations$currencies$en {
	_Translations$currencies$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Валюты';
	@override String ratesAgainst({required Object base}) => 'Курсы указаны к ${base}';
	@override String get addTooltip => 'Добавить валюту';
	@override String get loadFailed => 'Не удалось загрузить валюты';
	@override String empty({required Object base}) => 'Валют пока нет. Всё в ${base}.';
	@override String rateLine({required Object ticker, required Object rate, required Object base}) => '1 ${ticker} = ${rate} ${base}';
	@override String removeTooltip({required Object ticker}) => 'Удалить ${ticker}';
	@override String removeTitle({required Object ticker}) => 'Удалить ${ticker}?';
	@override String get removeBody => 'Уже записанные суммы сохранят те значения, с которыми были сохранены.';
	@override String get baseTitle => 'Основная валюта';
	@override String baseSubtitle({required Object base}) => 'Всё записывается в ${base}';
	@override String get baseSheetSubtitle => 'В ней записываются все суммы, и к ней приводятся курсы.';
	@override String get baseLoadFailed => 'Не удалось загрузить ваши валюты';
	@override String switchTitle({required Object ticker}) => 'Перейти на ${ticker}?';
	@override String switchAction({required Object ticker}) => 'Перейти на ${ticker}';
	@override String switchKept({required Object ticker}) => 'Уже записанные суммы сохранят свои числа — с этого момента они будут показываться в ${ticker}.';
	@override String switchDeletes({required Object base, required Object tickers}) => 'Добавленные вами валюты указаны к ${base}, поэтому их нельзя оставить: ${tickers} будут удалены. ';
	@override String switchAdopts({required Object ticker}) => '${ticker} тоже уйдёт из добавленных валют — теперь это основная валюта, и курса у неё быть не может. ';
	@override String get optionYourBase => 'Ваша основная валюта';
	@override String get optionYouAdded => 'Добавлена вами';
	@override String get formEditTitle => 'Изменить валюту';
	@override String get formCreateTitle => 'Новая валюта';
	@override String get sign => 'Знак';
	@override String get ticker => 'Код';
	@override String get exchangeRate => 'Курс';
	@override String rateHint({required Object unit, required Object base}) => 'Сколько 1 ${unit} стоит в ${base}';
	@override String get unit => 'единица';
	@override String get formCreate => 'Добавить валюту';
	@override String get enterTicker => 'Введите код';
	@override String tickerIsBase({required Object ticker}) => '${ticker} — это основная валюта';
	@override String get tickerFormat => 'Код — от 2 до 10 букв или цифр';
	@override String get rateAboveZero => 'Курс должен быть больше нуля';
	@override String alreadyListed({required Object ticker}) => '${ticker} уже есть в вашем списке';
	@override String notACurrency({required Object ticker}) => '${ticker} — не валюта';
	@override String get saveFailed => 'Не удалось сохранить валюту';
	@override String get removeFailed => 'Не удалось удалить валюту';
	@override String get baseChangeFailed => 'Не удалось сменить основную валюту';
	@override Map<String, String> get names => {
		'USD': 'Доллар США',
		'EUR': 'Евро',
		'GBP': 'Фунт стерлингов',
		'CHF': 'Швейцарский франк',
		'JPY': 'Японская иена',
		'PLN': 'Польский злотый',
		'UAH': 'Украинская гривна',
		'AED': 'Дирхам ОАЭ',
		'AUD': 'Австралийский доллар',
		'BGN': 'Болгарский лев',
		'BRL': 'Бразильский реал',
		'CAD': 'Канадский доллар',
		'CNY': 'Китайский юань',
		'CZK': 'Чешская крона',
		'DKK': 'Датская крона',
		'GEL': 'Грузинский лари',
		'HKD': 'Гонконгский доллар',
		'HUF': 'Венгерский форинт',
		'ILS': 'Израильский шекель',
		'INR': 'Индийская рупия',
		'KRW': 'Южнокорейская вона',
		'KZT': 'Казахстанский тенге',
		'MXN': 'Мексиканское песо',
		'NOK': 'Норвежская крона',
		'NZD': 'Новозеландский доллар',
		'RON': 'Румынский лей',
		'RSD': 'Сербский динар',
		'SEK': 'Шведская крона',
		'SGD': 'Сингапурский доллар',
		'THB': 'Тайский бат',
		'TRY': 'Турецкая лира',
		'ZAR': 'Южноафриканский рэнд',
	};
}

// Path: accounts
class _Translations$accounts$ru extends Translations$accounts$en {
	_Translations$accounts$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Аккаунты';
	@override String get tooltip => 'Аккаунты';
	@override String subtitle({required Object count}) => 'До ${count} собственных аккаунтов и один семейный, в который записываете вы и ваш партнёр.';
	@override String get firstAccountName => 'Личный';
	@override String get extraAccountName => 'Другой аккаунт';
	@override String get defaultFamilyName => 'Семейный';
	@override String get partnerFallback => 'Партнёр';
	@override String removeTooltip({required Object name}) => 'Убрать «${name}»';
	@override String removeTitle({required Object name}) => 'Убрать «${name}»?';
	@override String get removeBody => 'Его категории и записи перестанут показываться в приложении. Ничего не стирается, но вернуться к ним отсюда будет нельзя.';
	@override String get newAccount => 'Новый аккаунт';
	@override String noRoom({required Object count}) => 'У вас уже ${count} собственных аккаунтов и семейный. Уберите один, чтобы создать другой.';
	@override String get inviteCode => 'Код приглашения';
	@override String get codeCopied => 'Код скопирован';
	@override String get copyCode => 'Скопировать код';
	@override String get newCode => 'Новый код';
	@override String get inviteWarning => 'Любой, у кого есть этот код, сможет войти и видеть эти итоги.';
	@override String get rotateTitle => 'Новый код приглашения?';
	@override String get rotateBody => 'Старый код перестанет работать. Те, кто уже вошёл, останутся.';
	@override String get members => 'Участники';
	@override String memberYou({required Object label}) => '${label} (вы)';
	@override String get memberOwner => 'Создал этот аккаунт';
	@override String get memberPartner => 'Ведёт свои записи';
	@override String get leaveAction => 'Выйти из аккаунта';
	@override String leaveTitle({required Object name}) => 'Выйти из «${name}»?';
	@override String get leaveBody => 'Вы перестанете видеть эти итоги, а партнёр — ваши. Записи, которые вы уже сделали здесь, останутся в этом аккаунте.';
	@override String get joinLabel => 'Войти по коду';
	@override String get joinHint => 'ABC123';
	@override String get joinBlocked => 'Выйдите из семейного аккаунта, чтобы войти в другой.';
	@override String get formTitle => 'Новый аккаунт';
	@override String get kindPersonal => 'Только я';
	@override String get kindFamily => 'Семья';
	@override String formPersonalLimit({required Object count}) => 'У вас уже ${count} собственных. Уберите один, чтобы создать другой.';
	@override String get formFamilyLimit => 'Вы уже в семейном аккаунте. Выйдите из него, прежде чем создавать другой.';
	@override String get formPersonalAbout => 'Свои категории и итоги, отдельно от остальных аккаунтов.';
	@override String get formFamilyAbout => 'Одни категории и итоги на вас и вашего партнёра.';
	@override String get formHintPersonal => 'Подработка';
	@override String get formHintFamily => 'Дом';
	@override String get tileNobodyJoined => 'Пока никто не вошёл';
	@override String get tileOnlyYou => 'Только вы';
	@override String tileSharedWith({required Object name}) => 'Вместе с ${name}';
	@override String tileSharedWithOthers({required Object count}) => 'Вместе ещё с ${count}';
	@override String get openFailed => 'Не удалось открыть аккаунт';
	@override String get createFailed => 'Не удалось создать аккаунт';
	@override String get createFamilyFailed => 'Не удалось создать семейный аккаунт';
	@override String get removeFailed => 'Не удалось убрать аккаунт';
	@override String get codeFailed => 'Не удалось использовать этот код';
	@override String get leaveFailed => 'Не удалось выйти из аккаунта';
	@override String get rotateFailed => 'Не удалось сменить код';
	@override String get notYoursToOpen => 'Этот аккаунт не ваш, открыть его нельзя';
	@override String get notYoursToRemove => 'Этот аккаунт не ваш, убрать его нельзя';
	@override String get enterCode => 'Введите код, которым поделился ваш партнёр';
	@override String get cannotLeaveOwn => 'Из собственного аккаунта выйти нельзя';
	@override String get firstMustStay => 'Первый аккаунт должен остаться';
	@override String get leaveRatherThanRemove => 'Из семейного аккаунта нужно выйти, а не убирать его';
	@override String get onlyOwnerRotates => 'Сменить код может только создатель';
	@override String get joinedPending => 'Вы вошли. Аккаунт появится здесь, когда синхронизация догонит.';
	@override String personalLimitReached({required Object count}) => 'Собственных аккаунтов может быть до ${count}. Уберите один, чтобы создать другой.';
	@override String get familyLimitReached => 'Вы уже в семейном аккаунте. Выйдите из него, прежде чем входить в другой или создавать свой.';
	@override String get codeUnusable => 'Этот код не подошёл';
	@override String get codeOffline => 'Не удалось связаться с сервером. Для входа в семейный аккаунт нужно соединение.';
	@override String get codeNeedsAccount => 'Войдите в аккаунт, чтобы поделиться семейным аккаунтом.';
	@override String get noFreeCode => 'Не удалось подобрать код приглашения';
}

// Path: auth
class _Translations$auth$ru extends Translations$auth$en {
	_Translations$auth$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get signUpTitle => 'Создание аккаунта';
	@override String get signInTitle => 'С возвращением';
	@override String get blurb => 'После входа расходы синхронизируются между устройствами.';
	@override String get email => 'Эл. почта';
	@override String get password => 'Пароль';
	@override String get showPassword => 'Показать пароль';
	@override String get hidePassword => 'Скрыть пароль';
	@override String get confirmSnack => 'Подтвердите адрес почты, чтобы завершить создание аккаунта.';
	@override String get confirmNote => 'Аккаунт создан. Проверьте почту, подтвердите адрес и войдите.';
	@override String get signUpAction => 'Создать аккаунт';
	@override String get signInAction => 'Войти';
	@override String get toSignIn => 'У меня уже есть аккаунт';
	@override String get toSignUp => 'Создать аккаунт';
	@override String version({required Object label, required Object build}) => 'Версия ${label} (${build})';
	@override String get invalidEmail => 'Введите корректный адрес почты';
	@override String get enterPassword => 'Введите пароль';
	@override String passwordTooShort({required Object count}) => 'Пароль должен быть не короче ${count} символов';
	@override String get unreachable => 'Не удалось связаться с сервером. Попробуйте ещё раз.';
	@override String get noBackend => 'В этой сборке не настроен сервер';
}

// Path: sync
class _Translations$sync$ru extends Translations$sync$en {
	_Translations$sync$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String semantics({required Object state}) => 'Синхронизация: ${state}';
	@override String get stateIdle => 'не выполняется';
	@override String get stateSyncing => 'выполняется';
	@override String get stateSynced => 'выполнена';
	@override String get stateFailed => 'не удалась';
	@override String get detailSyncing => 'Синхронизация';
	@override String get detailSynced => 'Синхронизировано';
	@override String detailLastSynced({required Object at}) => 'Синхронизировано ${at}';
	@override String get detailFailed => 'Синхронизация не удалась';
	@override String detailFailedAt({required Object at}) => 'Синхронизация не удалась ${at}';
	@override String get detailIdle => 'Синхронизация не выполняется';
}

// Path: update
class _Translations$update$ru extends Translations$update$en {
	_Translations$update$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Нужно обновление';
	@override String get defaultMessage => 'Эта версия My Pnl больше не поддерживается. Обновите приложение, чтобы продолжить им пользоваться.';
	@override String youHave({required Object version}) => 'У вас ${version}';
	@override String needs({required Object version}) => 'Нужна ${version}';
	@override String get action => 'Обновить';
	@override String get noStore => 'Скачайте свежую версию в магазине приложений.';
	@override String get recheck => 'Я обновил';
	@override String get openFailed => 'Не удалось открыть магазин';
}

// Path: settings
class _Translations$settings$ru extends Translations$settings$en {
	_Translations$settings$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Настройки';
	@override String get tooltip => 'Настройки';
	@override String get appearance => 'Оформление';
	@override String get appearanceSubtitle => 'Как выглядит приложение. Хранится на этом устройстве.';
	@override String get themeSystem => 'Как на устройстве';
	@override String get themeLight => 'Светлое';
	@override String get themeDark => 'Тёмное';
	@override String get language => 'Язык';
	@override String get languageSubtitle => 'На каком языке приложение. Хранится на этом устройстве.';
	@override String get languageSystem => 'Как на устройстве';
	@override String get spending => 'Расходы';
	@override String get spendingSubtitle => 'С чем сравниваются ваши суммы. Общее для всех, у кого открыта эта книга.';
	@override String get currenciesSubtitle => 'В каких валютах можно смотреть итоги.';
	@override String get unusualMonthsSubtitle => 'Насколько категория должна превысить обычный месяц, чтобы её отметили.';
}
