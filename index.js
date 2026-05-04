import "expo-router/entry";
import { AppRegistry } from 'react-native';
import { notificationService } from './src/lib/notificationService';

// Registrasi Headless Task untuk Background Notification Listener
AppRegistry.registerHeadlessTask(
  'RNAndroidNotificationListenerHeadlessJs',
  () => notificationService
);
