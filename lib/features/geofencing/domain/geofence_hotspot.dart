class GeofenceHotspot {
  final String id;
  final double latitude;
  final double longitude;
  final String name;

  const GeofenceHotspot({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceHotspot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          name == other.name;

  @override
  int get hashCode =>
      id.hashCode ^ latitude.hashCode ^ longitude.hashCode ^ name.hashCode;
}
