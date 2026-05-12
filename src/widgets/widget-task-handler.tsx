import React from 'react';
import { requestWidgetUpdate } from 'react-native-android-widget';
import { DuaSakuWidget } from './DuaSakuWidget';

export async function updateDuaSakuWidget() {
  // Try to fetch values from MMKV store
  // Since we don't have access to the react hook here, we could use standard store fetch, 
  // but let's mock it for the setup if MMKV isn't fully ready here.
  let currentAmount = 0;
  let targetAmount = 5000000;
  let budgetName = 'Budget Bulan Ini';

  try {
    const { MMKV } = require('react-native-mmkv');
    const storage = new MMKV({ id: 'settings-storage', encryptionKey: process.env.EXPO_PUBLIC_MMKV_ENCRYPTION_KEY || 'DuaSaku-BankGrade-SecureKey-2026' });
    const settingsStr = storage.getString('settings-storage');
    if (settingsStr) {
      const parsed = JSON.parse(settingsStr);
      if (parsed?.state?.financialGoal) {
        currentAmount = parsed.state.financialGoal.currentAmount || 0;
        targetAmount = parsed.state.financialGoal.targetAmount || 0;
        budgetName = parsed.state.financialGoal.name || budgetName;
      }
    }
  } catch (err) {
    console.warn('[Widget] Failed to read MMKV storage:', err);
  }

  try {
    await requestWidgetUpdate({
      widgetName: 'DuaSakuWidget',
      renderWidget: () => (
        <DuaSakuWidget 
          currentAmount={currentAmount} 
          targetAmount={targetAmount} 
          budgetName={budgetName} 
        />
      ),
    });
  } catch (error) {
    console.warn('[Widget] Update failed:', error);
  }
}
