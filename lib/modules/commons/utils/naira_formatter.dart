import 'package:intl/intl.dart';

class NairaFormatter {
  NairaFormatter._();

  static final NumberFormat _f = NumberFormat.decimalPattern('en_NG');

  static String format(num value) => '₦${_f.format(value)}';

  /// Comma-grouped digits WITHOUT the ₦ sign — for displays that style
  /// the currency symbol separately (e.g. the bid composer's hero price).
  static String group(num value) => _f.format(value);

  static String formatCompact(num value) {
    if (value >= 1000000) {
      return '₦${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '₦${(value / 1000).toStringAsFixed(1)}k';
    }
    return format(value);
  }
}
