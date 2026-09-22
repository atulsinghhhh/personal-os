/// ISO 4217 currencies offered in the onboarding/settings pickers. No
/// default is hardcoded — the user chooses during onboarding.
class CurrencyInfo {
  const CurrencyInfo(this.code, this.name, [this.symbol = '']);

  final String code;
  final String name;
  final String symbol;
}

const List<CurrencyInfo> supportedCurrencies = <CurrencyInfo>[
  CurrencyInfo('INR', 'Indian Rupee', '₹'),
  CurrencyInfo('USD', 'US Dollar', r'$'),
  CurrencyInfo('EUR', 'Euro', '€'),
  CurrencyInfo('GBP', 'British Pound', '£'),
  CurrencyInfo('JPY', 'Japanese Yen', '¥'),
  CurrencyInfo('KRW', 'South Korean Won', '₩'),
  CurrencyInfo('AUD', 'Australian Dollar', r'A$'),
  CurrencyInfo('CAD', 'Canadian Dollar', r'C$'),
  CurrencyInfo('SGD', 'Singapore Dollar', r'S$'),
  CurrencyInfo('AED', 'UAE Dirham', 'د.إ'),
  CurrencyInfo('CHF', 'Swiss Franc', 'Fr'),
  CurrencyInfo('CNY', 'Chinese Yuan', '¥'),
];
