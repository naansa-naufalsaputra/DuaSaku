import "expo-router/entry";
import { AppRegistry } from 'react-native';
import { notificationService } from './src/lib/notificationService';

// Registrasi Headless Task untuk Background Notification Listener
AppRegistry.registerHeadlessTask(
  'RNAndroidNotificationListenerHeadlessJs',
  () => notificationService
);

// Register Widget Task Handler
import { registerWidgetTaskHandler } from 'react-native-android-widget';
import { updateDuaSakuWidget } from './src/widgets/widget-task-handler';

registerWidgetTaskHandler(updateDuaSakuWidget);
