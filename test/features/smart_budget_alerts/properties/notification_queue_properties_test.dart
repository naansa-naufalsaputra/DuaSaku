import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Notification Queue Batch Decision Logic
// ---------------------------------------------------------------------------

/// Represents the result of processing a notification queue after quiet hours.
enum NotificationDeliveryType {
  /// No notifications to send (queue is empty).
  none,

  /// Send individual notifications (queue size ≤ 3).
  individual,

  /// Send a single summary notification (queue size > 3).
  summary,
}

/// Result of the batch decision: how many notifications to actually send.
class NotificationBatchResult {
  final NotificationDeliveryType type;

  /// Number of notifications that will actually be sent.
  /// - 0 for [NotificationDeliveryType.none]
  /// - queue.size for [NotificationDeliveryType.individual]
  /// - 1 for [NotificationDeliveryType.summary]
  final int notificationCount;

  const NotificationBatchResult({
    required this.type,
    required this.notificationCount,
  });
}

/// Pure decision function for notification queue batch logic.
///
/// This encapsulates the rule from Requirement 5.2:
/// - If queue size > 3: exactly one summary notification SHALL be sent
/// - If queue size ≤ 3 and > 0: exactly queue.size individual notifications
/// - If queue size == 0: no notifications sent
NotificationBatchResult determineNotificationBatch(int queueSize) {
  assert(queueSize >= 0, 'Queue size cannot be negative');

  if (queueSize == 0) {
    return const NotificationBatchResult(
      type: NotificationDeliveryType.none,
      notificationCount: 0,
    );
  }

  if (queueSize > 3) {
    return const NotificationBatchResult(
      type: NotificationDeliveryType.summary,
      notificationCount: 1,
    );
  }

  // queueSize is 1, 2, or 3
  return NotificationBatchResult(
    type: NotificationDeliveryType.individual,
    notificationCount: queueSize,
  );
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // Feature: smart-budget-alerts, Property 12: Notification queue batch logic
  // **Validates: Requirements 5.2**
  group('Property 12: Notification queue batch logic', () {
    // Test with queue sizes > 3: exactly one summary notification
    Glados(any.intInRange(4, 20)).test(
      'queue size > 3 produces exactly one summary notification',
      (queueSize) {
        final result = determineNotificationBatch(queueSize);

        expect(result.type, equals(NotificationDeliveryType.summary));
        expect(result.notificationCount, equals(1));
      },
    );

    // Test with queue sizes 1 to 3: exactly queue.size individual notifications
    Glados(any.intInRange(1, 3)).test(
      'queue size <= 3 and > 0 produces exactly queue.size individual notifications',
      (queueSize) {
        final result = determineNotificationBatch(queueSize);

        expect(result.type, equals(NotificationDeliveryType.individual));
        expect(result.notificationCount, equals(queueSize));
      },
    );

    // Test with queue size == 0: no notifications sent
    test('queue size == 0 produces no notifications', () {
      final result = determineNotificationBatch(0);

      expect(result.type, equals(NotificationDeliveryType.none));
      expect(result.notificationCount, equals(0));
    });

    // Combined property: for any queue size 1-20, notification count is always
    // correct relative to the batch rule
    Glados(any.intInRange(1, 20)).test(
      'notification count follows batch rule for all queue sizes',
      (queueSize) {
        final result = determineNotificationBatch(queueSize);

        if (queueSize > 3) {
          // Summary: exactly 1 notification sent
          expect(result.notificationCount, equals(1));
          expect(result.type, equals(NotificationDeliveryType.summary));
        } else {
          // Individual: exactly queueSize notifications sent
          expect(result.notificationCount, equals(queueSize));
          expect(result.type, equals(NotificationDeliveryType.individual));
        }
      },
    );

    // Property: summary notification count is always strictly less than
    // the original queue size (compression property)
    Glados(any.intInRange(4, 20)).test(
      'summary notification count is always less than queue size (compression)',
      (queueSize) {
        final result = determineNotificationBatch(queueSize);

        expect(result.notificationCount, lessThan(queueSize));
      },
    );
  });
}
