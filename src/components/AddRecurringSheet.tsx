/**
 * AddRecurringSheet — Bottom sheet to create recurring transaction templates
 *
 * Darkmatter theme, glassmorphism styling.
 * Supports daily, weekly, monthly frequencies with day selectors.
 */

import React, { useMemo, forwardRef, useCallback, useState } from 'react';
import { View, Text, TouchableOpacity, ActivityIndicator, ScrollView, Alert } from 'react-native';
import BottomSheet, { BottomSheetTextInput, BottomSheetView } from '@gorhom/bottom-sheet';
import { Repeat, Calendar, DollarSign, Tag } from 'lucide-react-native';
import { BUDGET_CATEGORIES } from '../lib/budgetService';
import {
  createRecurring,
  type RecurrenceFrequency,
  type CreateRecurringInput,
} from '../lib/recurringService';

interface AddRecurringSheetProps {
  onClose?: () => void;
  onCreated?: () => void;
}

const FREQUENCY_OPTIONS: { key: RecurrenceFrequency; label: string; emoji: string }[] = [
  { key: 'daily', label: 'Harian', emoji: '📅' },
  { key: 'weekly', label: 'Mingguan', emoji: '📆' },
  { key: 'monthly', label: 'Bulanan', emoji: '🗓️' },
];

const DAY_NAMES = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

const QUICK_TEMPLATES = [
  { title: 'Kos/Kontrakan', amount: 0, category: 'Utilities', frequency: 'monthly' as RecurrenceFrequency, dayOfMonth: 1 },
  { title: 'Paket Data', amount: 0, category: 'Utilities', frequency: 'monthly' as RecurrenceFrequency, dayOfMonth: 1 },
  { title: 'Gaji', amount: 0, category: 'Income', frequency: 'monthly' as RecurrenceFrequency, dayOfMonth: 25 },
  { title: 'Langganan Spotify', amount: 54990, category: 'Entertainment', frequency: 'monthly' as RecurrenceFrequency, dayOfMonth: 1 },
];

const AddRecurringSheet = forwardRef<BottomSheet, AddRecurringSheetProps>(
  ({ onClose, onCreated }, ref) => {
    const snapPoints = useMemo(() => ['85%'], []);
    const [title, setTitle] = useState('');
    const [amount, setAmount] = useState('');
    const [category, setCategory] = useState('Food');
    const [type, setType] = useState<'expense' | 'income'>('expense');
    const [frequency, setFrequency] = useState<RecurrenceFrequency>('monthly');
    const [dayOfWeek, setDayOfWeek] = useState(1); // Monday
    const [dayOfMonth, setDayOfMonth] = useState(1);
    const [saving, setSaving] = useState(false);

    const handleSheetChanges = useCallback(
      (index: number) => {
        if (index === -1) onClose?.();
      },
      [onClose]
    );

    const resetForm = () => {
      setTitle('');
      setAmount('');
      setCategory('Food');
      setType('expense');
      setFrequency('monthly');
      setDayOfWeek(1);
      setDayOfMonth(1);
    };

    const handleSave = async () => {
      const parsedAmount = parseFloat(amount.replace(/[.,]/g, ''));
      if (!title.trim()) {
        Alert.alert('Error', 'Nama transaksi wajib diisi');
        return;
      }
      if (!parsedAmount || parsedAmount <= 0) {
        Alert.alert('Error', 'Nominal harus lebih dari 0');
        return;
      }

      setSaving(true);
      try {
        const input: CreateRecurringInput = {
          title: title.trim(),
          amount: parsedAmount,
          category,
          type,
          frequency,
          day_of_week: frequency === 'weekly' ? dayOfWeek : undefined,
          day_of_month: frequency === 'monthly' ? dayOfMonth : undefined,
        };

        const result = await createRecurring(input);
        if (result.success) {
          resetForm();
          onCreated?.();
          (ref as any).current?.close();
        } else {
          Alert.alert('Error', result.error || 'Gagal menyimpan');
        }
      } catch (err) {
        console.error('[AddRecurring] Error:', err);
        Alert.alert('Error', 'Terjadi kesalahan');
      } finally {
        setSaving(false);
      }
    };

    const handleTemplate = (tmpl: typeof QUICK_TEMPLATES[0]) => {
      setTitle(tmpl.title);
      if (tmpl.amount > 0) setAmount(String(tmpl.amount));
      setCategory(tmpl.category);
      setType(tmpl.category === 'Income' ? 'income' : 'expense');
      setFrequency(tmpl.frequency);
      if (tmpl.dayOfMonth) setDayOfMonth(tmpl.dayOfMonth);
    };

    return (
      <BottomSheet
        ref={ref}
        index={-1}
        snapPoints={snapPoints}
        enablePanDownToClose
        onChange={handleSheetChanges}
        handleIndicatorStyle={{ backgroundColor: '#27272a', width: 48, marginTop: 4 }}
        backgroundStyle={{
          backgroundColor: '#18181b',
          borderRadius: 24,
          borderWidth: 1,
          borderColor: '#27272a',
        }}
      >
        <BottomSheetView style={{ flex: 1 }}>
          {/* Header */}
          <View
            style={{
              paddingHorizontal: 20,
              paddingTop: 4,
              paddingBottom: 16,
              borderBottomWidth: 1,
              borderBottomColor: '#27272a',
            }}
          >
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
              <View
                style={{
                  width: 36,
                  height: 36,
                  borderRadius: 12,
                  backgroundColor: '#10b98115',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Repeat color="#10b981" size={18} />
              </View>
              <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 20, color: '#fafafa' }}>
                Transaksi Berulang
              </Text>
            </View>
          </View>

          <ScrollView
            style={{ flex: 1, paddingHorizontal: 20 }}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingTop: 16, paddingBottom: 40 }}
          >
            {/* Quick Templates */}
            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 8, textTransform: 'uppercase', letterSpacing: 1 }}>
              Template Cepat
            </Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginBottom: 20 }}>
              {QUICK_TEMPLATES.map((tmpl, i) => (
                <TouchableOpacity
                  key={i}
                  onPress={() => handleTemplate(tmpl)}
                  style={{
                    paddingHorizontal: 14,
                    paddingVertical: 10,
                    backgroundColor: '#09090b',
                    borderRadius: 12,
                    borderWidth: 1,
                    borderColor: '#27272a',
                    marginRight: 8,
                  }}
                >
                  <Text style={{ fontFamily: 'Inter', fontSize: 13, color: '#a1a1aa' }}>
                    {tmpl.title}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>

            {/* Title Input */}
            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
              Nama Transaksi
            </Text>
            <View
              style={{
                backgroundColor: '#09090b',
                borderRadius: 14,
                borderWidth: 1,
                borderColor: '#27272a',
                paddingHorizontal: 14,
                paddingVertical: 4,
                flexDirection: 'row',
                alignItems: 'center',
                marginBottom: 16,
              }}
            >
              <Tag color="#52525b" size={16} />
              <BottomSheetTextInput
                placeholder="Contoh: Kos Bulanan"
                placeholderTextColor="#52525b"
                value={title}
                onChangeText={setTitle}
                style={{ flex: 1, marginLeft: 10, fontSize: 15, color: '#fafafa', paddingVertical: 12 }}
              />
            </View>

            {/* Amount Input */}
            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
              Nominal (Rp)
            </Text>
            <View
              style={{
                backgroundColor: '#09090b',
                borderRadius: 14,
                borderWidth: 1,
                borderColor: '#27272a',
                paddingHorizontal: 14,
                paddingVertical: 4,
                flexDirection: 'row',
                alignItems: 'center',
                marginBottom: 16,
              }}
            >
              <DollarSign color="#52525b" size={16} />
              <BottomSheetTextInput
                placeholder="500000"
                placeholderTextColor="#52525b"
                value={amount}
                onChangeText={setAmount}
                keyboardType="numeric"
                style={{ flex: 1, marginLeft: 10, fontSize: 15, color: '#fafafa', paddingVertical: 12 }}
              />
            </View>

            {/* Type Toggle */}
            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
              Tipe
            </Text>
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16 }}>
              {(['expense', 'income'] as const).map((t) => (
                <TouchableOpacity
                  key={t}
                  onPress={() => setType(t)}
                  style={{
                    flex: 1,
                    paddingVertical: 12,
                    borderRadius: 12,
                    backgroundColor: type === t
                      ? (t === 'expense' ? '#450a0a' : '#052e16')
                      : '#09090b',
                    borderWidth: 1,
                    borderColor: type === t
                      ? (t === 'expense' ? '#7f1d1d' : '#14532d')
                      : '#27272a',
                    alignItems: 'center',
                  }}
                >
                  <Text
                    style={{
                      fontFamily: 'Inter_SemiBold',
                      fontSize: 14,
                      color: type === t
                        ? (t === 'expense' ? '#fca5a5' : '#34d399')
                        : '#71717a',
                    }}
                  >
                    {t === 'expense' ? '💸 Pengeluaran' : '💰 Pemasukan'}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Category */}
            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
              Kategori
            </Text>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
              {BUDGET_CATEGORIES.map((cat) => (
                <TouchableOpacity
                  key={cat.key}
                  onPress={() => setCategory(cat.key)}
                  style={{
                    paddingHorizontal: 14,
                    paddingVertical: 10,
                    borderRadius: 12,
                    backgroundColor: category === cat.key ? cat.color + '20' : '#09090b',
                    borderWidth: 1,
                    borderColor: category === cat.key ? cat.color : '#27272a',
                  }}
                >
                  <Text
                    style={{
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: category === cat.key ? '#fafafa' : '#71717a',
                    }}
                  >
                    {cat.emoji} {cat.label}
                  </Text>
                </TouchableOpacity>
              ))}
              {/* Income category for income type */}
              {type === 'income' && (
                <TouchableOpacity
                  onPress={() => setCategory('Income')}
                  style={{
                    paddingHorizontal: 14,
                    paddingVertical: 10,
                    borderRadius: 12,
                    backgroundColor: category === 'Income' ? '#10b98120' : '#09090b',
                    borderWidth: 1,
                    borderColor: category === 'Income' ? '#10b981' : '#27272a',
                  }}
                >
                  <Text
                    style={{
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: category === 'Income' ? '#fafafa' : '#71717a',
                    }}
                  >
                    💰 Pemasukan
                  </Text>
                </TouchableOpacity>
              )}
            </View>

            {/* Frequency */}
            <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
              Frekuensi
            </Text>
            <View style={{ flexDirection: 'row', gap: 8, marginBottom: 16 }}>
              {FREQUENCY_OPTIONS.map((opt) => (
                <TouchableOpacity
                  key={opt.key}
                  onPress={() => setFrequency(opt.key)}
                  style={{
                    flex: 1,
                    paddingVertical: 12,
                    borderRadius: 12,
                    backgroundColor: frequency === opt.key ? '#18181b' : '#09090b',
                    borderWidth: 1,
                    borderColor: frequency === opt.key ? '#10b981' : '#27272a',
                    alignItems: 'center',
                  }}
                >
                  <Text style={{ fontSize: 16, marginBottom: 2 }}>{opt.emoji}</Text>
                  <Text
                    style={{
                      fontFamily: 'Inter_SemiBold',
                      fontSize: 12,
                      color: frequency === opt.key ? '#10b981' : '#71717a',
                    }}
                  >
                    {opt.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Weekly: Day of Week Selector */}
            {frequency === 'weekly' && (
              <>
                <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
                  Hari dalam Minggu
                </Text>
                <View style={{ flexDirection: 'row', gap: 6, marginBottom: 16 }}>
                  {DAY_NAMES.map((name, idx) => (
                    <TouchableOpacity
                      key={idx}
                      onPress={() => setDayOfWeek(idx)}
                      style={{
                        flex: 1,
                        paddingVertical: 10,
                        borderRadius: 10,
                        backgroundColor: dayOfWeek === idx ? '#10b98120' : '#09090b',
                        borderWidth: 1,
                        borderColor: dayOfWeek === idx ? '#10b981' : '#27272a',
                        alignItems: 'center',
                      }}
                    >
                      <Text
                        style={{
                          fontFamily: 'Inter_SemiBold',
                          fontSize: 11,
                          color: dayOfWeek === idx ? '#10b981' : '#71717a',
                        }}
                      >
                        {name}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}

            {/* Monthly: Day of Month Selector */}
            {frequency === 'monthly' && (
              <>
                <Text style={{ fontFamily: 'Inter_SemiBold', fontSize: 12, color: '#71717a', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
                  Tanggal dalam Bulan
                </Text>
                <View
                  style={{
                    backgroundColor: '#09090b',
                    borderRadius: 14,
                    borderWidth: 1,
                    borderColor: '#27272a',
                    paddingHorizontal: 14,
                    paddingVertical: 4,
                    flexDirection: 'row',
                    alignItems: 'center',
                    marginBottom: 16,
                  }}
                >
                  <Calendar color="#52525b" size={16} />
                  <BottomSheetTextInput
                    placeholder="1"
                    placeholderTextColor="#52525b"
                    value={String(dayOfMonth)}
                    onChangeText={(v) => {
                      const n = parseInt(v, 10);
                      if (!isNaN(n) && n >= 1 && n <= 31) setDayOfMonth(n);
                      else if (v === '') setDayOfMonth(1);
                    }}
                    keyboardType="numeric"
                    style={{ flex: 1, marginLeft: 10, fontSize: 15, color: '#fafafa', paddingVertical: 12 }}
                  />
                </View>
              </>
            )}

            {/* Save Button */}
            <TouchableOpacity
              onPress={handleSave}
              disabled={saving}
              style={{
                backgroundColor: saving ? '#27272a' : '#10b981',
                paddingVertical: 16,
                borderRadius: 16,
                alignItems: 'center',
                marginTop: 8,
              }}
            >
              {saving ? (
                <ActivityIndicator color="#fafafa" />
              ) : (
                <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 16, color: '#09090b' }}>
                  Simpan Recurring
                </Text>
              )}
            </TouchableOpacity>
          </ScrollView>
        </BottomSheetView>
      </BottomSheet>
    );
  }
);

AddRecurringSheet.displayName = 'AddRecurringSheet';

export default AddRecurringSheet;
