import 'package:my_pnl/app/app.dart';
import 'package:my_pnl/bootstrap.dart';
import 'package:my_pnl/dependencies.dart';

Future<void> main() async {
  await bootstrap(() async {
    final dependencies = await initializeDependencies();
    return App(
      database: dependencies.database,
      appUpdateRepository: dependencies.appUpdateRepository,
      authRepository: dependencies.authRepository,
      baseCurrencyStore: dependencies.baseCurrencyStore,
      categoryRepository: dependencies.categoryRepository,
      currencyRepository: dependencies.currencyRepository,
      displayCurrencyStore: dependencies.displayCurrencyStore,
      debtRepository: dependencies.debtRepository,
      goalRepository: dependencies.goalRepository,
      overrunSettingsStore: dependencies.overrunSettingsStore,
      transactionRepository: dependencies.transactionRepository,
      syncRepository: dependencies.syncRepository,
    );
  });
}
