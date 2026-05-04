const { withAndroidManifest } = require('@expo/config-plugins');

module.exports = function withManifestToolsReplace(config) {
  return withAndroidManifest(config, (config) => {
    const androidManifest = config.modResults.manifest;
    const app = androidManifest.application[0];

    // Ensure xmlns:tools is present
    if (!androidManifest.$['xmlns:tools']) {
      androidManifest.$['xmlns:tools'] = 'http://schemas.android.com/tools';
    }

    // Add tools:replace="android:allowBackup"
    if (app.$['tools:replace']) {
      if (!app.$['tools:replace'].includes('android:allowBackup')) {
        app.$['tools:replace'] += ',android:allowBackup';
      }
    } else {
      app.$['tools:replace'] = 'android:allowBackup';
    }

    return config;
  });
};
