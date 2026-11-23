import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/notifications/notification_service.dart';

void main() {
  test('month-end reminders include short months and preserve 6 PM local time', () {
    final dates = NotificationService.monthEndReminderDates(DateTime(2026, 1, 31, 19));
    expect(dates, hasLength(12));
    expect(dates.take(3), [
      DateTime(2026, 2, 28, 18),
      DateTime(2026, 3, 31, 18),
      DateTime(2026, 4, 30, 18),
    ]);
    expect(dates.last, DateTime(2027, 1, 31, 18));
    expect(
      NotificationService.monthEndReminderDates(DateTime(2028, 2, 1)).first,
      DateTime(2028, 2, 29, 18),
    );
  });
}
