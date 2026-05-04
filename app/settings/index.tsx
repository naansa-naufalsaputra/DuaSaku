import React, { useState, useEffect } from 'react';
import { View, Text, ScrollView, TouchableOpacity, Switch } from 'react-native';
import { ArrowLeft, Globe, DollarSign, Fingerprint, Info, ChevronRight, User } from 'lucide-react-native';
import { useRouter } from 'expo-router';
import { useTranslation } from 'react-i18next';
import { useUserStore } from '../../src/store/useUserStore';
import { supabase } from '../../src/lib/supabase';
import * as LocalAuthentication from 'expo-local-authentication';
import Toast from 'react-native-toast-message';

export default function SettingsScreen() {
  const router = useRouter();
  const { t } = useTranslation();
  const { language, setLanguage, userProfile, biometricEnabled, setBiometricEnabled } = useUserStore();
  const [currency, setCurrency] = useState('IDR');
  const [isBiometricEnabled, setIsBiometricEnabled] = useState(biometricEnabled || false);
  const [hasBiometricHardware, setHasBiometricHardware] = useState(false);

  useEffect(() => {
    // Check hardware support for biometrics
    const checkBiometrics = async () => {
      const compatible = await LocalAuthentication.hasHardwareAsync();
      setHasBiometricHardware(compatible);
      
      // Load user preferences from Supabase metadata
      const { data } = await supabase.auth.getUser();
      if (data.user?.user_metadata) {
        if (data.user.user_metadata.currency) setCurrency(data.user.user_metadata.currency);
        if (data.user.user_metadata.language) setLanguage(data.user.user_metadata.language);
        if (data.user.user_metadata.biometricEnabled !== undefined) {
          setIsBiometricEnabled(data.user.user_metadata.biometricEnabled);
          setBiometricEnabled(data.user.user_metadata.biometricEnabled);
        }
      }
    };
    checkBiometrics();
  }, [setBiometricEnabled, setLanguage]);

  const handleLanguageToggle = async () => {
    const newLang = language === 'en' ? 'id' : 'en';
    setLanguage(newLang);
    
    // Sync to Supabase
    await supabase.auth.updateUser({
      data: { language: newLang }
    });
  };

  const handleCurrencyToggle = async () => {
    const newCurrency = currency === 'IDR' ? 'USD' : 'IDR';
    setCurrency(newCurrency);
    
    // Sync to Supabase
    await supabase.auth.updateUser({
      data: { currency: newCurrency }
    });
    Toast.show({ type: 'success', text1: 'Currency Updated', text2: `Currency set to ${newCurrency}` });
  };

  const handleBiometricToggle = async (newValue: boolean) => {
    if (!hasBiometricHardware) {
      Toast.show({ 
        type: 'error', 
        text1: 'Not Supported', 
        text2: 'Biometrics not available on this device.' 
      });
      return;
    }
    
    // Mandatory instant verification when toggling ON
    if (newValue) {
      const enrolled = await LocalAuthentication.isEnrolledAsync();
      if (!enrolled) {
        Toast.show({ 
          type: 'error', 
          text1: 'No Biometrics Found', 
          text2: 'Please set up biometrics in your device settings first.' 
        });
        return;
      }

      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: t('unlockDesc'),
        fallbackLabel: 'Use Passcode',
        disableDeviceFallback: false,
      });
      
      if (!result.success) {
        // Verification failed or cancelled, do not enable
        return;
      }
    }
    
    // Update local and global state
    setIsBiometricEnabled(newValue);
    setBiometricEnabled(newValue);
    
    // Sync preference with Supabase metadata for cross-device persistence (optional but good)
    try {
      await supabase.auth.updateUser({
        data: { biometricEnabled: newValue }
      });
    } catch (e) {
      console.warn('Supabase sync failed:', e);
    }
    
    Toast.show({ 
      type: 'success', 
      text1: 'Security Updated', 
      text2: newValue ? 'Biometric lock enabled' : 'Biometric lock disabled' 
    });
  };

  return (
    <View className="flex-1 bg-background">
      {/* TopAppBar */}
      <View className="flex-row justify-between items-center px-4 h-16 bg-background/80 border-b border-border mt-10">
        <View className="flex-row items-center gap-4">
          <TouchableOpacity 
            className="p-2 rounded-full items-center justify-center"
            onPress={() => router.back()}
          >
            <ArrowLeft color="#fafafa" size={24} />
          </TouchableOpacity>
          <Text className="font-h1 text-xl text-foreground">{t('settings')}</Text>
        </View>
      </View>

      <ScrollView className="flex-1 px-container-margin py-section-gap max-w-2xl w-full self-center">
        {/* Profile Read-Only Section */}
        <View className="mb-6">
          <Text className="font-label-md text-on-surface-variant mb-2 uppercase ml-1">{t('profile')}</Text>
          <View className="bg-surface-container-low rounded-xl border border-outline-variant p-4 flex-row items-center justify-between">
            <View className="flex-row items-center gap-4">
              <User color="#a1a1aa" size={24} />
              <View>
                <Text className="font-body-md text-on-surface">{userProfile.name}</Text>
                <Text className="font-body-sm text-on-surface-variant">{t('connectedAccount')}</Text>
              </View>
            </View>
          </View>
        </View>

        {/* Preferences Section */}
        <View className="mb-6">
          <Text className="font-label-md text-on-surface-variant mb-2 uppercase ml-1">{t('preferences')}</Text>
          <View className="bg-surface-container-low rounded-xl border border-outline-variant overflow-hidden">
            {/* Language Toggle */}
            <TouchableOpacity 
              className="w-full flex-row items-center justify-between p-4 border-b border-outline-variant"
              onPress={handleLanguageToggle}
            >
              <View className="flex-row items-center gap-4">
                <Globe color="#a1a1aa" size={24} />
                <Text className="font-body-md text-on-surface">{t('language')}</Text>
              </View>
              <View className="flex-row items-center gap-2">
                <Text className="font-label-md text-primary uppercase">{language}</Text>
                <ChevronRight color="#27272a" size={24} />
              </View>
            </TouchableOpacity>

            {/* Currency Toggle */}
            <TouchableOpacity 
              className="w-full flex-row items-center justify-between p-4"
              onPress={handleCurrencyToggle}
            >
              <View className="flex-row items-center gap-4">
                <DollarSign color="#a1a1aa" size={24} />
                <Text className="font-body-md text-on-surface">{t('currency')}</Text>
              </View>
              <View className="flex-row items-center gap-2">
                <Text className="font-label-md text-primary">{currency}</Text>
                <ChevronRight color="#27272a" size={24} />
              </View>
            </TouchableOpacity>
          </View>
        </View>

        {/* Security Section */}
        <View className="mb-6">
          <Text className="font-label-md text-on-surface-variant mb-2 uppercase ml-1">{t('security')}</Text>
          <View className="bg-surface-container-low rounded-xl border border-outline-variant overflow-hidden">
            <View className="w-full flex-row items-center justify-between p-4">
              <View className="flex-row items-center gap-4">
                <Fingerprint color="#a1a1aa" size={24} />
                <Text className="font-body-md text-on-surface">{t('biometricUnlock')}</Text>
              </View>
              <Switch
                testID="biometric_switch"
                value={isBiometricEnabled}
                onValueChange={handleBiometricToggle}
                trackColor={{ false: '#27272a', true: '#2dd4bf' }}
                thumbColor={'#fafafa'}
                disabled={!hasBiometricHardware}
              />
            </View>
          </View>
        </View>

        {/* About Section */}
        <View className="mb-10">
          <Text className="font-label-md text-on-surface-variant mb-2 uppercase ml-1">{t('about')}</Text>
          <View className="bg-surface-container-low rounded-xl border border-outline-variant overflow-hidden">
            <TouchableOpacity className="w-full flex-row items-center justify-between p-4 border-b border-outline-variant">
              <View className="flex-row items-center gap-4">
                <Info color="#a1a1aa" size={24} />
                <Text className="font-body-md text-on-surface">{t('version')}</Text>
              </View>
              <Text className="font-body-md text-on-surface-variant">1.0.0 (Build 12)</Text>
            </TouchableOpacity>
            
            <TouchableOpacity className="w-full flex-row items-center justify-between p-4">
              <Text className="font-body-md text-on-surface ml-10">{t('termsPrivacy')}</Text>
              <ChevronRight color="#27272a" size={24} />
            </TouchableOpacity>
          </View>
          <Text className="text-center font-body-sm text-on-surface-variant mt-4">{t('madeWith')}</Text>
        </View>
      </ScrollView>
    </View>
  );
}
