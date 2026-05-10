import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ActivityIndicator } from 'react-native';
import { supabase } from '../../src/lib/supabase';
import Toast from 'react-native-toast-message';
import { makeRedirectUri } from 'expo-auth-session';
import { GoogleIcon } from '../../src/components/GoogleIcon';
import { Fingerprint } from 'lucide-react-native';
import * as LocalAuthentication from 'expo-local-authentication';
import * as SecureStore from 'expo-secure-store';
import { useTranslation } from 'react-i18next';

export default function LoginScreen() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const signIn = async () => {
    if (!email || !password) {
      Toast.show({ type: 'error', text1: 'Validation Error', text2: 'Email and Password are required.' });
      return;
    }
    setLoading(true);
    const { error, data } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) {
      Toast.show({ type: 'error', text1: 'Login Failed', text2: error.message });
    } else {
      if (data.session) {
        await SecureStore.setItemAsync('credentials', JSON.stringify({ email, password }));
      }
      Toast.show({ type: 'success', text1: 'Success', text2: 'Logged in successfully.' });
    }
  };

  const signUp = async () => {
    if (!email || !password) {
      Toast.show({ type: 'error', text1: 'Validation Error', text2: 'Email and Password are required.' });
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.signUp({ email, password });
    setLoading(false);
    if (error) {
      Toast.show({ type: 'error', text1: 'Registration Failed', text2: error.message });
    } else {
      Toast.show({ type: 'success', text1: 'Success', text2: 'Please check your email to verify your account.' });
    }
  };

  const signInWithGoogle = async () => {
    setLoading(true);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: makeRedirectUri({ scheme: 'duasaku' }),
      },
    });
    setLoading(false);
    if (error) {
      Toast.show({ type: 'error', text1: 'Google Sign In Failed', text2: error.message });
    }
  };

  const handleBiometricAuth = async () => {
    try {
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const isEnrolled = await LocalAuthentication.isEnrolledAsync();

      if (!hasHardware || !isEnrolled) {
        Toast.show({ type: 'error', text1: 'Biometrics unavailable', text2: 'Your device does not support or have biometrics set up.' });
        return;
      }

      const credentialsStr = await SecureStore.getItemAsync('credentials');
      if (!credentialsStr) {
        Toast.show({ type: 'info', text1: 'No credentials', text2: 'Please log in with email/password first.' });
        return;
      }

      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Authenticate to log in',
        fallbackLabel: 'Use password',
      });

      if (result.success) {
        setLoading(true);
        const credentials = JSON.parse(credentialsStr);
        const { error } = await supabase.auth.signInWithPassword({
          email: credentials.email,
          password: credentials.password
        });
        setLoading(false);

        if (error) {
          Toast.show({ type: 'error', text1: 'Login Failed', text2: error.message });
        } else {
          Toast.show({ type: 'success', text1: 'Authenticated', text2: 'Biometric login successful.' });
        }
      }
    } catch (error) {
      console.error(error);
      setLoading(false);
      Toast.show({ type: 'error', text1: 'Authentication Failed' });
    }
  };

  return (
    <View className="flex-1 bg-background justify-center px-container-margin py-section-gap">
      <View className="items-center mb-10">
        <Text className="font-h1 text-4xl text-primary tracking-tight">DuaSaku</Text>
        <Text className="font-body-md text-on-surface-variant mt-2">{t('manageFinancesElegantly')}</Text>
      </View>

      <View className="flex-col gap-4">
        <View className="flex-col gap-2">
          <Text className="font-label-md text-on-surface-variant">Email</Text>
          <TextInput
            className="bg-[#09090b] border border-[#27272a] text-white rounded-xl px-4 py-3 font-body-md"
            placeholder="Enter your email"
            placeholderTextColor="#71717a"
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            keyboardType="email-address"
          />
        </View>

        <View className="flex-col gap-2 mb-4">
          <Text className="font-label-md text-on-surface-variant">Password</Text>
          <TextInput
            className="bg-[#09090b] border border-[#27272a] text-white rounded-xl px-4 py-3 font-body-md"
            placeholder="Enter your password"
            placeholderTextColor="#71717a"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
          />
        </View>

        <TouchableOpacity 
          className="w-full bg-primary py-4 rounded-xl items-center"
          onPress={signIn}
          disabled={loading}
        >
          {loading ? <ActivityIndicator color="#fff" /> : <Text className="font-label-lg text-on-primary">{t('signIn')}</Text>}
        </TouchableOpacity>

        <TouchableOpacity 
          className="w-full py-4 rounded-xl items-center border border-[#27272a]"
          onPress={signUp}
          disabled={loading}
        >
          <Text className="font-label-lg text-foreground">{t('signUp')}</Text>
        </TouchableOpacity>

        <View className="flex-row items-center my-2">
          <View className="flex-1 h-[1px] bg-[#27272a]" />
          <Text className="font-body-sm text-on-surface-variant px-4">{t('or')}</Text>
          <View className="flex-1 h-[1px] bg-[#27272a]" />
        </View>

        <TouchableOpacity 
          className="w-full bg-white py-4 rounded-xl items-center flex-row justify-center gap-x-3"
          onPress={signInWithGoogle}
          disabled={loading}
        >
          <GoogleIcon size={24} />
          <Text className="font-label-lg text-black font-semibold">{t('continueWithGoogle')}</Text>
        </TouchableOpacity>

        <TouchableOpacity 
          className="mt-4 w-14 h-14 rounded-full border border-[#27272a] items-center justify-center self-center"
          onPress={handleBiometricAuth}
        >
          <Fingerprint color="#fafafa" size={28} />
        </TouchableOpacity>
      </View>
    </View>
  );
}
