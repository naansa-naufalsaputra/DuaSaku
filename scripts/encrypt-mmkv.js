const fs = require('fs');
const files = [
  'src/store/useUserStore.ts',
  'src/store/useSettingsStore.ts',
  'src/store/useGamificationStore.ts',
  'src/lib/storage.ts',
  'src/lib/offlineSync.ts',
  'src/lib/notificationService.ts',
  'src/lib/geofencing.ts',
  'src/lib/conflictResolution.ts',
  'src/lib/backgroundTasks.ts',
  'src/lib/cleanupService.ts'
];
const enc = "encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026'";

for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  content = content.replace(/new MMKV\(\)/g, `new MMKV({ ${enc} })`);
  content = content.replace(/new MMKV\(\{([^}]*)\}\)/g, (match, p1) => {
    if (p1.includes('encryptionKey')) return match;
    return `new MMKV({ ${p1.trim()},\n  ${enc} })`;
  });
  fs.writeFileSync(file, content);
}
console.log('All MMKV instances encrypted!');
