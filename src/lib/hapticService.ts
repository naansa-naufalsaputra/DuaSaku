import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';

/**
 * HapticService — Centralized utility for refined tactile feedback patterns.
 * Designed to provide a premium feel across the app.
 */
export const HapticService = {
  /** Subtle tap for simple interactions like button presses */
  light: () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  },

  /** Stronger feedback for more significant actions like saving or toggling */
  medium: () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    }
  },

  /** Heavy impact for critical or high-stakes actions */
  heavy: () => {
    if (Platform.OS !== 'web') {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    }
  },

  /** Confirmation feedback for successful operations (e.g., transaction saved) */
  success: () => {
    if (Platform.OS !== 'web') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }
  },

  /** Error feedback for failed operations or invalid inputs */
  error: () => {
    if (Platform.OS !== 'web') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  },

  /** Warning feedback for budget alerts or nearing limits */
  warning: () => {
    if (Platform.OS !== 'web') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    }
  },

  /** Custom pattern for transaction success (Quick double-tap feel) */
  transactionSuccess: async () => {
    if (Platform.OS !== 'web') {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      // Optional: Add a light impact shortly after for a "premium" feel
      setTimeout(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light), 100);
    }
  },

  /** Custom pattern for critical budget warning */
  criticalWarning: async () => {
    if (Platform.OS !== 'web') {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      setTimeout(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium), 150);
    }
  },
};
