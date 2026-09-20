import 'workout_session.dart';

/// Which grouping the History screen is showing.
enum HistoryView { daily, weekly, monthly }

const _monthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// All grouping uses the phone's LOCAL time, so "Yesterday" means the user's
/// yesterday. Weeks start on Monday.
DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month);

DateTime _startOf(HistoryView view, DateTime d) {
  switch (view) {
    case HistoryView.daily:
      return _dayStart(d);
    case HistoryView.weekly:
      return _weekStart(d);
    case HistoryView.monthly:
      return _monthStart(d);
  }
}

/// Moves [start] forward ([n] > 0) or back ([n] < 0) by [n] whole periods.
DateTime _step(HistoryView view, DateTime start, int n) {
  switch (view) {
    case HistoryView.daily:
      return DateTime(start.year, start.month, start.day + n);
    case HistoryView.weekly:
      return DateTime(start.year, start.month, start.day + 7 * n);
    case HistoryView.monthly:
      return DateTime(start.year, start.month + n);
  }
}

/// How many recent periods are always listed (even when empty) and drawn in
/// the bar chart.
int windowSize(HistoryView view) {
  switch (view) {
    case HistoryView.daily:
      return 7;
    case HistoryView.weekly:
      return 4;
    case HistoryView.monthly:
      return 6;
  }
}

String windowLabel(HistoryView view) {
  switch (view) {
    case HistoryView.daily:
      return 'Last 7 days';
    case HistoryView.weekly:
      return 'Last 4 weeks';
    case HistoryView.monthly:
      return 'Last 6 months';
  }
}

/// Short label under a bar in the chart.
String chartLabel(HistoryView view, DateTime start) {
  switch (view) {
    case HistoryView.daily:
      return _weekdaysShort[start.weekday - 1];
    case HistoryView.weekly:
      return '${_monthsShort[start.month - 1]} ${start.day}';
    case HistoryView.monthly:
      return _monthsShort[start.month - 1];
  }
}

/// e.g. "Fri, Sep 18" (adds the year when it is not the current year).
String formatDayLabel(DateTime d, DateTime today) {
  final base =
      '${_weekdaysShort[d.weekday - 1]}, ${_monthsShort[d.month - 1]} ${d.day}';
  return d.year == today.year ? base : '$base, ${d.year}';
}

String _rangeLabel(DateTime start, DateTime end, DateTime today) {
  final a = '${_monthsShort[start.month - 1]} ${start.day}';
  final b = '${_monthsShort[end.month - 1]} ${end.day}';
  final range = '$a – $b';
  return start.year == today.year ? range : '$range, ${start.year}';
}

/// One day, one week or one month of workouts.
class PeriodSummary {
  const PeriodSummary({
    required this.start,
    required this.end,
    required this.sessions,
    required this.title,
    required this.isCurrent,
    this.subtitle,
  });

  /// First day of the period (inclusive).
  final DateTime start;

  /// Last day of the period (inclusive).
  final DateTime end;

  /// Sessions in this period, newest first. Empty for a rest day / week / month.
  final List<WorkoutSession> sessions;

  final String title;
  final String? subtitle;

  /// `true` for today / this week / this month.
  final bool isCurrent;

  bool get isEmpty => sessions.isEmpty;

  int get sessionCount => sessions.length;

  int get reps => sessions.fold(0, (sum, s) => sum + s.reps);

  Duration get totalDuration =>
      sessions.fold(Duration.zero, (sum, s) => sum + s.duration);

  /// Average form %, weighted by reps (a 50-rep session counts more than a
  /// 5-rep one).
  double get avgForm {
    final total = reps;
    if (total == 0) return 0;
    final weighted =
    sessions.fold<double>(0, (sum, s) => sum + s.formAccuracy * s.reps);
    return weighted / total;
  }
}

/// Totals for one calendar day (used inside week / month cards).
class DayTotal {
  const DayTotal({
    required this.day,
    required this.reps,
    required this.sessions,
  });

  final DateTime day;
  final int reps;
  final int sessions;
}

List<DayTotal> dayTotals(List<WorkoutSession> sessions) {
  final byDay = <DateTime, List<WorkoutSession>>{};
  for (final s in sessions) {
    byDay.putIfAbsent(_dayStart(s.completedAt), () => <WorkoutSession>[]).add(s);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      DayTotal(
        day: d,
        reps: byDay[d]!.fold(0, (sum, s) => sum + s.reps),
        sessions: byDay[d]!.length,
      ),
  ];
}

/// Groups [sessions] into periods, newest first.
///
/// The most recent [windowSize] periods are always included, even when empty
/// (so you can see rest days). Older periods appear only if they have workouts.
List<PeriodSummary> buildPeriods(
    List<WorkoutSession> sessions,
    HistoryView view, {
      DateTime? now,
    }) {
  final today = _dayStart(now ?? DateTime.now());
  final currentStart = _startOf(view, today);

  final groups = <DateTime, List<WorkoutSession>>{};
  for (final s in sessions) {
    groups
        .putIfAbsent(_startOf(view, s.completedAt), () => <WorkoutSession>[])
        .add(s);
  }
  for (var i = 0; i < windowSize(view); i++) {
    groups.putIfAbsent(_step(view, currentStart, -i), () => <WorkoutSession>[]);
  }

  final starts = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final start in starts)
      _summary(
        view,
        start,
        (groups[start]!..sort((a, b) => b.completedAt.compareTo(a.completedAt))),
        today,
        currentStart,
      ),
  ];
}

PeriodSummary _summary(
    HistoryView view,
    DateTime start,
    List<WorkoutSession> sessions,
    DateTime today,
    DateTime currentStart,
    ) {
  final next = _step(view, start, 1);
  final end = DateTime(next.year, next.month, next.day - 1);
  final isCurrent = start == currentStart;
  final isPrevious = start == _step(view, currentStart, -1);

  late final String title;
  String? subtitle;

  switch (view) {
    case HistoryView.daily:
      final label = formatDayLabel(start, today);
      title = isCurrent
          ? 'Today'
          : isPrevious
          ? 'Yesterday'
          : label;
      subtitle = (isCurrent || isPrevious) ? label : null;
    case HistoryView.weekly:
      final range = _rangeLabel(start, end, today);
      title = isCurrent
          ? 'This week'
          : isPrevious
          ? 'Last week'
          : range;
      subtitle = (isCurrent || isPrevious) ? range : null;
    case HistoryView.monthly:
      title = '${_monthsFull[start.month - 1]} ${start.year}';
      subtitle = isCurrent ? 'This month' : null;
  }

  return PeriodSummary(
    start: start,
    end: end,
    sessions: sessions,
    title: title,
    subtitle: subtitle,
    isCurrent: isCurrent,
  );
}