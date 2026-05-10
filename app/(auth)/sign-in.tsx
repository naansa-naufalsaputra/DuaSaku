import React, { useState, useEffect } from 'react';
import { 
  View, 
  Text, 
  TextInput, 
  TouchableOpacity, 
  KeyboardAvoidingView, 
  Platform, 
  ScrollView, 
  ActivityIndicator,
  Keyboard,
  Animated
} from 'react-native';
import LottieView from 'lottie-react-native';
import { useRouter } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as Haptics from 'expo-haptics';
import * as LocalAuthentication from 'expo-local-authentication';
import * as SecureStore from 'expo-secure-store';
import { Eye, EyeOff, Fingerprint } from 'lucide-react-native';
import { supabase } from '../../src/lib/supabase';
import Toast from 'react-native-toast-message';

const EMAIL_DOMAINS = ['@gmail.com', '@yahoo.com', '@outlook.com'];

export default function SignInScreen() {
  const router = useRouter();
  
  // States
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [isBiometricAvailable, setIsBiometricAvailable] = useState(false);
  
  // Animations
  const lottieScale = React.useRef(new Animated.Value(1)).current;

  // Keyboard Management
  useEffect(() => {
    const showSub = Keyboard.addListener(Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow', () => {
      Animated.timing(lottieScale, {
        toValue: 0.6,
        duration: 300,
        useNativeDriver: true,
      }).start();
    });
    const hideSub = Keyboard.addListener(Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide', () => {
      Animated.timing(lottieScale, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }).start();
    });

    return () => {
      showSub.remove();
      hideSub.remove();
    };
  }, [lottieScale]);

  // Check biometric availability on mount
  useEffect(() => {
    (async () => {
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const isEnrolled = await LocalAuthentication.isEnrolledAsync();
      const credentialsStr = await SecureStore.getItemAsync('credentials');
      
      if (hasHardware && isEnrolled && credentialsStr) {
        setIsBiometricAvailable(true);
        // Auto-run biometric on cold start if available
        handleBiometricAuth(credentialsStr);
      }
    })();
  }, []);

  // Haptic feedback for typing
  const handleTyping = (text: string, setter: (val: string) => void) => {
    if (text.length === 1 && text.length > 0) {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
    setter(text);
  };

  const appendDomain = (domain: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!email.includes('@')) {
      setEmail(email + domain);
    } else {
      const base = email.split('@')[0];
      setEmail(base + domain);
    }
  };

  // Auth Logic: Email/Password
  const handleSignIn = async () => {
    if (!email || !password) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Toast.show({
        type: 'error',
        text1: 'Oops!',
        text2: 'Please fill in both email and password.',
      });
      return;
    }

    setLoading(true);
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    
    if (error) {
      setLoading(false);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Toast.show({
        type: 'error',
        text1: 'Login Failed',
        text2: error.message,
      });
    } else {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      if (data.session) {
        // Store credentials for future biometric login
        await SecureStore.setItemAsync('credentials', JSON.stringify({ email, password }));
      }
      Toast.show({
        type: 'success',
        text1: 'Welcome back!',
        text2: 'Redirecting to your dashboard...',
      });
    }
  };

  // Auth Logic: Reset Password
  const handleResetPassword = async () => {
    if (!email) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      Toast.show({
        type: 'error',
        text1: 'Email required',
        text2: 'Please enter your email to reset password.',
      });
      return;
    }

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const { error } = await supabase.auth.resetPasswordForEmail(email);

    if (error) {
      Toast.show({ type: 'error', text1: 'Error', text2: error.message });
    } else {
      Toast.show({
        type: 'success',
        text1: 'Email Sent',
        text2: 'Check your inbox for the reset link.',
      });
    }
  };

  // Auth Logic: Biometric
  const handleBiometricAuth = async (storedCreds?: string) => {
    try {
      const credentialsStr = storedCreds || await SecureStore.getItemAsync('credentials');
      
      if (!credentialsStr) {
        if (!storedCreds) {
          Toast.show({
            type: 'info',
            text1: 'First time?',
            text2: 'Please log in with your email/password first.',
          });
        }
        return;
      }

      const result = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Sign in to DuaSaku',
        fallbackLabel: 'Use Password',
      });

      if (result.success) {
        setLoading(true);
        const credentials = JSON.parse(credentialsStr);
        const { error } = await supabase.auth.signInWithPassword({
          email: credentials.email,
          password: credentials.password
        });

        if (error) {
          setLoading(false);
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
          Toast.show({ type: 'error', text1: 'Auth Failed', text2: error.message });
        } else {
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          // Redirect handled by _layout.tsx on session change
        }
      }
    } catch (err) {
      console.error('Biometric error:', err);
      setLoading(false);
    }
  };

  return (
    <View className="flex-1 bg-[#121212]">
      <StatusBar style="light" />
      <KeyboardAvoidingView 
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        className="flex-1"
      >
        <ScrollView 
          contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', padding: 24 }}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Lottie Header with Animated Scale */}
          <Animated.View 
            className="w-44 h-44 mb-6 items-center justify-center"
            style={{ transform: [{ scale: lottieScale }] }}
          >
            <LottieView
              source={{ uri: 'https://lottie.host/880d603e-63f8-45e0-81f1-325b3400a42e/f1l8U7R6Pj.json' }}
              autoPlay
              loop
              speed={loading ? 2 : 1}
              style={{ width: '100%', height: '100%' }}
            />
          </Animated.View>

          {/* Welcome Text */}
          <View className="items-center mb-8">
            <Text className="text-white text-4xl font-bold tracking-tight text-center" style={{ fontFamily: 'Manrope_Bold' }}>
              DuaSaku
            </Text>
            <Text className="text-white/50 text-base mt-2 text-center" style={{ fontFamily: 'Inter' }}>
              Your futuristic financial companion
            </Text>
          </View>

          {/* Form */}
          <View className="w-full gap-y-5">
            {/* Email Input */}
            <View className="gap-y-2">
              <Text className="text-white/70 text-xs font-semibold uppercase tracking-widest ml-1">Email Address</Text>
              <TextInput
                className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-white text-base"
                placeholder="name@example.com"
                placeholderTextColor="rgba(255,255,255,0.2)"
                value={email}
                onChangeText={(text) => handleTyping(text, setEmail)}
                autoCapitalize="none"
                keyboardType="email-address"
                style={{ fontFamily: 'Inter' }}
              />
              {/* Email Suggestions */}
              <View className="flex-row gap-2 mt-1 px-1">
                {EMAIL_DOMAINS.map((domain) => (
                  <TouchableOpacity 
                    key={domain} 
                    onPress={() => appendDomain(domain)}
                    className="bg-white/5 px-3 py-1.5 rounded-full border border-white/5"
                  >
                    <Text className="text-white/40 text-[10px] font-medium">{domain}</Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>

            {/* Password Input */}
            <View className="gap-y-2">
              <View className="flex-row justify-between items-center ml-1">
                <Text className="text-white/70 text-xs font-semibold uppercase tracking-widest">Password</Text>
                <TouchableOpacity 
                  onPress={handleResetPassword} 
                  activeOpacity={0.7}
                >
                  <Text className="text-on-surface-variant active:text-white text-xs font-medium">Lupa Password?</Text>
                </TouchableOpacity>
              </View>
              <View className="relative">
                <TextInput
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-white text-base pr-14"
                  placeholder="••••••••"
                  placeholderTextColor="rgba(255,255,255,0.2)"
                  value={password}
                  onChangeText={(text) => handleTyping(text, setPassword)}
                  secureTextEntry={!showPassword}
                  style={{ fontFamily: 'Inter' }}
                />
                <TouchableOpacity 
                  onPress={() => setShowPassword(!showPassword)}
                  className="absolute right-4 top-4"
                >
                  {showPassword ? (
                    <EyeOff size={22} color="rgba(255,255,255,0.4)" />
                  ) : (
                    <Eye size={22} color="rgba(255,255,255,0.4)" />
                  )}
                </TouchableOpacity>
              </View>
            </View>

            {/* Sign In Button */}
            <TouchableOpacity 
              className="mt-4 w-full bg-[#8b5cf6] py-5 rounded-2xl items-center shadow-2xl shadow-purple-500/40"
              activeOpacity={0.8}
              onPress={handleSignIn}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text className="text-white text-lg font-bold tracking-tight">Sign In</Text>
              )}
            </TouchableOpacity>

            {/* Biometric Option */}
            {isBiometricAvailable && (
              <View className="items-center mt-4">
                <Text className="text-white/30 text-xs mb-4 uppercase tracking-tighter">Or use biometrics</Text>
                <TouchableOpacity 
                  onPress={() => handleBiometricAuth()}
                  className="w-16 h-16 rounded-full bg-white/5 border border-white/10 items-center justify-center"
                  activeOpacity={0.7}
                >
                  <Fingerprint size={32} color="#8b5cf6" />
                </TouchableOpacity>
              </View>
            )}

            {/* Footer */}
            <View className="flex-row justify-center mt-6 mb-10">
              <Text className="text-white/40">Don&apos;t have an account? </Text>
              <TouchableOpacity onPress={() => router.push('/(auth)/sign-up')}>
                <Text className="text-[#8b5cf6] font-bold">Sign Up</Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </View>
  );
}
