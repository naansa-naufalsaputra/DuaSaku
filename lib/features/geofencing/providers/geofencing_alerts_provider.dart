import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geofence_service.dart';

class GeofencingAlertsNotifier extends Notifier<bool> {
  static const String _prefKey = 'geofencing_alerts_enabled';

  @override
  bool build() {
    _loadPreference();
    return false; // Default to false initially, will load asynchronously
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_prefKey) ?? false;

      // If enabled, make sure monitoring is active
      if (state) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          await GeofenceService.instance.startMonitoring();
        } else {
          // Revert since permission isn't available
          state = false;
          await prefs.setBool(_prefKey, false);
        }
      }
    } catch (e) {
      // Fail silently
    }
  }

  Future<bool> toggleAlerts(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (enabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          state = false;
          await prefs.setBool(_prefKey, false);
          return false;
        }

        await GeofenceService.instance.startMonitoring();
        state = true;
        await prefs.setBool(_prefKey, true);
        return true;
      } else {
        await GeofenceService.instance.stopMonitoring();
        state = false;
        await prefs.setBool(_prefKey, false);
        return true;
      }
    } catch (e) {
      state = false;
      return false;
    }
  }
}

final geofencingAlertsProvider =
    NotifierProvider<GeofencingAlertsNotifier, bool>(() {
      return GeofencingAlertsNotifier();
    });
