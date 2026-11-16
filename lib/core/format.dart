import 'config.dart';

/// Number with thousands separators, no decimals unless needed: 1250000 -> 1,250,000.
String formatNumber(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final whole = number.truncateToDouble() == number;
  final fixed = number.abs().toStringAsFixed(whole ? 0 : 2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = number < 0 ? '-' : '';
  return parts.length > 1 ? '$sign$buffer.${parts[1]}' : '$sign$buffer';
}

/// Money in the app currency: UGX 1,250,000.
String money(dynamic value) => '${AppConfig.currency} ${formatNumber(value)}';

/// Short money for tight spaces: UGX 1.25M, UGX 820K.
String compactMoney(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final abs = number.abs();
  String text;
  if (abs >= 1e9) {
    text = '${_trim(number / 1e9)}B';
  } else if (abs >= 1e6) {
    text = '${_trim(number / 1e6)}M';
  } else if (abs >= 1e4) {
    text = '${_trim(number / 1e3)}K';
  } else {
    text = formatNumber(number);
  }
  return '${AppConfig.currency} $text';
}

String _trim(double value) {
  final text = value.toStringAsFixed(value.abs() >= 100 ? 0 : 2);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 15 Nov 2026 (and 14:05 when [withTime]); empty for missing or unreadable dates.
String formatDate(dynamic value, {bool withTime = false}) {
  if (value == null || '$value'.isEmpty) return '';
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '$value';
  final day = '${date.day} ${_months[date.month - 1]} ${date.year}';
  if (!withTime) return day;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$day, $hh:$mm';
}

/// A readable date range: "16 Nov 2026", "1 Nov – 16 Nov 2026" or
/// "20 Dec 2025 – 5 Jan 2026" (the year is shown once when both share it).
String formatDateRange(DateTime start, DateTime end) {
  String day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return '${day(start)} ${start.year}';
  }
  if (start.year == end.year) return '${day(start)} – ${day(end)} ${end.year}';
  return '${day(start)} ${start.year} – ${day(end)} ${end.year}';
}

/// yyyy-mm-dd for API query strings.
String isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// snake_case or kebab-case -> Title Case.
String titleCase(String? value) {
  if (value == null || value.isEmpty) return '';
  return value
      .replaceAll(RegExp(r'[_-]'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

double toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
