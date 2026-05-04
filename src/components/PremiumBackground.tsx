import React, { useEffect } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import Animated, { 
  useSharedValue, 
  useAnimatedStyle, 
  withRepeat, 
  withTiming, 
  Easing,
  interpolate
} from 'react-native-reanimated';
import { LinearGradient } from 'expo-linear-gradient';

const { width, height } = Dimensions.get('window');

export const PremiumBackground = () => {
  const move1 = useSharedValue(0);
  const move2 = useSharedValue(0);

  useEffect(() => {
    move1.value = withRepeat(
      withTiming(1, { duration: 15000, easing: Easing.inOut(Easing.sin) }),
      -1,
      true
    );
    move2.value = withRepeat(
      withTiming(1, { duration: 20000, easing: Easing.inOut(Easing.sin) }),
      -1,
      true
    );
  }, [move1, move2]);

  const orb1Style = useAnimatedStyle(() => ({
    transform: [
      { translateX: interpolate(move1.value, [0, 1], [-width * 0.2, width * 0.6]) },
      { translateY: interpolate(move1.value, [0, 1], [height * 0.1, height * 0.4]) },
      { scale: interpolate(move1.value, [0, 1], [1, 1.5]) }
    ],
    opacity: interpolate(move1.value, [0, 1], [0.03, 0.08])
  }));

  const orb2Style = useAnimatedStyle(() => ({
    transform: [
      { translateX: interpolate(move2.value, [0, 1], [width * 0.7, width * 0.1]) },
      { translateY: interpolate(move2.value, [0, 1], [height * 0.6, height * 0.2]) },
      { scale: interpolate(move2.value, [0, 1], [1.2, 0.8]) }
    ],
    opacity: interpolate(move2.value, [0, 1], [0.04, 0.1])
  }));

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <View style={[styles.background, { backgroundColor: '#020617' }]} />
      
      {/* Animated Orbs */}
      <Animated.View style={[styles.orb, orb1Style, { backgroundColor: '#7c3aed' }]} />
      <Animated.View style={[styles.orb, orb2Style, { backgroundColor: '#10b981' }]} />
      
      {/* Subtle Noise/Overlay */}
      <LinearGradient
        colors={['rgba(2,6,23,0)', 'rgba(2,6,23,0.8)']}
        style={StyleSheet.absoluteFill}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  background: {
    ...StyleSheet.absoluteFillObject,
  },
  orb: {
    position: 'absolute',
    width: width * 0.8,
    height: width * 0.8,
    borderRadius: width * 0.4,
    filter: 'blur(80px)',
  }
});
