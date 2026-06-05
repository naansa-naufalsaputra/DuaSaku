import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/geofence_service_interface.dart';
import '../domain/geofence_hotspot.dart';

class GeofenceService implements GeofenceServiceInterface {
  static final GeofenceService instance = GeofenceService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Default fallback hotspot: Simpang Lima Semarang
  static const GeofenceHotspot _defaultHotspot = GeofenceHotspot(
    id: 'default_simpang_lima',
    latitude: -6.9904,
    longitude: 110.4229,
    name: 'Area Simpang Lima Semarang',
  );

  List<GeofenceHotspot> _activeHotspots = [_defaultHotspot];
  final Map<String, DateTime> _lastHotspotNotificationTimes = {};

  StreamSubscription<Position>? _positionStreamSubscription;

  GeofenceService._init();

  @override
  Future<void> initialize() async {
    // 1. Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle when notification is tapped
      },
    );

    // 2. Request and check location permissions only if enabled in preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('geofencing_alerts_enabled') ?? false;
      if (enabled) {
        await startMonitoring();
      }
    } catch (e) {
      // Fallback silently if preferences are unavailable
    }
  }

  @override
  Future<void> startMonitoring() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Start location tracking stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Check every 10 meters
    );

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _checkGeofence(position);
          },
          onError: (e) {
            // Handle location stream error silently
          },
        );
  }

  @override
  Future<void> updateGeofences(List<GeofenceHotspot> hotspots) async {
    if (hotspots.isEmpty) {
      _activeHotspots = [_defaultHotspot];
    } else {
      _activeHotspots = hotspots;
    }
  }

  void _checkGeofence(Position position) {
    for (final hotspot in _activeHotspots) {
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        hotspot.latitude,
        hotspot.longitude,
      );

      if (distance <= 150.0) {
        // 150 meters geofence radius
        _triggerGeofenceNotification(hotspot);
      }
    }
  }

  Future<void> _triggerGeofenceNotification(GeofenceHotspot hotspot) async {
    final now = DateTime.now();
    final lastNotificationTime = _lastHotspotNotificationTimes[hotspot.id];

    // Cooldown logic to prevent notification spamming (6 hours per hotspot)
    if (lastNotificationTime != null &&
        now.difference(lastNotificationTime) < const Duration(hours: 6)) {
      return;
    }

    _lastHotspotNotificationTimes[hotspot.id] = now;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'geofence_channel',
          'Geofencing Alerts',
          channelDescription: 'Alerts when entering frequent spending areas',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: hotspot.id.hashCode,
      title: '⚠️ Watch your wallet!',
      body: "You've entered ${hotspot.name} (a frequent spending area).",
      notificationDetails: platformChannelSpecifics,
    );
  }

  @override
  Future<void> stopMonitoring() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}
