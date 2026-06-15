import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static String formatDate(DateTime dt) =>
      DateFormat('EEE, d MMM yyyy').format(dt);

  static String formatTime(DateTime dt) =>
      DateFormat('h:mm a').format(dt);

  static String formatDateTime(DateTime dt) =>
      DateFormat('EEE, d MMM • h:mm a').format(dt);

  static String formatCurrency(double amount) =>
      'RM ${NumberFormat('#,##0.00').format(amount)}';

  static String formatXp(int xp) =>
      '${NumberFormat('#,###').format(xp)} XP';
}
