/**
 * AddBudgetSheet — Bottom sheet for creating/editing monthly budgets
 *
 * Features:
 * - Category picker with emoji icons
 * - Amount input with Rupiah formatting
 * - Edit mode (pre-fills existing budget data)
 * - Darkmatter glassmorphism design
 */

import React, { useState, useMemo, forwardRef, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
  TextInput,
  ScrollView,
} from 'react-native';
import BottomSheet, { BottomSheetView } from '@gorhom/bottom-sheet';
import { upsertBudget, getCurrentMonthYear } from '../lib/budgetService';
import { useCategoryStore } from '../store/useCategoryStore';
import { EmojiPicker } from './ui/EmojiPicker';
import { Plus, X, Check, Target } from 'lucide-react-native';
import * as Haptics from 'expo-haptics';
import { useUserStore } from '../store/useUserStore';

interface AddBudgetSheetProps {
  onClose?: () => void;
  onSaved?: () => void;
  editData?: {
    category: string;
    budget_amount: number;
  } | null;
}

const AddBudgetSheet = forwardRef<BottomSheet, AddBudgetSheetProps>(
  ({ onClose, onSaved, editData }, ref) => {
    const { session } = useUserStore();
    const userId = session?.user?.id;
    const { getAllCategories, addCustomCategory, setCategoryTarget, categoryTargets } = useCategoryStore();
    const categories = getAllCategories();

    const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
    const [amount, setAmount] = useState('');
    const [targetAmount, setTargetAmount] = useState('');
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);
    
    // Custom category creation state
    const [isCreatingCustom, setIsCreatingCustom] = useState(false);
    const [customName, setCustomName] = useState('');
    const [customEmoji, setCustomEmoji] = useState('📦');

    const snapPoints = useMemo(() => [isCreatingCustom ? '70%' : '55%'], [isCreatingCustom]);

    // Pre-fill when editing
    useEffect(() => {
      if (editData) {
        setSelectedCategory(editData.category);
        setAmount(String(editData.budget_amount));
        setTargetAmount(categoryTargets[editData.category] ? String(categoryTargets[editData.category]) : '');
      } else {
        setSelectedCategory(null);
        setAmount('');
        setTargetAmount('');
      }
      setError(null);
    }, [editData, categoryTargets]);

    const handleSheetChanges = useCallback(
      (index: number) => {
        if (index === -1) {
          onClose?.();
          setSelectedCategory(null);
          setAmount('');
          setError(null);
        }
      },
      [onClose]
    );

    const formatDisplayAmount = (val: string): string => {
      const num = parseInt(val.replace(/\D/g, ''), 10);
      if (isNaN(num)) return '';
      return num.toLocaleString('id-ID');
    };

    const handleAmountChange = (text: string) => {
      // Strip non-digits, keep raw number
      const raw = text.replace(/\D/g, '');
      setAmount(raw);
    };

    const handleSave = async () => {
      let categoryToSave = selectedCategory;

      if (isCreatingCustom) {
        if (!customName.trim()) {
          setError('Masukkan nama kategori');
          return;
        }
        addCustomCategory({
          id: Date.now().toString(),
          name: customName.trim(),
          emoji: customEmoji,
          color: '#8b5cf6' // Default purple for custom
        });
        categoryToSave = customName.trim();
      }

      if (!categoryToSave) {
        setError('Pilih kategori dulu');
        return;
      }

      const numAmount = parseInt(amount, 10);
      if (!numAmount || numAmount <= 0) {
        setError('Masukkan nominal yang valid');
        return;
      }

      if (!userId) {
        setError('User not authenticated');
        return;
      }

      setSaving(true);
      setError(null);

      try {
        const numTarget = targetAmount ? parseInt(targetAmount, 10) : undefined;

        // 1. Save Category Target if provided
        if (numTarget !== undefined) {
          setCategoryTarget(categoryToSave, numTarget);
        }

        // 2. Upsert Budget to Supabase
        const result = await upsertBudget(userId, categoryToSave, numAmount);

        if (result.success) {
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
          onSaved?.();
          resetAndClose();
        } else {
          setError(result.error || 'Gagal menyimpan budget');
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
        }
      } catch (err) {
        console.error('[AddBudgetSheet] Save error:', err);
        setError('Terjadi kesalahan sistem');
      } finally {
        setSaving(false);
      }
    };

    const resetAndClose = () => {
      setIsCreatingCustom(false);
      setCustomName('');
      setCustomEmoji('📦');
      setSelectedCategory(null);
      setAmount('');
      setError(null);
      (ref as any)?.current?.close();
    };

    const monthLabel = (() => {
      const my = getCurrentMonthYear();
      const [y, m] = my.split('-');
      const months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ];
      return `${months[parseInt(m, 10) - 1]} ${y}`;
    })();

    return (
      <BottomSheet
        ref={ref}
        index={-1}
        snapPoints={snapPoints}
        enablePanDownToClose
        onChange={handleSheetChanges}
        handleIndicatorStyle={styles.indicator}
        backgroundStyle={styles.sheetBackground}
      >
        <BottomSheetView style={styles.sheetContent}>
          {/* Header */}
          <View style={styles.header}>
            <View>
              <Text style={styles.headerTitle}>
                {isCreatingCustom ? 'Kategori Kustom' : editData ? 'Edit Budget' : 'Tambah Budget'}
              </Text>
              <Text style={styles.headerSubtitle}>
                {monthLabel}
              </Text>
            </View>
            <TouchableOpacity onPress={resetAndClose} style={styles.closeButton}>
              <X color="#71717a" size={18} />
            </TouchableOpacity>
          </View>

          {isCreatingCustom ? (
            <View>
              <EmojiPicker 
                selectedEmoji={customEmoji} 
                onSelect={(e) => {
                  setCustomEmoji(e);
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                }} 
              />
              
              <Text style={styles.inputLabel}>
                Nama Kategori
              </Text>
              <TextInput
                style={styles.textInput}
                placeholder="Contoh: Gym, Kursus, dll"
                placeholderTextColor="#3f3f46"
                value={customName}
                onChangeText={setCustomName}
              />
              
              <TouchableOpacity 
                onPress={() => setIsCreatingCustom(false)}
                style={styles.cancelButton}
              >
                <Text style={styles.cancelText}>Batal, pilih yang ada</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <>
              {/* Category Grid */}
              <View style={styles.categoryHeader}>
                <Text style={styles.inputLabel}>
                  Pilih Kategori
                </Text>
                <TouchableOpacity 
                  onPress={() => {
                    setIsCreatingCustom(true);
                    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                  }}
                  style={styles.customCatButton}
                >
                  <Plus color="#10b981" size={14} />
                  <Text style={styles.customCatText}>Kustom</Text>
                </TouchableOpacity>
              </View>
              
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                style={styles.categoryScroll}
                contentContainerStyle={styles.categoryScrollContent}
              >
                {categories.map((cat) => {
                  const isSelected = selectedCategory === cat.key;
                  return (
                    <TouchableOpacity
                      key={cat.key}
                      onPress={() => {
                        setSelectedCategory(cat.key);
                        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      }}
                      style={[
                        styles.categoryChip,
                        {
                          backgroundColor: isSelected ? cat.color + '20' : '#09090b',
                          borderColor: isSelected ? cat.color : '#27272a',
                        }
                      ]}
                    >
                      <Text style={styles.emojiText}>{cat.emoji}</Text>
                      <Text
                        style={[
                          styles.categoryLabel,
                          {
                            fontFamily: isSelected ? 'Inter_SemiBold' : 'Inter',
                            color: isSelected ? cat.color : '#a1a1aa',
                          }
                        ]}
                      >
                        {cat.label}
                      </Text>
                      {isSelected && <Check color={cat.color} size={16} />}
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            </>
          )}

          {/* Amount Input */}
          <Text style={styles.inputLabel}>
            Limit Bulanan
          </Text>
          <View style={styles.amountInputContainer}>
            <Text style={styles.currencyPrefix}>Rp</Text>
            <TextInput
              style={styles.amountInput}
              placeholder="0"
              placeholderTextColor="#3f3f46"
              keyboardType="numeric"
              value={amount ? formatDisplayAmount(amount) : ''}
              onChangeText={handleAmountChange}
            />
          </View>

          {/* Quick Amount Chips */}
          <View style={styles.quickAmountGrid}>
            {[200000, 500000, 1000000, 2000000].map((val) => (
              <TouchableOpacity
                key={val}
                onPress={() => {
                  setAmount(String(val));
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                }}
                style={[
                  styles.quickChip,
                  { borderColor: amount === String(val) ? '#10b981' : '#27272a' }
                ]}
              >
                <Text
                  style={[
                    styles.quickChipText,
                    { color: amount === String(val) ? '#10b981' : '#71717a' }
                  ]}
                >
                  {val >= 1000000 ? `${val / 1000000}jt` : `${val / 1000}rb`}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Target Tabungan (Optional) */}
          <Text style={[styles.inputLabel, { marginTop: 12 }]}>
            Target Tabungan (Opsional)
          </Text>
          <View style={styles.amountInputContainer}>
            <Text style={styles.currencyPrefix}>Rp</Text>
            <TextInput
              style={[styles.amountInput, { color: '#10b981' }]}
              placeholder="0"
              placeholderTextColor="#3f3f46"
              keyboardType="numeric"
              value={targetAmount ? formatDisplayAmount(targetAmount) : ''}
              onChangeText={(t) => setTargetAmount(t.replace(/\D/g, ''))}
            />
          </View>
          
          <View style={styles.quickAmountGrid}>
            {[100000, 250000, 500000, 1000000].map((val) => (
              <TouchableOpacity
                key={val}
                onPress={() => {
                  setTargetAmount(String(val));
                  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                }}
                style={[
                  styles.quickChip,
                  { borderColor: targetAmount === String(val) ? '#10b981' : '#27272a' }
                ]}
              >
                <Text style={[
                  styles.quickChipText,
                  { color: targetAmount === String(val) ? '#10b981' : '#71717a' }
                ]}>
                  {val >= 1000000 ? `${val / 1000000}jt` : `${val / 1000}rb`}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          {/* Error */}
          {error && (
            <Text style={styles.errorText}>
              {error}
            </Text>
          )}

          {/* Save Button */}
          <TouchableOpacity
            onPress={handleSave}
            disabled={saving}
            style={[
              styles.saveButton,
              { backgroundColor: saving ? '#27272a' : '#10b981' }
            ]}
          >
            {saving ? (
              <ActivityIndicator size="small" color="#fafafa" />
            ) : (
              <>
                <Target color="#09090b" size={20} />
                <Text style={styles.saveButtonText}>
                  {editData ? 'Simpan Perubahan' : 'Pasang Budget'}
                </Text>
              </>
            )}
          </TouchableOpacity>
        </BottomSheetView>
      </BottomSheet>
    );
  }
);

const styles = RNStyleSheet.create({
  indicator: {
    backgroundColor: '#27272a',
    width: 48,
    marginTop: 4
  },
  sheetBackground: {
    backgroundColor: '#18181b',
    borderRadius: 24,
    borderWidth: 1,
    borderColor: '#27272a',
  },
  sheetContent: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 8
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  headerTitle: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 20,
    color: '#fafafa'
  },
  headerSubtitle: {
    fontFamily: 'Inter',
    fontSize: 13,
    color: '#71717a',
    marginTop: 2
  },
  closeButton: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: '#09090b',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#27272a',
  },
  inputLabel: {
    fontFamily: 'Inter_SemiBold',
    fontSize: 12,
    color: '#71717a',
    textTransform: 'uppercase',
    letterSpacing: 1.5,
    marginBottom: 10,
  },
  textInput: {
    backgroundColor: '#09090b',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#27272a',
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontFamily: 'Inter_Medium',
    fontSize: 16,
    color: '#fafafa',
    marginBottom: 20
  },
  cancelButton: {
    marginBottom: 12,
    alignItems: 'center'
  },
  cancelText: {
    color: '#71717a',
    fontSize: 13,
    fontFamily: 'Inter'
  },
  categoryHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10
  },
  customCatButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4
  },
  customCatText: {
    color: '#10b981',
    fontSize: 12,
    fontFamily: 'Inter_SemiBold'
  },
  categoryScroll: {
    marginBottom: 20,
    flexGrow: 0
  },
  categoryScrollContent: {
    gap: 8
  },
  categoryChip: {
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 16,
    borderWidth: 1.5,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  emojiText: {
    fontSize: 18
  },
  categoryLabel: {
    fontSize: 14,
  },
  amountInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#09090b',
    borderRadius: 20,
    borderWidth: 1,
    borderColor: '#27272a',
    paddingHorizontal: 20,
    paddingVertical: 14,
    marginBottom: 12,
  },
  currencyPrefix: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 18,
    color: '#52525b',
    marginRight: 8,
  },
  amountInput: {
    flex: 1,
    fontFamily: 'Manrope_700Bold',
    fontSize: 24,
    color: '#fafafa',
    padding: 0,
  },
  quickAmountGrid: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 20
  },
  quickChip: {
    flex: 1,
    paddingVertical: 8,
    borderRadius: 12,
    backgroundColor: '#09090b',
    borderWidth: 1,
    alignItems: 'center',
  },
  quickChipText: {
    fontFamily: 'Inter_SemiBold',
    fontSize: 12,
  },
  errorText: {
    fontFamily: 'Inter',
    fontSize: 13,
    color: '#ef4444',
    marginBottom: 12,
    textAlign: 'center',
  },
  saveButton: {
    paddingVertical: 16,
    borderRadius: 20,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  saveButtonText: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 16,
    color: '#09090b',
  }
});

AddBudgetSheet.displayName = 'AddBudgetSheet';

export default AddBudgetSheet;
