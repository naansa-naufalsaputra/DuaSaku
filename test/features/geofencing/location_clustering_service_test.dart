import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/features/geofencing/services/location_clustering_service.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';

void main() {
  group('LocationClusteringService Tests', () {
    late LocationClusteringService service;

    setUp(() {
      service = LocationClusteringService();
    });

    test(
      'should return empty list when transactions count with location < 3',
      () {
        final transactions = [
          TransactionModel(
            userId: 'user-1',
            amount: 10000,
            categoryId: 'cat-food',
            type: 'expense',
            notes: 'makan 1',
            createdAt: DateTime.now(),
            latitude: -6.9904,
            longitude: 110.4229,
          ),
          TransactionModel(
            userId: 'user-1',
            amount: 15000,
            categoryId: 'cat-food',
            type: 'expense',
            notes: 'makan 2',
            createdAt: DateTime.now(),
            latitude: -6.9905,
            longitude: 110.4230,
          ),
        ];

        final hotspots = service.detectHotspots(transactions);
        expect(hotspots, isEmpty);
      },
    );

    test(
      'should group nearby points into a single cluster and calculate correct centroid',
      () {
        final now = DateTime.now();
        final transactions = [
          TransactionModel(
            userId: 'user-1',
            amount: 10000,
            categoryId: 'cat-food',
            type: 'expense',
            notes: 'makan 1',
            createdAt: now,
            latitude: -6.9904,
            longitude: 110.4229,
          ),
          TransactionModel(
            userId: 'user-1',
            amount: 15000,
            categoryId: 'cat-food',
            type: 'expense',
            notes: 'makan 2',
            createdAt: now,
            latitude: -6.9905,
            longitude: 110.4230,
          ),
          TransactionModel(
            userId: 'user-1',
            amount: 20000,
            categoryId: 'cat-transport',
            type: 'expense',
            notes: 'ojek',
            createdAt: now,
            latitude: -6.9903,
            longitude: 110.4228,
          ),
        ];

        final hotspots = service.detectHotspots(transactions);
        expect(hotspots.length, equals(1));

        final hotspot = hotspots.first;
        expect(hotspot.id, equals('hotspot_1'));
        // Average latitude: (-6.9904 + -6.9905 + -6.9903) / 3 = -6.9904
        expect(hotspot.latitude, closeTo(-6.9904, 0.0001));
        // Average longitude: (110.4229 + 110.4230 + 110.4228) / 3 = 110.4229
        expect(hotspot.longitude, closeTo(110.4229, 0.0001));
        // Top category is 'cat-food' (count: 2) vs 'cat-transport' (count: 1)
        expect(hotspot.name, equals('Area cat-food'));
      },
    );

    test(
      'should identify high-spending clusters even if they have < 3 transactions',
      () {
        final now = DateTime.now();
        final transactions = [
          // Giant expense at place A (only 2 transactions but total > 500k)
          TransactionModel(
            userId: 'user-1',
            amount: 300000,
            categoryId: 'cat-shopping',
            type: 'expense',
            notes: 'baju',
            createdAt: now,
            latitude: -6.9904,
            longitude: 110.4229,
          ),
          TransactionModel(
            userId: 'user-1',
            amount: 250000,
            categoryId: 'cat-shopping',
            type: 'expense',
            notes: 'sepatu',
            createdAt: now,
            latitude: -6.9905,
            longitude: 110.4230,
          ),
          // One unrelated transaction elsewhere to satisfy total data count constraints
          TransactionModel(
            userId: 'user-1',
            amount: 10000,
            categoryId: 'cat-transport',
            type: 'expense',
            notes: 'parkir',
            createdAt: now,
            latitude: -7.0200,
            longitude: 110.4500,
          ),
        ];

        final hotspots = service.detectHotspots(transactions);

        // The Giant expense cluster (-6.9904) should be returned as hotspot_1
        // because total expense (550k) > 500k threshold.
        // The other cluster (-7.0200) only has 1 transaction and 10k spend, so it is filtered out.
        expect(hotspots.length, equals(1));
        expect(hotspots.first.latitude, closeTo(-6.9904, 0.0005));
        expect(hotspots.first.name, equals('Area cat-shopping'));
      },
    );

    test('should prioritize hotspots by spending amount and limit to top 5', () {
      final now = DateTime.now();
      final transactions = <TransactionModel>[];

      // Add 6 different locations (each with 3 transactions to pass density threshold)
      for (int i = 0; i < 6; i++) {
        final double baseLat = -6.9900 + (i * 0.05);
        final double baseLon = 110.4200 + (i * 0.05);
        final double amount =
            (i + 1) *
            100000.0; // spending increases with i (from 100k to 600k total per transaction)

        for (int j = 0; j < 3; j++) {
          transactions.add(
            TransactionModel(
              userId: 'user-1',
              amount: amount,
              categoryId: 'Cat$i',
              type: 'expense',
              notes: 'tx $i-$j',
              createdAt: now,
              latitude: baseLat + (j * 0.0001),
              longitude: baseLon + (j * 0.0001),
            ),
          );
        }
      }

      final hotspots = service.detectHotspots(transactions);

      // Total hotspots is limited to top 5
      expect(hotspots.length, equals(5));

      // Sorted by descending spending, so top hotspot should be Cat5 (spending = 600k * 3 = 1.8M)
      expect(hotspots[0].name, equals('Area Cat5'));
      expect(hotspots[1].name, equals('Area Cat4'));
      expect(hotspots[2].name, equals('Area Cat3'));
      expect(hotspots[3].name, equals('Area Cat2'));
      expect(hotspots[4].name, equals('Area Cat1'));
    });
  });
}
