import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../transactions/domain/models/transaction_model.dart';
import '../../transactions/domain/transaction_repository_interface.dart';
import '../../../core/utils/result.dart';
import 'location_clustering_service.dart';
import 'geofence_service.dart';

class GeofenceSyncHelper {
  /// Fetches all user transactions from local DB, clusters them, and registers hotspots to GeofenceService.
  static Future<void> syncGeofenceHotspots(
    TransactionRepositoryInterface transactionRepo,
    String userId,
  ) async {
    try {
      // 1. Check if geofencing alerts are enabled in preferences
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('geofencing_alerts_enabled') ?? false;
      if (!enabled) {
        // If disabled, stop monitoring and exit
        await GeofenceService.instance.stopMonitoring();
        return;
      }

      // 2. Fetch all transactions for this user
      final result = await transactionRepo.getTransactionsOnce(userId);
      final List<TransactionModel> transactions;
      switch (result) {
        case Success(:final value):
          transactions = value;
        case Failure(:final error):
          debugPrint('[GeofenceSync] Failed to fetch transactions: ${error.message}');
          return;
      }

      // 3. Detect hotspots using Clustering Service
      final clusteringService = LocationClusteringService();
      final hotspots = clusteringService.detectHotspots(transactions);

      // 4. Update the GeofenceService with the detected hotspots
      await GeofenceService.instance.updateGeofences(hotspots);

      // Ensure we are actively monitoring location
      await GeofenceService.instance.startMonitoring();

      debugPrint(
        '[GeofenceSync] Geofence sync completed. Registered ${hotspots.length} hotspots.',
      );
    } catch (e) {
      debugPrint('[GeofenceSync] Error in geofence sync: $e');
    }
  }
}
