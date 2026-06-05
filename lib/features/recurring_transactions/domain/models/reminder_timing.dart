/// When to send a reminder notification relative to the execution date.
enum ReminderTiming {
  /// Send reminder 1 day before at 09:00 local time.
  dayBefore,

  /// Send reminder on the same day at 08:00 local time.
  sameDay;

  /// Parse from stored string value.
  static ReminderTiming fromString(String value) => switch (value) {
    'day_before' => ReminderTiming.dayBefore,
    'same_day' => ReminderTiming.sameDay,
    _ => ReminderTiming.sameDay,
  };

  /// Convert to string for database storage.
  String toStorageString() => switch (this) {
    ReminderTiming.dayBefore => 'day_before',
    ReminderTiming.sameDay => 'same_day',
  };
}
