import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/data/budget_repository.dart';
import '../data/alert_preferences_repository.dart';
import '../data/alert_repository.dart';
import '../data/alert_threshold_status_repository.dart';
import '../domain/alert_preferences_repository_interface.dart';
import '../domain/alert_repository_interface.dart';
import '../domain/alert_threshold_status_repository_interface.dart';
import '../domain/models/budget_alert_model.dart';
import '../services/alert_engine_service.dart';
import '../services/budget_alert_evaluator.dart';
import '../services/budget_notification_service.dart';
import '../services/prediction_engine_service.dart';

// ─── Repository Providers ─────────────────────────────────────────────────────

/// Provides the alert repository (abstract interface type).
final alertRepositoryProvider = Provider<AlertRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AlertRepository(db);
});

/// Provides the alert preferences repository (abstract interface type).
final alertPreferencesRepositoryProvider =
    Provider<AlertPreferencesRepositoryInterface>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return AlertPreferencesRepository(db);
    });

/// Provides the alert threshold status repository (abstract interface type).
final alertThresholdStatusRepositoryProvider =
    Provider<AlertThresholdStatusRepositoryInterface>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return AlertThresholdStatusRepository(db);
    });

// ─── Service Providers ────────────────────────────────────────────────────────

/// Provides the BudgetNotificationService for sending push notifications.
final budgetNotificationServiceProvider = Provider<BudgetNotificationService>((
  ref,
) {
  return BudgetNotificationService(
    db: ref.watch(appDatabaseProvider),
  );
});

/// Provides the AlertEngineService for threshold evaluation.
final alertEngineProvider = Provider<AlertEngineService>((ref) {
  return AlertEngineService(
    alertRepo: ref.watch(alertRepositoryProvider),
    prefsRepo: ref.watch(alertPreferencesRepositoryProvider),
    statusRepo: ref.watch(alertThresholdStatusRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
    notificationService: ref.watch(budgetNotificationServiceProvider),
  );
});

/// Provides the PredictionEngineService for spending projection.
final predictionEngineProvider = Provider<PredictionEngineService>((ref) {
  return PredictionEngineService(
    alertRepo: ref.watch(alertRepositoryProvider),
    prefsRepo: ref.watch(alertPreferencesRepositoryProvider),
    statusRepo: ref.watch(alertThresholdStatusRepositoryProvider),
    budgetRepo: ref.watch(budgetRepositoryProvider) as BudgetRepository,
    db: ref.watch(appDatabaseProvider),
    notificationService: ref.watch(budgetNotificationServiceProvider),
  );
});

// ─── Alert Center Stream Provider ─────────────────────────────────────────────

/// Provides the [BudgetAlertEvaluator] for triggering alert evaluation
/// from transaction providers and other integration points.
final budgetAlertEvaluatorProvider = Provider<BudgetAlertEvaluator>((ref) {
  return BudgetAlertEvaluator(
    alertEngine: ref.watch(alertEngineProvider),
    predictionEngine: ref.watch(predictionEngineProvider),
    statusRepo:
        ref.watch(alertThresholdStatusRepositoryProvider)
            as AlertThresholdStatusRepository,
  );
});

/// Watches all alerts for the current user as a reactive stream.
///
/// Returns an empty list if no user is logged in.
/// Auto-disposes when no longer watched (e.g., navigating away from
/// Alert Center screen).
final alertCenterProvider = StreamProvider.autoDispose<List<BudgetAlertModel>>((
  ref,
) {
  final user = ref.watch(userProvider);
  if (user == null) return Stream.value([]);
  final repo = ref.watch(alertRepositoryProvider);
  return repo.watchAlerts(user.id);
});
