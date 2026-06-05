import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  String _filterType = 'all'; // all, income, expense
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  IconData _getIconData(String? name) {
    switch (name) {
      case 'restaurant': return Icons.restaurant_rounded;
      case 'local_cafe': return Icons.local_cafe_rounded;
      case 'attach_money': return Icons.attach_money_rounded;
      case 'receipt': return Icons.receipt_rounded;
      case 'shopping_bag': return Icons.shopping_bag_rounded;
      case 'directions_car': return Icons.directions_car_rounded;
      case 'local_gas_station': return Icons.local_gas_station_rounded;
      case 'home': return Icons.home_rounded;
      case 'electrical_services': return Icons.electrical_services_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'wifi': return Icons.wifi_rounded;
      case 'medical_services': return Icons.medical_services_rounded;
      case 'sports_esports': return Icons.sports_esports_rounded;
      case 'movie': return Icons.movie_rounded;
      case 'flight': return Icons.flight_rounded;
      case 'school': return Icons.school_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      case 'pets': return Icons.pets_rounded;
      case 'card_giftcard': return Icons.card_giftcard_rounded;
      case 'work': return Icons.work_rounded;
      case 'trending_up': return Icons.trending_up_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'account_balance': return Icons.account_balance_rounded;
      case 'build': return Icons.build_rounded;
      case 'spa': return Icons.spa_rounded;
      case 'payments': return Icons.payments_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String? colorHex, String type) {
    if (colorHex == null || colorHex.isEmpty || colorHex == 'system') {
      return type == 'expense' ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return type == 'expense' ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
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

  Map<String, List<TransactionModel>> _groupTransactions(List<TransactionModel> list, BuildContext context) {
    final groups = <String, List<TransactionModel>>{};
    // Sort transactions by date descending
    final sorted = List<TransactionModel>.from(list)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (var tx in sorted) {
      final key = _getDateGroupName(tx.createdAt, context);
      groups.putIfAbsent(key, () => []).add(tx);
    }
    return groups;
  }

  Widget _buildSummaryHeader(List<TransactionModel> filteredList, bool isDark, ThemeData theme) {
    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in filteredList) {
      if (tx.type.toLowerCase() == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type.toLowerCase() == 'expense') {
        totalExpense += tx.amount;
      }
    }
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GlassCard(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isDark 
                  ? const [Color(0x1F6366F1), Color(0x0F0F172A)]
                  : [theme.colorScheme.primary.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'bottom_sheet.income'.tr(),
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(totalIncome),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFFF43F5E), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'bottom_sheet.expense'.tr(),
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(totalExpense),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionState = ref.watch(transactionNotifierProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: const Text('Transaction History'),
        scrollController: _scrollController,
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Search and Filter Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Field
                      GlassInputField(
                        hintText: 'Search transactions...',
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.grey),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Income', 'income'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Expense', 'expense'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).liquidFadeIn(),
                
                // Transaction List with Summary Header
                Expanded(
                  child: transactionState.when(
                    data: (transactions) {
                      // Apply Filters
                      final filteredList = transactions.where((tx) {
                        // Type filter
                        if (_filterType != 'all' && tx.type.toLowerCase() != _filterType) {
                          return false;
                        }
                        // Search filter
                        if (_searchQuery.isNotEmpty) {
                          final matchCategory = tx.category.toLowerCase().contains(_searchQuery);
                          final matchNotes = tx.notes.toLowerCase().contains(_searchQuery);
                          if (!matchCategory && !matchNotes) return false;
                        }
                        return true;
                      }).toList();

                      // Grouped list compilation
                      final grouped = _groupTransactions(filteredList, context);
                      final listItems = <dynamic>[];
                      grouped.forEach((dateGroupName, txList) {
                        listItems.add(dateGroupName);
                        listItems.addAll(txList);
                      });

                      return Column(
                        children: [
                          _buildSummaryHeader(filteredList, isDark, theme),
                          Expanded(
                            child: filteredList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_rounded, 
                                          size: 64, 
                                          color: isDark ? Colors.white24 : Colors.black26
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No transactions found.',
                                          style: TextStyle(
                                            color: isDark ? Colors.white54 : Colors.black54,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                    itemCount: listItems.length,
                                    itemBuilder: (context, index) {
                                      final item = listItems[index];

                                      if (item is String) {
                                        // Chronological Day Group Header
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                                          child: Text(
                                            item,
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black54,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        );
                                      }

                                      final tx = item as TransactionModel;
                                      final isExpense = tx.type.toLowerCase() == 'expense';
                                      
                                      final matchedCategory = categories.firstWhere(
                                        (c) => c.name.toLowerCase() == tx.category.toLowerCase(),
                                        orElse: () => CategoryModel(
                                          id: '',
                                          userId: '',
                                          name: tx.category,
                                          type: tx.type,
                                          icon: isExpense ? 'restaurant' : 'attach_money',
                                          color: isExpense ? '#F43F5E' : '#10B981',
                                          createdAt: DateTime.now(),
                                        ),
                                      );

                                      final catColor = _getCategoryColor(matchedCategory.color, tx.type);
                                      final amountColor = isExpense ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
                                      final amountPrefix = isExpense ? '-' : '+';
                                      final formattedAmount = NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: 'Rp ',
                                        decimalDigits: 0,
                                      ).format(tx.amount);

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: GlassCard(
                                          enableBlur: false,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.1),
                                              ),
                                              boxShadow: isDark ? null : [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.03),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: catColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    _getIconData(matchedCategory.icon),
                                                    color: catColor,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        tx.notes.isNotEmpty ? tx.notes : tx.category,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                          fontSize: 15,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        tx.category.toUpperCase(),
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white54 : Colors.black54,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '$amountPrefix$formattedAmount',
                                                      style: TextStyle(
                                                        color: amountColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      DateFormat('HH:mm').format(tx.createdAt),
                                                      style: TextStyle(
                                                        color: isDark ? Colors.white30 : Colors.black38,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ).liquidStagger(index);
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          HapticFeedback.lightImpact();
          setState(() {
            if (selected) {
              _filterType = value;
            }
          });
        },
        backgroundColor: isDark ? const Color(0x1F26233A) : Colors.white.withValues(alpha: 0.8),
        selectedColor: theme.colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected ? theme.colorScheme.onPrimaryContainer : (isDark ? Colors.white70 : Colors.grey[700]),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!),
          ),
        ),
        showCheckmark: false,
      ),
    );
  }
}

