/// ISO 4217 currencies offered in the onboarding/settings pickers. No
/// default is hardcoded — the user chooses during onboarding.
class CurrencyInfo {
  const CurrencyInfo(this.code, this.name);

  final String code;
  final String name;
}

const List<CurrencyInfo> supportedCurrencies = <CurrencyInfo>[
  CurrencyInfo('INR', 'Indian Rupee'),
  CurrencyInfo('USD', 'US Dollar'),
  CurrencyInfo('EUR', 'Euro'),
  CurrencyInfo('GBP', 'British Pound'),
  CurrencyInfo('JPY', 'Japanese Yen'),
  CurrencyInfo('KRW', 'South Korean Won'),
  CurrencyInfo('AUD', 'Australian Dollar'),
  CurrencyInfo('CAD', 'Canadian Dollar'),
  CurrencyInfo('SGD', 'Singapore Dollar'),
  CurrencyInfo('AED', 'UAE Dirham'),
  CurrencyInfo('CHF', 'Swiss Franc'),
  CurrencyInfo('CNY', 'Chinese Yuan'),
];
