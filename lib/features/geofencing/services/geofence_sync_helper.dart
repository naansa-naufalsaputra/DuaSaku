import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../../../core/local_db/app_database.dart';
import '../../transactions/domain/models/transaction_model.dart';
import 'location_clustering_service.dart';
import 'geofence_service.dart';

class GeofenceSyncHelper {
  /// Fetches all user transactions from local DB, clusters them, and registers hotspots to GeofenceService.
  static Future<void> syncGeofenceHotspots(
    AppDatabase db,
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

      // 2. Fetch all transactions for this user with category names
      final query = db.select(db.transactions).join([
        leftOuterJoin(
          db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId),
        ),
      ]);
      query.where(db.transactions.userId.equals(userId));

      final rows = await query.get();
      final transactions = rows.map((row) {
        final tx = row.readTable(db.transactions);
        final cat = row.readTableOrNull(db.categories);

        return TransactionModel(
          id: tx.id,
          userId: tx.userId,
          amount: tx.amount,
          category: cat?.name ?? 'Uncategorized',
          type: tx.type,
          notes: tx.notes ?? '',
          createdAt: tx.date,
          walletId: tx.walletId,
          fromWalletId: tx.fromWalletId,
          toWalletId: tx.toWalletId,
          latitude: tx.latitude,
          longitude: tx.longitude,
        );
      }).toList();

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
