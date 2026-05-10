/**
 * TransactionDetailSheet — Bottom sheet for drill-down into daily transactions
 *
 * Triggered by tapping a bar on the BarChart in insights.tsx.
 * Displays all transactions for the selected date in a Darkmatter glassmorphism style.
 */

import React, { useMemo, forwardRef, useCallback } from 'react';
import { View, Text, ScrollView, TouchableOpacity, DeviceEventEmitter, StyleSheet as RNStyleSheet } from 'react-native';
import BottomSheet, { BottomSheetView } from '@gorhom/bottom-sheet';
import { Calendar, ArrowUpRight, ArrowDownLeft } from 'lucide-react-native';
import { useTranslation } from 'react-i18next';
import { useCategoryStore } from '../store/useCategoryStore';
import { HapticService } from '../lib/hapticService';

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

const TransactionDetailSheet = forwardRef<BottomSheet, TransactionDetailSheetProps>(
  ({ transactions, dateLabel, onClose }, ref) => {
    const { t } = useTranslation();
    const { getAllCategories } = useCategoryStore();
    const categories = getAllCategories();
    
    const snapPoints = useMemo(() => ['50%', '80%'], []);

    const getCategoryMeta = useCallback((name: string) => {
      return categories.find(c => c.label === name) || { emoji: '📦', color: '#52525b' };
    }, [categories]);

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
        handleIndicatorStyle={styles.handleIndicator}
        backgroundStyle={styles.sheetBackground}
      >
        <BottomSheetView style={{ flex: 1 }}>
          {/* Header */}
          <View style={styles.header}>
            <View style={styles.headerRow}>
              <View style={styles.headerIconContainer}>
                <Calendar color="#10b981" size={18} />
              </View>
              <View style={{ flex: 1 }}>
                  <Text style={styles.headerTitle}>
                  {dateLabel}
                </Text>
                 <Text style={styles.headerSubtitle}>
                  {transactions.length} {t('transaction').toLowerCase()}
                </Text>
              </View>
              <View
                style={[styles.amountBadge, totalAmount >= 0 ? styles.incomeBadge : styles.expenseBadge]}
              >
                <Text
                  style={[styles.amountText, totalAmount >= 0 ? styles.incomeText : styles.expenseText]}
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
            contentContainerStyle={styles.scrollContent}
          >
            {transactions.length === 0 ? (
              <View style={styles.emptyContainer}>
                 <Text style={styles.emptyText}>
                  {t('noTransactionsFound')}
                </Text>
              </View>
            ) : (
              transactions.map((tx, idx) => {
                const meta = getCategoryMeta(tx.category);
                const isIncome = tx.type === 'income';

                return (
                  <View
                    key={tx.id || idx}
                    style={[
                      styles.transactionItem,
                      {
                        borderBottomWidth: idx < transactions.length - 1 ? 1 : 0,
                        borderBottomColor: '#1f1f23',
                      },
                    ]}
                  >
                    {/* Emoji Icon */}
                    <View style={[styles.emojiContainer, { backgroundColor: isIncome ? '#052e16' : '#09090b' }]}>
                      <Text style={styles.emojiText}>{meta.emoji}</Text>
                    </View>

                    {/* Details */}
                    <View style={styles.itemDetails}>
                       <Text style={styles.itemTitle} numberOfLines={1}>
                        {tx.title || tx.note || t('transaction')}
                      </Text>
                      <View style={styles.itemMetaRow}>
                        <Text style={styles.itemCategory}>
                          {tx.category || 'Other'}
                        </Text>
                        {tx.location_name && (
                          <>
                            <Text style={styles.dotSeparator}>•</Text>
                            <Text style={styles.itemLocation} numberOfLines={1}>
                              {tx.location_name}
                            </Text>
                          </>
                        )}
                      </View>
                    </View>

                    {/* Amount + Time */}
                    <View style={styles.itemAmountContainer}>
                      <View style={styles.amountRow}>
                        {isIncome ? (
                          <ArrowDownLeft color="#34d399" size={12} />
                        ) : (
                          <ArrowUpRight color="#fca5a5" size={12} />
                        )}
                        <Text
                          style={[
                            styles.itemAmountText,
                            { color: isIncome ? '#34d399' : '#fafafa' }
                          ]}
                        >
                          {isIncome ? '+' : '-'}{formatCurrency(tx.amount)}
                        </Text>
                      </View>
                      <Text style={styles.itemTime}>
                        {formatTime(tx.created_at)}
                      </Text>
                      <TouchableOpacity 
                        onPress={() => {
                          DeviceEventEmitter.emit('edit_transaction', tx);
                          HapticService.light();
                        }}
                        style={styles.editButton}
                      >
                        <Text style={styles.editText}>
                          {t('edit').toUpperCase()}
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

const styles = RNStyleSheet.create({
  editButton: {
    marginTop: 4,
  },
  editText: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 12,
    color: '#10b981',
  },
  incomeBadge: {
    backgroundColor: '#052e16',
  },
  expenseBadge: {
    backgroundColor: '#450a0a',
  },
  incomeText: {
    color: '#34d399',
  },
  expenseText: {
    color: '#fca5a5',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    fontFamily: 'Inter',
    fontSize: 14,
    color: '#52525b',
  },
  emojiText: {
    fontSize: 20,
  },
  itemDetails: {
    flex: 1,
  },
  itemMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 3,
  },
  dotSeparator: {
    color: '#3f3f46',
    fontSize: 12,
  },
  itemAmountContainer: {
    alignItems: 'flex-end',
  },
  amountRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  itemAmountText: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 15,
  },
  itemTime: {
    fontFamily: 'Inter',
    fontSize: 12,
    color: '#52525b',
    marginTop: 2,
  },
  handleIndicator: {
    backgroundColor: '#3f3f46',
    width: 48,
    marginTop: 4,
  },
  sheetBackground: {
    backgroundColor: '#161616',
    borderRadius: 32,
    borderWidth: 1,
    borderColor: '#27272a',
  },
  header: {
    paddingHorizontal: 20,
    paddingTop: 4,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#27272a',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 4,
  },
  headerIconContainer: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: '#10b98115',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 18,
    color: '#fafafa',
  },
  headerSubtitle: {
    fontFamily: 'Inter',
    fontSize: 12,
    color: '#71717a',
  },
  amountBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 10,
  },
  amountText: {
    fontFamily: 'Manrope_700Bold',
    fontSize: 14,
  },
  scrollContent: {
    paddingTop: 12,
    paddingBottom: 40,
  },
  transactionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
  },
  emojiContainer: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: '#09090b',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 14,
    borderWidth: 1,
    borderColor: '#27272a',
  },
  itemTitle: {
    fontFamily: 'Manrope_600SemiBold',
    fontSize: 15,
    color: '#fafafa',
  },
  itemCategory: {
    fontFamily: 'Inter',
    fontSize: 12,
    color: '#52525b',
  },
  itemLocation: {
    fontFamily: 'Inter',
    fontSize: 12,
    color: '#52525b',
  },
});

