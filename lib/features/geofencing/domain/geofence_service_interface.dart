import 'geofence_hotspot.dart';

/// Abstract interface for geofencing operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than the concrete GeofenceService.
abstract class GeofenceServiceInterface {
  /// Initialize the geofence service (notifications and location monitoring).
  Future<void> initialize();

  /// Start monitoring the user's location for geofence triggers.
  Future<void> startMonitoring();

  /// Update registered geofences dynamically based on hotspots.
  Future<void> updateGeofences(List<GeofenceHotspot> hotspots);

  /// Stop monitoring location for geofencing triggers.
  Future<void> stopMonitoring();

  /// Dispose of resources (cancel location stream subscriptions).
  void dispose();
}
