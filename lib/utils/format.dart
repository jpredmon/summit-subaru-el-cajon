import 'package:intl/intl.dart';

/// Formats a price as whole-dollar US currency, e.g. `$20,000` — matches the
/// web app's `price.toLocaleString('en-US', { style: 'currency', currency:
/// 'USD', maximumFractionDigits: 0 })`.
String formatPrice(double price) {
  return NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 0).format(price);
}

/// Formats mileage with thousands separators and an "mi" suffix, e.g.
/// `45,231 mi` — matches the web app's `${mileage.toLocaleString('en-US')} mi`.
String formatMileage(int mileage) {
  return '${NumberFormat.decimalPattern('en_US').format(mileage)} mi';
}
