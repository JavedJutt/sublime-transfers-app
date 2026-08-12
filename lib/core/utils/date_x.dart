import 'package:intl/intl.dart';

/// Date helpers for the calendar. Everything renders in the single operating
/// timezone (Europe/London per config); [DateTime]s are stored UTC and
/// localised at the model boundary, so these operate on local time.
extension DateX on DateTime {
  DateTime get dayStart => DateTime(year, month, day);
  DateTime get dayEnd => DateTime(year, month, day, 23, 59, 59, 999);

  DateTime addDays(int n) => DateTime(year, month, day + n, hour, minute);

  /// Monday as the first day of the week (UK convention).
  DateTime get weekStart => dayStart.addDays(-(weekday - DateTime.monday));
  DateTime get weekEnd => weekStart.addDays(6).dayEnd;

  DateTime get monthStart => DateTime(year, month, 1);
  DateTime get monthEnd => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());
  bool get isTomorrow => isSameDay(DateTime.now().addDays(1));
  bool get isYesterday => isSameDay(DateTime.now().addDays(-1));

  /// The date portion as a stable map key for bucketing rides by day.
  String get dayKey => DateFormat('yyyy-MM-dd').format(this);
}

/// A half-open [start, end) range, the shape the calendar hands to queries.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// ISO strings for a PostgREST `gte`/`lt` filter, in UTC.
  String get startIso => start.toUtc().toIso8601String();
  String get endIso => end.toUtc().toIso8601String();
}

/// Named date/time formatters, defined once so every screen renders time
/// identically. Time is 24-hour throughout — transfer bookings are quoted that
/// way and a 12-hour clock invites AM/PM airport mistakes.
abstract final class Dates {
  static final time = DateFormat('HH:mm');
  static final dayName = DateFormat('EEE');
  static final dayNum = DateFormat('d');
  static final monthShort = DateFormat('MMM');
  static final weekday = DateFormat('EEEE');
  static final dayMonth = DateFormat('d MMM');
  static final dayMonthYear = DateFormat('d MMM yyyy');
  static final fullDate = DateFormat('EEEE d MMMM yyyy');
  static final dateTime = DateFormat('EEE d MMM, HH:mm');
  static final monthYear = DateFormat('MMMM yyyy');

  /// "Today", "Tomorrow", "Yesterday", else "Thu 12 Mar".
  static String relativeDay(DateTime d) {
    if (d.isToday) return 'Today';
    if (d.isTomorrow) return 'Tomorrow';
    if (d.isYesterday) return 'Yesterday';
    return DateFormat('EEE d MMM').format(d);
  }

  /// A compact "in 20 min" / "in 3h" / "2h ago" for pickup countdowns.
  static String relativeTime(DateTime target, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final diff = target.difference(now);
    final mins = diff.inMinutes;
    if (mins.abs() < 1) return 'now';
    final past = mins < 0;
    final a = mins.abs();
    final label = a < 60
        ? '$a min'
        : a < 1440
            ? '${(a / 60).round()}h'
            : '${(a / 1440).round()}d';
    return past ? '$label ago' : 'in $label';
  }
}

/// Money formatting for fares.
abstract final class Money {
  static String format(num? amount, {String currency = 'GBP'}) {
    if (amount == null) return '—';
    final symbol = switch (currency) {
      'GBP' => '£',
      'EUR' => '€',
      'USD' => r'$',
      _ => '$currency ',
    };
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(amount);
  }
}
