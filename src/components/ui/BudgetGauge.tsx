import React, { useEffect, useState, useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import LottieView from 'lottie-react-native';
import { getCachedLottie } from '../../lib/lottieCache';

interface BudgetGaugeProps {
  percentage: number;
  label: string;
  amount: string;
}

export default function BudgetGauge({ percentage, label, amount }: BudgetGaugeProps) {
  const [localUri, setLocalUri] = useState<string | null>(null);

  // Pick animation based on severity
  const animationUrl = useMemo(() => {
    if (percentage >= 100) return 'https://assets8.lottiefiles.com/private_files/lf30_8as99f6u.json'; // Red alert
    if (percentage >= 80) return 'https://assets5.lottiefiles.com/packages/lf20_S6v94y.json'; // Yellow warning
    return 'https://assets2.lottiefiles.com/packages/lf20_tiviy6ab.json'; // Green progress
  }, [percentage]);

  useEffect(() => {
    let isMounted = true;
    getCachedLottie(animationUrl).then(uri => {
      if (isMounted) setLocalUri(uri);
    });
    return () => { isMounted = false; };
  }, [animationUrl]);

  return (
    <View style={styles.container}>
      <View style={styles.lottieWrapper}>
        {localUri && (
          <LottieView
            source={{ uri: localUri }}
            autoPlay
            loop={percentage < 100} // Loop only if not alert
            style={styles.lottie}
          />
        )}
        <View style={styles.textOverlay}>
          <Text style={styles.percentageText}>{percentage}%</Text>
        </View>
      </View>
      <View style={styles.info}>
        <Text style={styles.label}>{label}</Text>
        <Text style={styles.amount}>{amount}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.03)',
    borderRadius: 20,
    padding: 12,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.05)',
  },
  lottieWrapper: {
    width: 60,
    height: 60,
    alignItems: 'center',
    justifyContent: 'center',
  },
  lottie: {
    width: 100,
    height: 100,
    position: 'absolute',
  },
  textOverlay: {
    position: 'absolute',
    alignItems: 'center',
    justifyContent: 'center',
  },
  percentageText: {
    color: '#fafafa',
    fontSize: 10,
    fontFamily: 'Manrope_700Bold',
  },
  info: {
    marginLeft: 16,
    flex: 1,
  },
  label: {
    color: '#a1a1aa',
    fontSize: 12,
    fontFamily: 'Manrope_500Medium',
    marginBottom: 2,
  },
  amount: {
    color: '#fafafa',
    fontSize: 14,
    fontFamily: 'Manrope_700Bold',
  },
});
