import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../widgets/transaction_detail_dialog.dart';
import '../widgets/transaction_filter_panel.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/utils/category_translation.dart';
import '../../../../core/utils/text_sanitizer.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/category_icon_helper.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Trigger load more when 200px from bottom
      ref.read(transactionNotifierProvider.notifier).loadMoreTransactions();
    }
  }


  String _getDateGroupName(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    final locale = EasyLocalization.of(context)?.locale.languageCode ?? 'en';
    final isIndonesian = locale == 'id';

    if (txDate == today) {
      return isIndonesian ? 'Hari ini' : 'Today';
    } else if (txDate == yesterday) {
      return isIndonesian ? 'Kemarin' : 'Yesterday';
    } else {
      return DateFormat('dd MMMM yyyy', locale).format(date);
    }
  }

  Map<String, List<TransactionModel>> _groupTransactions(
    List<TransactionModel> list,
    BuildContext context,
  ) {
    final groups = <String, List<TransactionModel>>{};
    final sorted = List<TransactionModel>.from(list)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (var tx in sorted) {
      final key = _getDateGroupName(tx.createdAt, context);
      groups.putIfAbsent(key, () => []).add(tx);
    }
    return groups;
  }

  Widget _buildSummaryHeader(List<TransactionModel> filteredList, bool isDark) {
    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in filteredList) {
      if (tx.type.toLowerCase() == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type.toLowerCase() == 'expense') {
        totalExpense += tx.amount;
      }
    }
    final currencyFormat = ref.watch(currencyFormatterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total Income
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bottom_sheet.income'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(totalIncome),
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Total Expense
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: Color(0xFFF43F5E),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bottom_sheet.expense'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(totalExpense),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionState = ref.watch(transactionNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final walletsAsync = ref.watch(walletProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Transaction History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: isDark ? Colors.white : Colors.black87,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // New Filter Panel (replaces old search/filter UI)
                const TransactionFilterPanel(),

                // Transaction List with Summary Header
                Expanded(
                  child: transactionState.when(
                    data: (transactions) {
                      // No client-side filtering - handled by repository now
                      final filteredList = transactions;

                      // Grouped list compilation
                      final grouped = _groupTransactions(filteredList, context);
                      final listItems = <dynamic>[];
                      grouped.forEach((dateGroupName, txList) {
                        listItems.add(dateGroupName);
                        listItems.addAll(txList);
                      });

                      final notifier = ref.read(transactionNotifierProvider.notifier);

                      return Column(
                        children: [
                          _buildSummaryHeader(filteredList, isDark),
                          Expanded(
                            child: filteredList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_rounded,
                                          size: 64,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black26,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No transactions found.',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      100,
                                    ),
                                    itemCount: listItems.length + (notifier.hasMorePages ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // Show loading indicator at bottom for pagination
                                      if (index == listItems.length) {
                                        return notifier.isLoadingMore
                                            ? const Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: CircularProgressIndicator(),
                                                ),
                                              )
                                            : const SizedBox.shrink();
                                      }
                                      
                                      final item = listItems[index];

                                      if (item is String) {
                                        // Chronological Day Group Header
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            0,
                                            24,
                                            0,
                                            12,
                                          ),
                                          child: Text(
                                            item.toUpperCase(),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        );
                                      }

                                      final tx = item as TransactionModel;
                                      final isExpense =
                                          tx.type.toLowerCase() == 'expense';

                                      final matchedCategory = categories
                                          .firstWhere(
                                            (c) =>
                                                c.name.toLowerCase() ==
                                                tx.categoryId.toLowerCase(),
                                            orElse: () => CategoryModel(
                                              id: '',
                                              userId: '',
                                              name: tx.categoryId,
                                              type: tx.type,
                                              icon: isExpense
                                                  ? 'restaurant'
                                                  : 'attach_money',
                                              color: isExpense
                                                  ? '#007AFF'
                                                  : '#10B981',
                                              createdAt: DateTime.now(),
                                            ),
                                          );

                                      final amountColor = isExpense
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                          : const Color(0xFF10B981);
                                      final amountPrefix = isExpense
                                          ? '-'
                                          : '+';
                                      final formattedAmount =
                                          ref.watch(currencyFormatterProvider).format(tx.amount);

                                      return Column(
                                        children: [
                                          InkWell(
                                            onTap: () {},
                                            onLongPress: () {
                                              TransactionDetailDialog.show(
                                                context,
                                                transaction: tx,
                                                category: matchedCategory,
                                                wallets:
                                                    walletsAsync.valueOrNull ??
                                                    [],
                                              );
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: accentColor
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      CategoryIconHelper.getIconData(
                                                        matchedCategory.icon,
                                                      ),
                                                      color: accentColor,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          tx.notes.isNotEmpty
                                                              ? TextSanitizer.prettifyNotes(
                                                                  tx.notes,
                                                                )
                                                              : tx.categoryId
                                                                    .toLocalizedCategory(),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: isDark
                                                                ? Colors.white
                                                                : Colors
                                                                      .black87,
                                                            fontSize: 16,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          tx.categoryId
                                                              .toLocalizedCategory()
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            color: isDark
                                                                ? Colors.white30
                                                                : Colors
                                                                      .black38,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w300,
                                                            letterSpacing: 1,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        '$amountPrefix$formattedAmount',
                                                        style: TextStyle(
                                                          color: amountColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        DateFormat(
                                                          'HH:mm',
                                                        ).format(tx.createdAt),
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white30
                                                              : Colors.black38,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w300,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (index < listItems.length - 1 &&
                                              listItems[index + 1] is! String)
                                            Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.05,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                            ),
                                        ],
                                      ).liquidStagger(index);
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text(
                        'Error loading history: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
