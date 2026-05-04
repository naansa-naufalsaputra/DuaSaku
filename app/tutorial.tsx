import React, { useState, useRef } from 'react';
import { View, Text, TouchableOpacity, Dimensions, FlatList } from 'react-native';
import LottieView from 'lottie-react-native';
import { router } from 'expo-router';
import { useSettingsStore } from '../src/store/useSettingsStore';
import { useHaptic } from '../src/hooks/useHaptic';
import { LinearGradient } from 'expo-linear-gradient';
import { ChevronRight, Sparkles } from 'lucide-react-native';

const { width, height } = Dimensions.get('window');

interface TutorialSlide {
  id: string;
  title: string;
  description: string;
  lottie: string;
  colors: [string, string, ...string[]];
}

const SLIDES: TutorialSlide[] = [
  {
    id: '1',
    title: 'Halo, Aku DuaSaku!',
    description: 'Asisten finansial pribadimu yang siap membantu mengelola uang dengan cerdas dan menyenangkan.',
    lottie: 'https://lottie.host/819d44c8-3c5e-42c2-8419-867c2957f864/D3m6Jv2X1R.json', // Welcome robot
    colors: ['#1e293b', '#0f172a']
  },
  {
    id: '2',
    title: 'Catat Lewat Suara',
    description: 'Cukup bicara "Tadi beli kopi 20 ribu", dan aku akan otomatis mencatatnya untukmu. Praktis kan?',
    lottie: 'https://lottie.host/9e4d0752-1678-4395-8149-6e3e55389656/Z8B9fC6D6V.json', // Voice/Audio waves
    colors: ['#1e1b4b', '#0f172a']
  },
  {
    id: '3',
    title: 'Analisis Masa Depan',
    description: 'Aku bisa memprediksi sisa saldomu di akhir bulan dan memberi saran anggaran agar kamu tetap hemat.',
    lottie: 'https://lottie.host/6e2a9e3e-4b6d-4c6e-8d6f-7e6d5c4b3a21/insight.json', // Chart/Insights
    colors: ['#164e63', '#0f172a']
  },
  {
    id: '4',
    title: 'Kumpulkan Lencana',
    description: 'Semakin disiplin kamu mencatat, semakin tinggi skor kesehatan finansialmu dan lencana keren yang kamu dapat!',
    lottie: 'https://lottie.host/a8b9c0d1-e2f3-4a5b-6c7d-8e9f0a1b2c3d/badge.json', // Trophy/Medal
    colors: ['#14532d', '#0f172a']
  }
];

export default function TutorialScreen() {
  const [currentIndex, setCurrentIndex] = useState(0);
  const flatListRef = useRef<FlatList>(null);
  const { hapticMedium, hapticSuccess } = useHaptic();
  const setHasCompletedTutorial = useSettingsStore(state => state.setHasCompletedTutorial);

  const handleNext = () => {
    if (currentIndex < SLIDES.length - 1) {
      flatListRef.current?.scrollToIndex({ index: currentIndex + 1 });
      hapticMedium();
    } else {
      hapticSuccess();
      setHasCompletedTutorial(true);
      router.replace('/(tabs)');
    }
  };

  const renderItem = ({ item }: any) => (
    <View style={{ width, height }} className="items-center justify-center px-10">
      <View className="w-full h-72 items-center justify-center mb-10">
        <LottieView
          source={{ uri: item.lottie }}
          autoPlay
          loop
          style={{ width: 300, height: 300 }}
        />
      </View>
      <Text className="text-white text-3xl font-bold text-center mb-4" style={{ fontFamily: 'Manrope_800ExtraBold' }}>
        {item.title}
      </Text>
      <Text className="text-slate-400 text-lg text-center leading-7">
        {item.description}
      </Text>
    </View>
  );

  return (
    <View className="flex-1 bg-[#020617]">
      <LinearGradient
        colors={SLIDES[currentIndex].colors}
        style={{ position: 'absolute', width, height, opacity: 0.5 }}
      />
      
      <FlatList
        ref={flatListRef}
        data={SLIDES}
        renderItem={renderItem}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={(e) => {
          const index = Math.round(e.nativeEvent.contentOffset.x / width);
          setCurrentIndex(index);
        }}
        keyExtractor={(item) => item.id}
      />

      {/* Footer */}
      <View className="absolute bottom-16 left-0 right-0 px-10 items-center">
        {/* Pagination Dots */}
        <View className="flex-row gap-2 mb-10">
          {SLIDES.map((_, i) => (
            <View 
              key={i} 
              className={`h-2 rounded-full ${i === currentIndex ? 'w-8 bg-purple-500' : 'w-2 bg-slate-700'}`} 
            />
          ))}
        </View>

        <TouchableOpacity 
          className="w-full bg-purple-600 h-16 rounded-[24px] flex-row items-center justify-center gap-2 shadow-2xl shadow-purple-600/50"
          onPress={handleNext}
        >
          <Text className="text-white font-bold text-lg">
            {currentIndex === SLIDES.length - 1 ? 'Mulai Sekarang' : 'Lanjutkan'}
          </Text>
          {currentIndex === SLIDES.length - 1 ? (
            <Sparkles color="white" size={20} />
          ) : (
            <ChevronRight color="white" size={20} />
          )}
        </TouchableOpacity>
        
        {currentIndex < SLIDES.length - 1 && (
          <TouchableOpacity 
            className="mt-6"
            onPress={() => {
              setHasCompletedTutorial(true);
              router.replace('/(tabs)');
            }}
          >
            <Text className="text-slate-500 font-medium">Lewati Tutorial</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}
