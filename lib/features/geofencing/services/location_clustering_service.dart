import 'dart:math';
import '../../../core/utils/location_helper.dart';
import '../../transactions/domain/models/transaction_model.dart';
import '../domain/geofence_hotspot.dart';

class TransactionCluster {
  final List<TransactionModel> transactions;
  double centroidLatitude;
  double centroidLongitude;

  TransactionCluster({
    required this.transactions,
    required this.centroidLatitude,
    required this.centroidLongitude,
  });

  double get totalSpent {
    return transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalSpentLast30Days {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return transactions
        .where((t) => t.type == 'expense' && t.createdAt.isAfter(cutoff))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  void addTransaction(TransactionModel tx) {
    transactions.add(tx);
    // Recalculate centroid (simple arithmetic mean is fine for local clusters)
    double sumLat = 0.0;
    double sumLon = 0.0;
    int count = 0;

    for (final t in transactions) {
      if (t.latitude != null && t.longitude != null) {
        sumLat += t.latitude!;
        sumLon += t.longitude!;
        count++;
      }
    }
    if (count > 0) {
      centroidLatitude = sumLat / count;
      centroidLongitude = sumLon / count;
    }
  }

  String determineName() {
    // Find the most frequent category in this cluster
    final categoryCounts = <String, int>{};
    for (final tx in transactions) {
      categoryCounts[tx.category] = (categoryCounts[tx.category] ?? 0) + 1;
    }

    String topCategory = 'Belanja';
    int maxCount = 0;
    categoryCounts.forEach((category, count) {
      if (count > maxCount) {
        maxCount = count;
        topCategory = category;
      }
    });

    return 'Area $topCategory';
  }
}

class LocationClusteringService {
  static const double clusterRadiusMeters = 150.0;
  static const int minTransactionCount = 3;
  static const double minSpendAmountLast30Days = 500000.0;

  /// Clusters transactions based on location and returns the top 5 hotspots.
  List<GeofenceHotspot> detectHotspots(List<TransactionModel> transactions) {
    // 1. Filter out transactions without coordinates
    final locTransactions = transactions
        .where((t) => t.latitude != null && t.longitude != null)
        .toList();

    if (locTransactions.length < minTransactionCount) {
      return const [];
    }

    final clusters = <TransactionCluster>[];

    // 2. Perform distance-based clustering
    for (final tx in locTransactions) {
      final txLat = tx.latitude!;
      final txLon = tx.longitude!;
      
      TransactionCluster? bestCluster;
      double minDistance = double.maxFinite;

      for (final cluster in clusters) {
        final distance = LocationHelper.calculateDistance(
          txLat,
          txLon,
          cluster.centroidLatitude,
          cluster.centroidLongitude,
        );
        if (distance <= clusterRadiusMeters && distance < minDistance) {
          minDistance = distance;
          bestCluster = cluster;
        }
      }

      if (bestCluster != null) {
        bestCluster.addTransaction(tx);
      } else {
        clusters.add(
          TransactionCluster(
            transactions: [tx],
            centroidLatitude: txLat,
            centroidLongitude: txLon,
          ),
        );
      }
    }

    // 3. Filter clusters (hotspots)
    // Criteria: contains >= 3 transactions OR spending in last 30 days >= Rp 500.000
    final hotspots = clusters.where((cluster) {
      final isHighFrequency = cluster.transactions.length >= minTransactionCount;
      final isHighSpending = cluster.totalSpentLast30Days >= minSpendAmountLast30Days;
      return isHighFrequency || isHighSpending;
    }).toList();

    // 4. Sort by descending total spending, then descending transaction count
    hotspots.sort((a, b) {
      final spendCompare = b.totalSpent.compareTo(a.totalSpent);
      if (spendCompare != 0) return spendCompare;
      return b.transactions.length.compareTo(a.transactions.length);
    });

    // 5. Select top 5 hotspots and convert to GeofenceHotspot objects
    final result = <GeofenceHotspot>[];
    final limit = min(5, hotspots.length);

    for (int i = 0; i < limit; i++) {
      final cluster = hotspots[i];
      result.add(
        GeofenceHotspot(
          id: 'hotspot_${i + 1}',
          latitude: cluster.centroidLatitude,
          longitude: cluster.centroidLongitude,
          name: cluster.determineName(),
        ),
      );
    }

    return result;
  }
}
