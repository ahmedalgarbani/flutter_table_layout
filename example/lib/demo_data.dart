/// Mock models and datasets used by the showcase app.
library;

class AccountTransaction {
  final int id;
  final DateTime date;
  final double amount;
  final String currency;
  final double baseEquivalent;
  final String details;
  final bool isDeposit;

  const AccountTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    required this.baseEquivalent,
    required this.details,
    required this.isDeposit,
  });
}

class Currency {
  final int id;
  final String name;
  final String code;
  final String symbol;
  final String subunit;
  final double rate;
  final double minRate;
  final double maxRate;
  final bool isActive;

  const Currency({
    required this.id,
    required this.name,
    required this.code,
    required this.symbol,
    required this.subunit,
    required this.rate,
    required this.minRate,
    required this.maxRate,
    required this.isActive,
  });

  Currency copyWith({bool? isActive}) => Currency(
    id: id,
    name: name,
    code: code,
    symbol: symbol,
    subunit: subunit,
    rate: rate,
    minRate: minRate,
    maxRate: maxRate,
    isActive: isActive ?? this.isActive,
  );
}

const _rates = {'YER': 1.0, 'SAR': 250.0, 'USD': 930.0};

List<AccountTransaction> generateTransactions({required bool arabic}) {
  const detailsAr = [
    'مقابل خدمات استشارية',
    'دفعة مقدمة لمشروع التطوير',
    'رسوم اشتراك شهري',
    'سند صرف من فاتورة مشتريات رقم 4',
    'مقابل فاتورة مشتريات',
    'دفعة سداد حساب العميل',
    'إيداع نقدي مباشر',
    'تحويل بنكي وارد',
    'صيانة أجهزة المكتب',
    'مصاريف شحن',
    'عمولة مبيعات',
    'استرداد مبلغ',
  ];
  const detailsEn = [
    'Consulting services',
    'Development project advance',
    'Monthly subscription fee',
    'Payment for purchase invoice #4',
    'Purchase invoice settlement',
    'Customer account repayment',
    'Direct cash deposit',
    'Incoming bank transfer',
    'Office equipment maintenance',
    'Shipping expenses',
    'Sales commission',
    'Refund',
  ];
  const amounts = [
    5300.0, 4580.0, 120.0, 22000.0, 22000.0, 15000.0, //
    30000.0, 850.0, 3200.0, 740.0, 1250.0, 90.0,
  ];
  const currencies = [
    'YER', 'USD', 'SAR', 'YER', 'YER', 'SAR', //
    'YER', 'USD', 'YER', 'SAR', 'USD', 'YER',
  ];
  const deposits = [
    true, true, false, false, true, false, //
    true, true, false, false, true, true,
  ];
  return [
    for (var i = 0; i < 24; i++)
      AccountTransaction(
        id: i + 1,
        date: DateTime(2026, 4, 2).add(Duration(days: i * 2)),
        amount: amounts[i % 12] * (1 + (i ~/ 12) * 0.5),
        currency: currencies[i % 12],
        baseEquivalent:
            amounts[i % 12] *
            (1 + (i ~/ 12) * 0.5) *
            _rates[currencies[i % 12]]!,
        details: (arabic ? detailsAr : detailsEn)[i % 12],
        isDeposit: deposits[i % 12],
      ),
  ];
}

double rateOf(String currency) => _rates[currency] ?? 1.0;

List<Currency> generateCurrencies({required bool arabic}) {
  return [
    Currency(
      id: 1,
      name: arabic ? 'ريال يمني' : 'Yemeni Rial',
      code: 'YER',
      symbol: arabic ? 'ر.ي' : 'YR',
      subunit: arabic ? 'فلس' : 'Fils',
      rate: 1.0,
      minRate: 1.0,
      maxRate: 1.0,
      isActive: true,
    ),
    Currency(
      id: 2,
      name: arabic ? 'ريال سعودي' : 'Saudi Riyal',
      code: 'SAR',
      symbol: arabic ? 'ر.س' : 'SR',
      subunit: arabic ? 'هللة' : 'Halala',
      rate: 250.0,
      minRate: 248.0,
      maxRate: 252.0,
      isActive: true,
    ),
    Currency(
      id: 3,
      name: arabic ? 'دولار أمريكي' : 'US Dollar',
      code: 'USD',
      symbol: r'$',
      subunit: arabic ? 'سنت' : 'Cent',
      rate: 930.0,
      minRate: 928.0,
      maxRate: 935.0,
      isActive: true,
    ),
    Currency(
      id: 4,
      name: arabic ? 'يورو' : 'Euro',
      code: 'EUR',
      symbol: '€',
      subunit: arabic ? 'سنت' : 'Cent',
      rate: 1010.0,
      minRate: 1000.0,
      maxRate: 1020.0,
      isActive: false,
    ),
    Currency(
      id: 5,
      name: arabic ? 'درهم إماراتي' : 'UAE Dirham',
      code: 'AED',
      symbol: arabic ? 'د.إ' : 'AED',
      subunit: arabic ? 'فلس' : 'Fils',
      rate: 253.0,
      minRate: 251.0,
      maxRate: 255.0,
      isActive: true,
    ),
  ];
}
