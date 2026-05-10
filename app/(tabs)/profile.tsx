import React from 'react';
import { View, Text, ScrollView, TouchableOpacity, Switch, Alert } from 'react-native';
import { User, Shield, Languages, CircleHelp, LogOut, ChevronRight, Download, Wallet } from 'lucide-react-native';
import { useUserStore } from '../../src/store/useUserStore';
import { supabase } from '../../src/lib/supabase';
import { useTranslation } from 'react-i18next';
import { useHaptic } from '../../src/hooks/useHaptic';
import { CleanupService } from '../../src/lib/cleanupService';
import { useSettingsStore } from '../../src/store/useSettingsStore';
import { useGamificationStore } from '../../src/store/useGamificationStore';
import { Target as TargetIcon, BrainCircuit, Trophy } from 'lucide-react-native';
import { TextInput } from 'react-native';

const ProfileItem = ({ icon: Icon, title, value, onPress, showChevron = true, color = "#fafafa" }: any) => (
  <TouchableOpacity 
    className="flex-row items-center justify-between p-4 bg-surface-container mb-2 rounded-2xl border border-border"
    onPress={onPress}
    activeOpacity={0.7}
  >
    <View className="flex-row items-center gap-4">
      <View className="w-10 h-10 bg-background rounded-xl items-center justify-center border border-border">
        <Icon color={color} size={20} />
      </View>
      <View>
        <Text className="text-foreground font-h3 text-base">{title}</Text>
        {value && <Text className="text-on-surface-variant text-xs font-body-sm">{value}</Text>}
      </View>
    </View>
    {showChevron && <ChevronRight color="#52525b" size={20} />}
  </TouchableOpacity>
);

export default function ProfileScreen() {
  const { t, i18n } = useTranslation();
  const { hapticMedium, hapticSuccess } = useHaptic();
  const userProfile = useUserStore(state => state.userProfile);
  const biometricEnabled = useUserStore(state => state.biometricEnabled);
  const setBiometricEnabled = useUserStore(state => state.setBiometricEnabled);
  
  const { 
    aiPersonality, 
    setAiPersonality, 
    financialGoal,
    setFinancialGoal 
  } = useSettingsStore();

  const { badges } = useGamificationStore();

  const handleLogout = async () => {
    Alert.alert(
      t('logout'),
      'Apakah kamu yakin ingin keluar?',
      [
        { text: 'Batal', style: 'cancel' },
        { 
          text: 'Keluar', 
          style: 'destructive',
          onPress: async () => {
            // 1. Clear local caches first for security
            await CleanupService.clearAllCaches();
            
            // 2. Sign out from Supabase
            await supabase.auth.signOut();
            
            hapticMedium();
          }
        }
      ]
    );
  };

  const toggleBiometrics = () => {
    setBiometricEnabled(!biometricEnabled);
    hapticSuccess();
  };

  const toggleLanguage = () => {
    const newLang = i18n.language === 'id' ? 'en' : 'id';
    i18n.changeLanguage(newLang);
    hapticMedium();
  };

  return (
    <View className="flex-1 bg-background">
      {/* Header */}
      <View className="px-6 pt-14 pb-6 bg-background border-b border-border">
        <Text className="text-foreground font-h1 text-2xl tracking-tight">{t('profile')}</Text>
      </View>

      <ScrollView className="flex-1 px-6" showsVerticalScrollIndicator={false}>
        {/* User Card */}
        <View className="mt-6 p-6 bg-[#18181b] rounded-3xl border border-[#27272a] items-center">
          <View className="w-24 h-24 bg-primary/10 rounded-full items-center justify-center border-4 border-[#27272a] mb-4">
            <User color="#10b981" size={48} />
          </View>
          <Text className="text-foreground font-h2 text-xl mb-1">{userProfile?.name || 'User'}</Text>
          <Text className="text-on-surface-variant font-body-sm text-sm">{t('freeAccount')}</Text>
          
          <TouchableOpacity className="mt-6 bg-primary px-6 py-2.5 rounded-full">
            <Text className="text-primary-foreground font-label-md">{t('editProfile')}</Text>
          </TouchableOpacity>
        </View>

        {/* Badges Section */}
        <Text className="text-on-surface-variant font-label-sm uppercase tracking-widest mt-8 mb-4 px-1">{t('achievements')}</Text>
        <View className="flex-row flex-wrap gap-3">
          {badges.map((badge) => (
            <View 
              key={badge.id}
              className={`w-[47%] p-4 rounded-3xl border ${
                badge.unlockedAt ? 'bg-primary/5 border-primary/20' : 'bg-surface-container/50 border-border opacity-50'
              }`}
            >
              <View className="flex-row items-center gap-2 mb-2">
                <Text className="text-2xl">{badge.icon}</Text>
                {badge.unlockedAt && <Trophy color="#10b981" size={14} />}
              </View>
              <Text className={`font-bold text-sm ${badge.unlockedAt ? 'text-foreground' : 'text-on-surface-variant'}`}>
                {badge.name}
              </Text>
              <Text className="text-[12px] text-on-surface-variant leading-3 mt-1">
                {badge.description}
              </Text>
            </View>
          ))}
        </View>

        {/* Sections */}
        <Text className="text-on-surface-variant font-label-sm uppercase tracking-widest mt-10 mb-4 px-1">{t('accountSettings')}</Text>
        <ProfileItem icon={Wallet} title="Dompet & Saldo" value="Kelola sumber dana kamu" />
        <ProfileItem icon={Download} title="Ekspor Data" value="Download laporan transaksi (CSV)" />
        
        <Text className="text-on-surface-variant font-label-sm uppercase tracking-widest mt-8 mb-4 px-1">{t('aiIntelligence')}</Text>
        
        {/* Personality Selector */}
        <View className="p-4 bg-surface-container mb-4 rounded-3xl border border-border">
          <View className="flex-row items-center gap-3 mb-4">
            <View className="w-10 h-10 bg-primary/10 rounded-xl items-center justify-center border border-primary/20">
              <BrainCircuit color="#10b981" size={20} />
            </View>
            <View>
              <Text className="text-foreground font-h3 text-base">{t('aiPersonality')}</Text>
              <Text className="text-on-surface-variant text-xs font-body-sm">{t('aiPersonalityDesc')}</Text>
            </View>
          </View>
          
          <View className="flex-row gap-2">
            {[
              { id: 'strict', label: 'Tegas', icon: '😡' },
              { id: 'casual', label: 'Santai', icon: '😎' },
              { id: 'coach', label: 'Coach', icon: '🧠' }
            ].map((p) => (
              <TouchableOpacity
                key={p.id}
                onPress={() => {
                  setAiPersonality(p.id as any);
                  hapticMedium();
                }}
                className={`flex-1 py-3 rounded-2xl border items-center justify-center ${
                  aiPersonality === p.id 
                    ? 'bg-primary border-primary' 
                    : 'bg-background border-border'
                }`}
              >
                <Text className="text-lg mb-1">{p.icon}</Text>
                <Text 
                  className={`font-label-sm ${
                    aiPersonality === p.id ? 'text-primary-foreground' : 'text-on-surface-variant'
                  }`}
                >
                  {p.label}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Financial Goals Input */}
        <View className="p-4 bg-surface-container mb-4 rounded-3xl border border-border">
          <View className="flex-row items-center gap-3 mb-3">
            <View className="w-10 h-10 bg-secondary/10 rounded-xl items-center justify-center border border-secondary/20">
              <TargetIcon color="#3b82f6" size={20} />
            </View>
            <View>
              <Text className="text-foreground font-h3 text-base">{t('financialTarget')}</Text>
              <Text className="text-on-surface-variant text-xs font-body-sm">{t('financialTargetDesc')}</Text>
            </View>
          </View>
          
          <View className="gap-4">
            <View>
              <Text className="text-on-surface-variant text-[12px] uppercase font-bold mb-1 ml-1">{t('targetName')}</Text>
              <TextInput
                value={financialGoal.name}
                onChangeText={(text) => setFinancialGoal(prev => ({ ...prev, name: text }))}
                placeholder="Contoh: Liburan ke Bali"
                placeholderTextColor="#52525b"
                className="bg-background text-foreground px-4 py-3 rounded-2xl border border-border font-body-sm text-sm"
              />
            </View>

            <View className="flex-row gap-3">
              <View className="flex-1">
                <Text className="text-on-surface-variant text-[12px] uppercase font-bold mb-1 ml-1">{t('targetAmount')}</Text>
                <TextInput
                  value={financialGoal.targetAmount.toString()}
                  onChangeText={(text) => setFinancialGoal(prev => ({ ...prev, targetAmount: Number(text) || 0 }))}
                  placeholder="0"
                  placeholderTextColor="#52525b"
                  keyboardType="numeric"
                  className="bg-background text-foreground px-4 py-3 rounded-2xl border border-border font-body-sm text-sm"
                />
              </View>
              <View className="flex-1">
                <Text className="text-on-surface-variant text-[12px] uppercase font-bold mb-1 ml-1">{t('collectedAmount')}</Text>
                <TextInput
                  value={financialGoal.currentAmount.toString()}
                  onChangeText={(text) => setFinancialGoal(prev => ({ ...prev, currentAmount: Number(text) || 0 }))}
                  placeholder="0"
                  placeholderTextColor="#52525b"
                  keyboardType="numeric"
                  className="bg-background text-foreground px-4 py-3 rounded-2xl border border-border font-body-sm text-sm"
                />
              </View>
            </View>
          </View>
        </View>

        <Text className="text-on-surface-variant font-label-sm uppercase tracking-widest mt-6 mb-4 px-1">{t('preferences')}</Text>
        <ProfileItem 
          icon={Languages} 
          title={t('language')} 
          value={i18n.language === 'id' ? 'Bahasa Indonesia' : 'English'} 
          onPress={toggleLanguage}
          showChevron={false}
        />
        <View className="flex-row items-center justify-between p-4 bg-surface-container mb-2 rounded-2xl border border-border">
          <View className="flex-row items-center gap-4">
            <View className="w-10 h-10 bg-background rounded-xl items-center justify-center border border-border">
              <Shield color="#2dd4bf" size={20} />
            </View>
            <View>
              <Text className="text-foreground font-h3 text-base">{t('biometricUnlock')}</Text>
              <Text className="text-on-surface-variant text-xs font-body-sm">{t('lockApp')}</Text>
            </View>
          </View>
          <Switch 
            value={biometricEnabled} 
            onValueChange={toggleBiometrics}
            trackColor={{ false: '#27272a', true: '#10b981' }}
            thumbColor="#fafafa"
          />
        </View>

        <Text className="text-on-surface-variant font-label-sm uppercase tracking-widest mt-8 mb-4 px-1">{t('other')}</Text>
        <ProfileItem icon={CircleHelp} title="Pusat Bantuan" />
        <ProfileItem icon={LogOut} title={t('logout')} color="#ef4444" showChevron={false} onPress={handleLogout} />

        <View className="mt-10 mb-20 items-center">
          <Text className="text-on-surface-variant text-xs font-body-sm">DuaSaku v1.0.0</Text>
          <Text className="text-on-surface-variant text-xs font-body-sm mt-1">{t('madeWith')}</Text>
        </View>
      </ScrollView>
    </View>
  );
}
