import React, { useMemo, useState, useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import LottieView from 'lottie-react-native';

/**
 * EmptyState Component - DuaSaku Darkmatter Edition
 * 
 * PROP:
 * - message: Pesan yang ingin ditampilkan
 * - animationAsset: Path ke file JSON atau URL remote
 * 
 * CARA PAKAI ANIMASI LOKAL:
 * 1. Letakkan file .json di `assets/animations/`
 * 2. Import: `import myAnim from '../../assets/animations/empty.json'`
 * 3. Gunakan: `<LottieView source={myAnim} ... />`
 */

import { getCachedLottie } from '../../lib/lottieCache';

interface EmptyStateProps {
  message: string;
  animationAsset?: string;
}

export default function EmptyState({ message, animationAsset }: EmptyStateProps) {
  const currentHour = new Date().getHours();
  const isNight = currentHour >= 19 || currentHour <= 5;
  const [localUri, setLocalUri] = useState<string | null>(null);

  // Dynamic Theme Selection
  const remoteAsset = useMemo(() => {
    if (animationAsset) return animationAsset;
    
    // Default assets based on time (Day/Night)
    return isNight 
      ? "https://assets1.lottiefiles.com/packages/lf20_kyu7aux1.json" // Night themed wallet
      : "https://assets9.lottiefiles.com/packages/lf20_glp9al7u.json"; // Day themed wallet
  }, [animationAsset, isNight]);

  useEffect(() => {
    let isMounted = true;
    getCachedLottie(remoteAsset).then(uri => {
      if (isMounted) setLocalUri(uri);
    });
    return () => { isMounted = false; };
  }, [remoteAsset]);

  return (
    <View style={styles.container}>
      {localUri ? (
        <LottieView
          source={{ uri: localUri }}
          autoPlay
          loop
          style={styles.lottie}
        />
      ) : (
        /* Fallback Visual */
        <View style={styles.placeholder}>
          <Text style={styles.placeholderText}>Lottie Placeholder</Text>
        </View>
      )}

      <Text style={styles.messageText}>
        {message}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
    marginTop: 40,
    width: '100%',
  },
  lottie: {
    width: 180,
    height: 180,
    marginBottom: 16,
  },
  placeholder: {
    width: 180, 
    height: 180, 
    backgroundColor: '#1e1e1e', 
    borderRadius: 8, 
    marginBottom: 16, 
    alignItems: 'center', 
    justifyContent: 'center',
  },
  placeholderText: {
    color: '#a1a1aa', 
    fontSize: 10,
  },
  messageText: {
    color: '#94a3b8',
    fontSize: 15,
    textAlign: 'center',
    fontFamily: 'Manrope_500Medium',
    lineHeight: 22,
  }
});
