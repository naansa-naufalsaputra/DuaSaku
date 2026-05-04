import React, { useRef, useState, useEffect } from 'react';
import { View, TouchableOpacity } from 'react-native';
import { Tabs } from 'expo-router';
import { Home, PieChart, Wallet, User, Plus, MapPin, Bot } from 'lucide-react-native';
import BottomSheet from '@gorhom/bottom-sheet';
import SmartInputSheet from '../../src/components/SmartInputSheet';
import * as Notifications from 'expo-notifications';

export default function TabsLayout() {
  const [isInputOpen, setIsInputOpen] = useState(false);
  const [hasOpenedSheet, setHasOpenedSheet] = useState(false);
  const sheetRef = useRef<BottomSheet>(null);

  useEffect(() => {
    const subscription = Notifications.addNotificationResponseReceivedListener(response => {
      setHasOpenedSheet(true);
      setTimeout(() => {
        sheetRef.current?.snapToIndex(1);
        setIsInputOpen(true);
      }, 50); // Small delay to allow mounting
    });

    return () => {
      subscription.remove();
    };
  }, []);

  const toggleInputSheet = () => {
    if (isInputOpen) {
      sheetRef.current?.close();
      setIsInputOpen(false);
    } else {
      setHasOpenedSheet(true);
      setTimeout(() => {
        sheetRef.current?.snapToIndex(1);
        setIsInputOpen(true);
      }, 50); // Small delay if it's the first time
    }
  };

  return (
    <View className="flex-1 bg-background">
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: '#fafafa',
          tabBarInactiveTintColor: '#a1a1aa',
          tabBarStyle: {
            backgroundColor: '#09090b',
            borderTopWidth: 1,
            borderTopColor: '#27272a',
            elevation: 0,
            shadowOpacity: 0,
            paddingBottom: 8,
            height: 60,
          },
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: 'Home',
            tabBarIcon: ({ color }) => <Home color={color} size={24} />,
          }}
        />
        <Tabs.Screen
          name="insights"
          options={{
            title: 'Analytics',
            tabBarIcon: ({ color }) => <PieChart color={color} size={24} />,
          }}
        />
        <Tabs.Screen
          name="ai"
          options={{
            title: 'AI Advisor',
            tabBarIcon: ({ color }) => <Bot color={color} size={24} />,
          }}
        />
        <Tabs.Screen
          name="budget"
          options={{
            title: 'Wallets',
            tabBarIcon: ({ color }) => <Wallet color={color} size={24} />,
          }}
        />
        <Tabs.Screen
          name="map"
          options={{
            title: 'Map',
            tabBarIcon: ({ color }) => <MapPin color={color} size={24} />,
          }}
        />
        <Tabs.Screen
          name="profile"
          options={{
            title: 'Profile',
            tabBarIcon: ({ color }) => <User color={color} size={24} />,
          }}
        />
      </Tabs>

      {/* Global FAB */}
      <TouchableOpacity
        testID="global_add_transaction_fab"
        className="absolute bottom-24 right-6 w-14 h-14 bg-primary rounded-full items-center justify-center shadow-lg z-50"
        onPress={toggleInputSheet}
        activeOpacity={0.8}
      >
        <Plus color="#18181b" size={28} />
      </TouchableOpacity>

      {/* Global Smart Input Sheet - Defer mounted for cold start optimization */}
      {hasOpenedSheet && (
        <SmartInputSheet 
          ref={sheetRef} 
          onClose={() => setIsInputOpen(false)}
        />
      )}
    </View>
  );
}

