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
import { Eye, EyeOff, User, Mail, Lock } from 'lucide-react-native';
import { supabase } from '../../src/lib/supabase';
import Toast from 'react-native-toast-message';
import { GoogleIcon } from '../../src/components/GoogleIcon';
import { makeRedirectUri } from 'expo-auth-session';

const EMAIL_DOMAINS = ['@gmail.com', '@yahoo.com', '@outlook.com'];

export default function SignUpScreen() {
  const router = useRouter();
  
  // States
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  
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

  // Auth Logic: Sign Up
  const handleSignUp = async () => {
    if (!email || !password || !fullName) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Toast.show({
        type: 'error',
        text1: 'Required Fields',
        text2: 'Please fill in name, email, and password.',
      });
      return;
    }

    setLoading(true);
    const { error } = await supabase.auth.signUp({ 
      email, 
      password,
      options: {
        data: {
          full_name: fullName,
          display_name: fullName,
        }
      }
    });
    
    setLoading(false);
    if (error) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Toast.show({
        type: 'error',
        text1: 'Registration Failed',
        text2: error.message,
      });
    } else {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Toast.show({
        type: 'success',
        text1: 'Welcome!',
        text2: 'Please check your email to verify your account.',
      });
      // Optionally redirect to sign-in or wait for verification
    }
  };

  const handleGoogleSignIn = async () => {
    setLoading(true);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: makeRedirectUri({ scheme: 'duasaku' }),
      },
    });
    setLoading(false);
    if (error) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      Toast.show({ type: 'error', text1: 'Google Sign In Failed', text2: error.message });
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
          contentContainerStyle={{ flexGrow: 1, padding: 24 }}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* Lottie Header */}
          <Animated.View 
            className="w-40 h-40 mt-10 mb-4 items-center justify-center self-center"
            style={{ transform: [{ scale: lottieScale }] }}
          >
            <LottieView
              source={{ uri: 'https://lottie.host/6ad3950b-70e0-4740-9e32-21a48c4a5c54/wI14F7t5oU.json' }}
              autoPlay
              loop
              speed={loading ? 2 : 1}
              style={{ width: '100%', height: '100%' }}
            />
          </Animated.View>

          {/* Header Text */}
          <View className="items-center mb-8">
            <Text className="text-white text-3xl font-bold tracking-tight text-center" style={{ fontFamily: 'Manrope_Bold' }}>
              Join DuaSaku
            </Text>
            <Text className="text-white/50 text-base mt-2 text-center" style={{ fontFamily: 'Inter' }}>
              Start your journey to financial freedom
            </Text>
          </View>

          {/* Form */}
          <View className="w-full gap-y-5">
            {/* Full Name Input */}
            <View className="gap-y-2">
              <Text className="text-white/70 text-xs font-semibold uppercase tracking-widest ml-1">Full Name</Text>
              <View className="relative">
                <TextInput
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-white text-base pl-12"
                  placeholder="John Doe"
                  placeholderTextColor="rgba(255,255,255,0.2)"
                  value={fullName}
                  onChangeText={(text) => handleTyping(text, setFullName)}
                  style={{ fontFamily: 'Inter' }}
                />
                <View className="absolute left-4 top-4">
                  <User size={20} color="rgba(255,255,255,0.3)" />
                </View>
              </View>
            </View>

            {/* Email Input */}
            <View className="gap-y-2">
              <Text className="text-white/70 text-xs font-semibold uppercase tracking-widest ml-1">Email Address</Text>
              <View className="relative">
                <TextInput
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-white text-base pl-12"
                  placeholder="name@example.com"
                  placeholderTextColor="rgba(255,255,255,0.2)"
                  value={email}
                  onChangeText={(text) => handleTyping(text, setEmail)}
                  autoCapitalize="none"
                  keyboardType="email-address"
                  style={{ fontFamily: 'Inter' }}
                />
                <View className="absolute left-4 top-4">
                  <Mail size={20} color="rgba(255,255,255,0.3)" />
                </View>
              </View>
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
              <Text className="text-white/70 text-xs font-semibold uppercase tracking-widest ml-1">Password</Text>
              <View className="relative">
                <TextInput
                  className="w-full bg-white/5 border border-white/10 rounded-2xl px-5 py-4 text-white text-base pl-12 pr-14"
                  placeholder="••••••••"
                  placeholderTextColor="rgba(255,255,255,0.2)"
                  value={password}
                  onChangeText={(text) => handleTyping(text, setPassword)}
                  secureTextEntry={!showPassword}
                  style={{ fontFamily: 'Inter' }}
                />
                <View className="absolute left-4 top-4">
                  <Lock size={20} color="rgba(255,255,255,0.3)" />
                </View>
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

            {/* Sign Up Button */}
            <TouchableOpacity 
              className="mt-4 w-full bg-[#8b5cf6] py-5 rounded-2xl items-center shadow-2xl shadow-purple-500/40"
              activeOpacity={0.8}
              onPress={handleSignUp}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Text className="text-white text-lg font-bold tracking-tight">Create Account</Text>
              )}
            </TouchableOpacity>

            <View className="flex-row items-center my-2">
              <View className="flex-1 h-[1px] bg-white/10" />
              <Text className="text-white/20 text-xs font-bold px-4">OR</Text>
              <View className="flex-1 h-[1px] bg-white/10" />
            </View>

            {/* Google Sign In */}
            <TouchableOpacity 
              className="w-full bg-white py-4 rounded-2xl items-center flex-row justify-center space-x-3"
              activeOpacity={0.9}
              onPress={handleGoogleSignIn}
              disabled={loading}
            >
              <GoogleIcon size={20} />
              <Text className="text-black text-base font-semibold ml-2">Continue with Google</Text>
            </TouchableOpacity>

            {/* Footer */}
            <View className="flex-row justify-center mt-6 mb-10">
              <Text className="text-white/40">Already have an account? </Text>
              <TouchableOpacity onPress={() => router.push('/(auth)/sign-in')}>
                <Text className="text-[#8b5cf6] font-bold">Sign In</Text>
              </TouchableOpacity>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </View>
  );
}
