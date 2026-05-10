import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import ClusteredMapView from 'react-native-map-clustering';
import { MapPin, Plus, Layers, Target } from 'lucide-react-native';
import * as Location from 'expo-location';
import { supabase } from '../../src/lib/supabase';
import { useUserStore } from '../../src/store/useUserStore';


export default function MapScreen() {
  const [location, setLocation] = useState<Location.LocationObject | null>(null);
  const [markers, setMarkers] = useState<any[]>([]);
  const [mapRegion, setMapRegion] = useState({
    latitude: -6.200000,
    longitude: 106.816666,
    latitudeDelta: 0.05,
    longitudeDelta: 0.05,
  });

  const { session } = useUserStore();
  const userId = session?.user?.id;

  useEffect(() => {
    if (!userId) return;

    (async () => {
      let { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') return;

      let loc = await Location.getCurrentPositionAsync({});
      setLocation(loc);
      setMapRegion(prev => ({
        ...prev,
        latitude: loc.coords.latitude,
        longitude: loc.coords.longitude,
      }));

      // Fetch transaction markers for current user
      const { data, error } = await supabase
        .from('transactions')
        .select('*')
        .eq('user_id', userId)
        .not('latitude', 'is', null);
      
      if (!error && data) {
        setMarkers(data);
      }
    })();
  }, [userId]);

  const centerOnUser = async () => {
    if (location) {
      setMapRegion(prev => ({
        ...prev,
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      }));
    }
  };

  return (
    <View className="flex-1 bg-background">
      <ClusteredMapView
        style={StyleSheet.absoluteFill}
        provider={PROVIDER_GOOGLE}
        initialRegion={mapRegion}
        region={mapRegion}
        onRegionChangeComplete={setMapRegion}
        clusterColor="#10b981"
        clusterTextColor="#18181b"
        mapPadding={{ top: 50, right: 0, bottom: 0, left: 0 }}
        customMapStyle={darkMapStyle}
      >
        {markers.map((marker) => (
          <Marker
            key={marker.id}
            coordinate={{
              latitude: marker.latitude,
              longitude: marker.longitude,
            }}
            title={marker.note}
            description={`Rp ${marker.amount.toLocaleString('id-ID')}`}
          >
            <View className="bg-[#18181b] p-2 rounded-full border-2 border-primary">
              <MapPin color="#10b981" size={20} />
            </View>
          </Marker>
        ))}
      </ClusteredMapView>

      {/* Overlays */}
      <View className="absolute top-14 left-6 right-6 flex-row justify-between items-center">
        <View className="bg-[#18181b]/90 px-4 py-2 rounded-2xl border border-[#27272a] shadow-lg">
          <Text className="text-foreground font-h3 text-base">{t('expenseMap')}</Text>
          <Text className="text-on-surface-variant text-xs">{markers.length} Locations</Text>
        </View>
        <TouchableOpacity className="w-12 h-12 bg-[#18181b]/90 rounded-2xl items-center justify-center border border-[#27272a] shadow-lg">
          <Layers color="#fafafa" size={20} />
        </TouchableOpacity>
      </View>

      <View className="absolute bottom-32 right-6 gap-3">
        <TouchableOpacity 
          className="w-14 h-14 bg-primary rounded-2xl items-center justify-center shadow-xl"
          onPress={() => {}}
        >
          <Plus color="#18181b" size={28} />
        </TouchableOpacity>
        <TouchableOpacity 
          className="w-14 h-14 bg-[#18181b]/90 rounded-2xl items-center justify-center border border-[#27272a] shadow-xl"
          onPress={centerOnUser}
        >
          <Target color="#fafafa" size={24} />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const darkMapStyle = [
  { "elementType": "geometry", "stylers": [{ "color": "#121212" }] },
  { "elementType": "labels.text.fill", "stylers": [{ "color": "#746855" }] },
  { "elementType": "labels.text.stroke", "stylers": [{ "color": "#242f3e" }] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{ "color": "#d59563" }] },
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [{ "color": "#d59563" }] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [{ "color": "#263c3f" }] },
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{ "color": "#6b9a76" }] },
  { "featureType": "road", "elementType": "geometry", "stylers": [{ "color": "#38414e" }] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [{ "color": "#212a37" }] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [{ "color": "#9ca5b3" }] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [{ "color": "#746855" }] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{ "color": "#1f2835" }] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{ "color": "#f3d19c" }] },
  { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#17263c" }] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [{ "color": "#515c6d" }] },
  { "featureType": "water", "elementType": "labels.text.stroke", "stylers": [{ "color": "#17263c" }] }
];
