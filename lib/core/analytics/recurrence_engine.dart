import 'dart:math' as math;

import '../../models/transaction.dart';

class RecurrenceEngine {
  /// Adjusts a date to avoid weekends and key holidays (New Year's and Christmas)
  static DateTime adjustForWeekendsAndHolidays(DateTime date) {
    DateTime adjusted = date;
    if (adjusted.weekday == DateTime.saturday) {
      adjusted = _calendarDay(adjusted, -1);
    } else if (adjusted.weekday == DateTime.sunday) {
      adjusted = _calendarDay(adjusted, 1);
    }
    
    if (adjusted.month == 1 && adjusted.day == 1) {
      adjusted = _calendarDay(adjusted, 1);
    } else if (adjusted.month == 12 && adjusted.day == 25) {
      adjusted = _calendarDay(adjusted, -1);
    }
    
    if (adjusted.weekday == DateTime.saturday) {
      adjusted = _calendarDay(adjusted, -1);
    } else if (adjusted.weekday == DateTime.sunday) {
      adjusted = _calendarDay(adjusted, 1);
    }
    
    return adjusted;
  }

  static DateTime _calendarDay(DateTime date, int offset) =>
      DateTime(date.year, date.month, date.day + offset);

  static DateTime _anchoredMonth(DateTime anchor, int months) {
    final last = DateTime(anchor.year, anchor.month + months + 1, 0);
    return DateTime(last.year, last.month, math.min(anchor.day, last.day));
  }

  /// One entry per adjusted ledger date, anchored to the original calendar day.
  static Iterable<DateTime> datesThrough(Transaction template, DateTime through) sync* {
    final anchor = _calendarDay(template.date, 0);
    final limit = _calendarDay(through, 0);
    final end = template.recurrenceEndDate;
    final lastDate = end != null && _calendarDay(end, 0).isBefore(limit)
        ? _calendarDay(end, 0)
        : limit;
    final seen = <DateTime>{};
    for (int occurrence = 1; ; occurrence++) {
      final scheduled = switch (template.recurrence) {
        'daily' => _calendarDay(anchor, occurrence),
        'weekly' => _calendarDay(anchor, occurrence * 7),
        'monthly' => _anchoredMonth(anchor, occurrence),
        'yearly' => _anchoredMonth(anchor, occurrence * 12),
        _ => null,
      };
      // A weekend or holiday can move an occurrence back by up to two days.
      if (scheduled == null || scheduled.isAfter(_calendarDay(lastDate, 2))) break;
      final adjusted = adjustForWeekendsAndHolidays(scheduled);
      if (adjusted.isAfter(anchor) && !adjusted.isAfter(lastDate) && seen.add(adjusted)) {
        yield adjusted;
      }
    }
  }

  static List<Transaction> projectFutureInstances(
    List<Transaction> baseTxs, {
    DateTime? now,
  }) {
    final today = _calendarDay(now ?? DateTime.now(), 0);
    final limit = _anchoredMonth(today, 12);
    final projected = [...baseTxs];
    var virtualId = -1;

    for (final template in baseTxs) {
      if (template.parentId != null) continue;
      for (final date in datesThrough(template, limit)) {
        if (!date.isAfter(today)) continue;
        projected.add(template.copyWith(
          id: virtualId--,
          title: '${template.title} (Projected)',
          date: date,
          recurrence: 'none',
          recurrenceEndDate: null,
        ));
      }
    }

    projected.sort((a, b) => b.date.compareTo(a.date));
    return projected;
  }
}
