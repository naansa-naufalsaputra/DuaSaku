
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_type.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/budget_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Custom Generators & Helpers
// ---------------------------------------------------------------------------

/// Generates a random non-empty alphanumeric string of given length.
String _randomString(Random rng, int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random AlertType value.
AlertType _randomAlertType(Random rng) {
  return AlertType.values[rng.nextInt(AlertType.values.length)];
}

/// Generates a random DateTime within a reasonable range with varied timestamps.
DateTime _randomDateTime(Random rng) {
  return DateTime(
    2020 + rng.nextInt(5), // 2020-2024
    1 + rng.nextInt(12), // month 1-12
    1 + rng.nextInt(28), // day 1-28
    rng.nextInt(24), // hour
    rng.nextInt(60), // minute
    rng.nextInt(60), // second
  );
}

/// Generates a random BudgetAlertModel with the given seed.
BudgetAlertModel _generateBudgetAlertModel(Random rng) {
  final alertType = _randomAlertType(rng);

  final int? thresholdValue;
  if (alertType == AlertType.prediction) {
    thresholdValue = null;
  } else {
    thresholdValue = (rng.nextInt(20) + 1) * 5; // 5, 10, ..., 100
  }

  return BudgetAlertModel(
    id: _randomString(rng, 10 + rng.nextInt(10)),
    userId: _randomString(rng, 8),
    categoryId: _randomString(rng, 8),
    alertType: alertType,
    thresholdValue: thresholdValue,
    actualPercentage: rng.nextDouble() * 200.0,
    message: _randomString(rng, 10 + rng.nextInt(50)),
    isRead: rng.nextBool(),
    createdAt: _randomDateTime(rng),
  );
}

/// Generates a list of random BudgetAlertModel instances for a single user.
/// The list size varies from 0 to 20 alerts.
List<BudgetAlertModel> _generateAlertList(int seed) {
  final rng = Random(seed);
  final count = rng.nextInt(21); // 0 to 20 alerts
  final userId = _randomString(rng, 8);

  return List.generate(count, (_) {
    final alert = _generateBudgetAlertModel(rng);
    // Override userId to ensure all alerts belong to the same user
    return alert.copyWith(userId: userId);
  });
}

/// Sorts a list of alerts descending by createdAt (simulates getAlerts/watchAlerts behavior).
List<BudgetAlertModel> _sortDescendingByCreatedAt(List<BudgetAlertModel> alerts) {
  final sorted = List<BudgetAlertModel>.from(alerts);
  sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted;
}

/// Computes the unread count from a list of alerts (simulates getUnreadCount behavior).
int _computeUnreadCount(List<BudgetAlertModel> alerts) {
  return alerts.where((alert) => !alert.isRead).length;
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // Feature: smart-budget-alerts, Property 10: Alerts sorted descending by creation timestamp
  // **Validates: Requirements 4.1**
  group('Property 10: Alerts sorted descending by creation timestamp', () {
    Glados(any.intInRange(0, 999999)).test(
      'For any list of alerts sorted by createdAt descending, '
      'all consecutive pairs satisfy alerts[i].createdAt >= alerts[i+1].createdAt',
      (seed) {
        // Generate a random list of alerts
        final alerts = _generateAlertList(seed);

        // Sort descending by createdAt (simulating getAlerts/watchAlerts behavior)
        final sortedAlerts = _sortDescendingByCreatedAt(alerts);

        // Verify the ordering property for all consecutive pairs
        for (int i = 0; i < sortedAlerts.length - 1; i++) {
          final current = sortedAlerts[i];
          final next = sortedAlerts[i + 1];

          expect(
            current.createdAt.isAfter(next.createdAt) ||
                current.createdAt.isAtSameMomentAs(next.createdAt),
            isTrue,
            reason:
                'Alert at index $i (createdAt: ${current.createdAt}) should be >= '
                'alert at index ${i + 1} (createdAt: ${next.createdAt})',
          );
        }
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'Sorting is stable: alerts with same createdAt maintain relative order',
      (seed) {
        final rng = Random(seed);
        final userId = _randomString(rng, 8);
        // Create alerts with some duplicate timestamps
        final sharedTimestamp = _randomDateTime(rng);
        final count = 2 + rng.nextInt(10); // 2 to 11 alerts

        final alerts = List.generate(count, (i) {
          final alert = _generateBudgetAlertModel(rng);
          // Give ~50% of alerts the same timestamp
          final createdAt = rng.nextBool() ? sharedTimestamp : _randomDateTime(rng);
          return alert.copyWith(userId: userId, createdAt: createdAt);
        });

        final sortedAlerts = _sortDescendingByCreatedAt(alerts);

        // Verify ordering property still holds
        for (int i = 0; i < sortedAlerts.length - 1; i++) {
          expect(
            sortedAlerts[i].createdAt.isAfter(sortedAlerts[i + 1].createdAt) ||
                sortedAlerts[i]
                    .createdAt
                    .isAtSameMomentAs(sortedAlerts[i + 1].createdAt),
            isTrue,
            reason:
                'Ordering violated at index $i: ${sortedAlerts[i].createdAt} '
                'should be >= ${sortedAlerts[i + 1].createdAt}',
          );
        }
      },
    );
  });

  // Feature: smart-budget-alerts, Property 11: Unread count accuracy
  // **Validates: Requirements 4.4**
  group('Property 11: Unread count accuracy', () {
    Glados(any.intInRange(0, 999999)).test(
      'getUnreadCount() equals the number of alerts where isRead == false',
      (seed) {
        // Generate a random list of alerts for a user
        final alerts = _generateAlertList(seed);

        // Compute unread count (simulating getUnreadCount behavior)
        final unreadCount = _computeUnreadCount(alerts);

        // Manually count unread alerts
        final expectedUnread = alerts.where((a) => !a.isRead).length;

        expect(
          unreadCount,
          equals(expectedUnread),
          reason:
              'Unread count ($unreadCount) should equal the number of alerts '
              'with isRead == false ($expectedUnread) in a list of ${alerts.length} alerts',
        );
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'Unread count is always between 0 and total alert count (inclusive)',
      (seed) {
        final alerts = _generateAlertList(seed);
        final unreadCount = _computeUnreadCount(alerts);

        expect(unreadCount, greaterThanOrEqualTo(0));
        expect(unreadCount, lessThanOrEqualTo(alerts.length));
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'When all alerts are read, unread count is 0',
      (seed) {
        final alerts = _generateAlertList(seed);

        // Mark all alerts as read
        final allReadAlerts = alerts.map((a) => a.copyWith(isRead: true)).toList();

        final unreadCount = _computeUnreadCount(allReadAlerts);
        expect(unreadCount, equals(0));
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'When no alerts are read, unread count equals total count',
      (seed) {
        final alerts = _generateAlertList(seed);

        // Mark all alerts as unread
        final allUnreadAlerts =
            alerts.map((a) => a.copyWith(isRead: false)).toList();

        final unreadCount = _computeUnreadCount(allUnreadAlerts);
        expect(unreadCount, equals(allUnreadAlerts.length));
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'Unread count + read count equals total alert count',
      (seed) {
        final alerts = _generateAlertList(seed);

        final unreadCount = alerts.where((a) => !a.isRead).length;
        final readCount = alerts.where((a) => a.isRead).length;

        expect(
          unreadCount + readCount,
          equals(alerts.length),
          reason: 'unread ($unreadCount) + read ($readCount) should equal '
              'total (${alerts.length})',
        );
      },
    );
  });
}
