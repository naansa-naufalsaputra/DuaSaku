import 'dart:math' as math;

/// Utility class for geographic and location-based calculations.
class LocationHelper {
  /// Calculates the distance in meters between two geographic coordinates
  /// using the Haversine formula.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000; // Earth's radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
            
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
