import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../../core/local_db/app_database_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../domain/geofence_hotspot.dart';
import '../../services/location_clustering_service.dart';

final geofencingMapHotspotsProvider =
    FutureProvider.autoDispose<List<GeofenceHotspot>>((ref) async {
      final db = ref.watch(appDatabaseProvider);
      final user = ref.watch(userProvider);

      if (user == null) return const [];

      final query = db.select(db.transactions).join([
        leftOuterJoin(
          db.categories,
          db.categories.id.equalsExp(db.transactions.categoryId),
        ),
      ]);
      query.where(db.transactions.userId.equals(user.id));

      final rows = await query.get();
      final transactions = rows.map((row) {
        final tx = row.readTable(db.transactions);

        return TransactionModel(
          id: tx.id,
          userId: tx.userId,
          amount: tx.amount,
          categoryId: tx.categoryId ?? 'uncategorized',
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

      final clusteringService = LocationClusteringService();
      return clusteringService.detectHotspots(transactions);
    });

class GeofencingMapScreen extends ConsumerWidget {
  const GeofencingMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotspotsAsync = ref.watch(geofencingMapHotspotsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Modern Minimalist Dark / Light mode color styles matching DuaSaku theme
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF9F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'profile.geofencing_alerts'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      body: hotspotsAsync.when(
        data: (hotspots) {
          if (hotspots.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No spending hotspots detected yet.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Spend money at 3+ locations or spend more than Rp 500.000 in one area to trigger a warning hotspot.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final centerLatLng = LatLng(
            hotspots.first.latitude,
            hotspots.first.longitude,
          );

          return FlutterMap(
            options: MapOptions(
              initialCenter: centerLatLng,
              initialZoom: 15.0,
              maxZoom: 18.0,
              minZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.duasaku.app',
                tileBuilder: isDark
                    ? (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -0.2126,
                            -0.7152,
                            -0.0722,
                            0,
                            255,
                            -0.2126,
                            -0.7152,
                            -0.0722,
                            0,
                            255,
                            -0.2126,
                            -0.7152,
                            -0.0722,
                            0,
                            255,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: tileWidget,
                        );
                      }
                    : null,
              ),
              CircleLayer(
                circles: hotspots
                    .map(
                      (h) => CircleMarker(
                        point: LatLng(h.latitude, h.longitude),
                        radius: 150.0,
                        useRadiusInMeter: true,
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderColor: Colors.redAccent.withValues(alpha: 0.45),
                        borderStrokeWidth: 1.5,
                      ),
                    )
                    .toList(),
              ),
              MarkerLayer(
                markers: hotspots
                    .map(
                      (h) => Marker(
                        point: LatLng(h.latitude, h.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showHotspotDetails(
                            context,
                            ref,
                            h,
                            cardBgColor,
                            cardBorderColor,
                            textColor,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.redAccent,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.location_on_rounded,
                                color: Colors.redAccent,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('error.general'.tr())),
      ),
    );
  }

  void _showHotspotDetails(
    BuildContext context,
    WidgetRef ref,
    GeofenceHotspot hotspot,
    Color bg,
    Color border,
    Color text,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotspot.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Spending Warning Zone',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: border),
              const SizedBox(height: 16),
              Text(
                'Radius: 150m from centroid',
                style: TextStyle(
                  fontSize: 13,
                  color: text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Latitude: ${hotspot.latitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 13,
                  color: text.withValues(alpha: 0.7),
                ),
              ),
              Text(
                'Longitude: ${hotspot.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 13,
                  color: text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
