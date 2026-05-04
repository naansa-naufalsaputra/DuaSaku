/**
 * TransactionDetailSheet — Bottom sheet for drill-down into daily transactions
 *
 * Triggered by tapping a bar on the BarChart in insights.tsx.
 * Displays all transactions for the selected date in a Darkmatter glassmorphism style.
 */

import React, { useMemo, forwardRef, useCallback } from 'react';
import { View, Text, ScrollView, TouchableOpacity, DeviceEventEmitter } from 'react-native';
import BottomSheet, { BottomSheetView } from '@gorhom/bottom-sheet';
import { Calendar, ArrowUpRight, ArrowDownLeft } from 'lucide-react-native';

export interface TransactionItem {
  id: string;
  title?: string;
  note?: string;
  amount: number;
  category: string;
  type: 'expense' | 'income';
  created_at: string;
  location_name?: string | null;
}

interface TransactionDetailSheetProps {
  transactions: TransactionItem[];
  dateLabel: string;
  onClose?: () => void;
}

const CATEGORY_EMOJI: Record<string, string> = {
  Food: '🍔',
  Transport: '🚗',
  Entertainment: '🎬',
  Utilities: '💡',
  Shopping: '🛍️',
  Income: '💰',
  Health: '🏥',
  Investment: '📈',
  Other: '📦',
};

const TransactionDetailSheet = forwardRef<BottomSheet, TransactionDetailSheetProps>(
  ({ transactions, dateLabel, onClose }, ref) => {
    const snapPoints = useMemo(() => ['50%', '80%'], []);

    const handleSheetChanges = useCallback(
      (index: number) => {
        if (index === -1) onClose?.();
      },
      [onClose]
    );

    const totalAmount = transactions.reduce((acc, tx) => {
      return tx.type === 'income' ? acc + tx.amount : acc - tx.amount;
    }, 0);

    const formatCurrency = (amount: number) =>
      `Rp ${Math.abs(amount).toLocaleString('id-ID')}`;

    const formatTime = (isoString: string) => {
      try {
        const d = new Date(isoString);
        return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
      } catch {
        return '';
      }
    };

    return (
      <BottomSheet
        ref={ref}
        index={-1}
        snapPoints={snapPoints}
        enablePanDownToClose
        onChange={handleSheetChanges}
        handleIndicatorStyle={{ backgroundColor: '#3f3f46', width: 48, marginTop: 4 }}
        backgroundStyle={{
          backgroundColor: '#161616',
          borderRadius: 32,
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
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 4 }}>
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
                <Calendar color="#10b981" size={18} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 18, color: '#fafafa' }}>
                  {dateLabel}
                </Text>
                <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#71717a' }}>
                  {transactions.length} transaksi
                </Text>
              </View>
              <View
                style={{
                  backgroundColor: totalAmount >= 0 ? '#052e16' : '#450a0a',
                  paddingHorizontal: 12,
                  paddingVertical: 6,
                  borderRadius: 10,
                }}
              >
                <Text
                  style={{
                    fontFamily: 'Manrope_700Bold',
                    fontSize: 14,
                    color: totalAmount >= 0 ? '#34d399' : '#fca5a5',
                  }}
                >
                  {totalAmount >= 0 ? '+' : '-'}{formatCurrency(totalAmount)}
                </Text>
              </View>
            </View>
          </View>

          {/* Transaction List */}
          <ScrollView
            style={{ flex: 1, paddingHorizontal: 20 }}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={{ paddingTop: 12, paddingBottom: 40 }}
          >
            {transactions.length === 0 ? (
              <View style={{ alignItems: 'center', paddingVertical: 40 }}>
                <Text style={{ fontFamily: 'Inter', fontSize: 14, color: '#52525b' }}>
                  Tidak ada transaksi di hari ini
                </Text>
              </View>
            ) : (
              transactions.map((tx, idx) => {
                const emoji = CATEGORY_EMOJI[tx.category] || '📦';
                const isIncome = tx.type === 'income';

                return (
                  <View
                    key={tx.id || idx}
                    style={{
                      flexDirection: 'row',
                      alignItems: 'center',
                      paddingVertical: 14,
                      borderBottomWidth: idx < transactions.length - 1 ? 1 : 0,
                      borderBottomColor: '#1f1f23',
                    }}
                  >
                    {/* Emoji Icon */}
                    <View
                      style={{
                        width: 44,
                        height: 44,
                        borderRadius: 14,
                        backgroundColor: '#09090b',
                        alignItems: 'center',
                        justifyContent: 'center',
                        marginRight: 14,
                        borderWidth: 1,
                        borderColor: '#27272a',
                      }}
                    >
                      <Text style={{ fontSize: 20 }}>{emoji}</Text>
                    </View>

                    {/* Details */}
                    <View style={{ flex: 1 }}>
                      <Text
                        style={{ fontFamily: 'Manrope_600SemiBold', fontSize: 15, color: '#fafafa' }}
                        numberOfLines={1}
                      >
                        {tx.title || tx.note || 'Transaksi'}
                      </Text>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 3 }}>
                        <Text style={{ fontFamily: 'Inter', fontSize: 12, color: '#52525b' }}>
                          {tx.category || 'Other'}
                        </Text>
                        {tx.location_name && (
                          <>
                            <Text style={{ color: '#3f3f46', fontSize: 10 }}>•</Text>
                            <Text
                              style={{ fontFamily: 'Inter', fontSize: 11, color: '#52525b' }}
                              numberOfLines={1}
                            >
                              {tx.location_name}
                            </Text>
                          </>
                        )}
                      </View>
                    </View>

                    {/* Amount + Time */}
                    <View style={{ alignItems: 'flex-end' }}>
                      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                        {isIncome ? (
                          <ArrowDownLeft color="#34d399" size={12} />
                        ) : (
                          <ArrowUpRight color="#fca5a5" size={12} />
                        )}
                        <Text
                          style={{
                            fontFamily: 'Manrope_700Bold',
                            fontSize: 15,
                            color: isIncome ? '#34d399' : '#fafafa',
                          }}
                        >
                          {isIncome ? '+' : '-'}{formatCurrency(tx.amount)}
                        </Text>
                      </View>
                      <Text style={{ fontFamily: 'Inter', fontSize: 11, color: '#52525b', marginTop: 2 }}>
                        {formatTime(tx.created_at)}
                      </Text>
                      <TouchableOpacity 
                        onPress={() => {
                          DeviceEventEmitter.emit('edit_transaction', tx);
                        }}
                        style={{ marginTop: 4 }}
                      >
                        <Text style={{ fontFamily: 'Manrope_700Bold', fontSize: 10, color: '#10b981' }}>
                          EDIT
                        </Text>
                      </TouchableOpacity>
                    </View>
                  </View>
                );
              })
            )}
          </ScrollView>
        </BottomSheetView>
      </BottomSheet>
    );
  }
);

TransactionDetailSheet.displayName = 'TransactionDetailSheet';

export default TransactionDetailSheet;
