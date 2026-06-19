import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../domain/transaction_filters.dart';
import '../../providers/transaction_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';

class TransactionFilterPanel extends ConsumerStatefulWidget {
  const TransactionFilterPanel({super.key});

  @override
  ConsumerState<TransactionFilterPanel> createState() =>
      _TransactionFilterPanelState();
}

class _TransactionFilterPanelState
    extends ConsumerState<TransactionFilterPanel> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedType;
  String? _selectedWalletId;
  double? _minAmount;
  double? _maxAmount;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: ExpansionTile(
        title: Text(
          'filters.title'.tr(),
          style: theme.textTheme.titleMedium,
        ),
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'filters.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),

          // Date range pickers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate == null
                          ? 'filters.start_date'.tr()
                          : DateFormat('dd/MM/yyyy').format(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(false),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _endDate == null
                          ? 'filters.end_date'.tr()
                          : DateFormat('dd/MM/yyyy').format(_endDate!),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Type filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text('filters.all'.tr()),
                  selected: _selectedType == null,
                  onSelected: (_) => _setType(null),
                ),
                FilterChip(
                  label: Text('filters.income'.tr()),
                  selected: _selectedType == 'income',
                  onSelected: (_) => _setType('income'),
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                ),
                FilterChip(
                  label: Text('filters.expense'.tr()),
                  selected: _selectedType == 'expense',
                  onSelected: (_) => _setType('expense'),
                  selectedColor: Colors.red.withValues(alpha: 0.2),
                ),
                FilterChip(
                  label: Text('filters.transfer'.tr()),
                  selected: _selectedType == 'transfer',
                  onSelected: (_) => _setType('transfer'),
                  selectedColor: Colors.blue.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Wallet filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildWalletDropdown(),
          ),

          const SizedBox(height: 16),

          // Amount range
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'filters.min_amount'.tr(),
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _minAmount = double.tryParse(value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'filters.max_amount'.tr(),
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _maxAmount = double.tryParse(value);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Apply / Clear buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: Text('filters.clear'.tr()),
                ),
                ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.check),
                  label: Text('filters.apply'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletDropdown() {
    final walletsAsync = ref.watch(walletProvider);

    return walletsAsync.when(
      data: (wallets) {
        if (wallets.isEmpty) {
          return const SizedBox.shrink();
        }

        return DropdownButtonFormField<String?>(
          initialValue: _selectedWalletId,
          decoration: InputDecoration(
            labelText: 'filters.wallet'.tr(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('filters.all_wallets'.tr()),
            ),
            ...wallets.map((wallet) {
              return DropdownMenuItem<String?>(
                value: wallet.id,
                child: Text(wallet.name),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedWalletId = value;
            });
            _applyFilters();
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _applyFilters();
    }
  }

  void _setType(String? type) {
    setState(() {
      _selectedType = type;
    });
    _applyFilters();
  }

  void _applyFilters() {
    ref.read(transactionNotifierProvider.notifier).applyFilters(
          TransactionFilters(
            searchQuery: _searchController.text.isEmpty
                ? null
                : _searchController.text,
            startDate: _startDate,
            endDate: _endDate,
            type: _selectedType,
            walletId: _selectedWalletId,
            minAmount: _minAmount,
            maxAmount: _maxAmount,
          ),
        );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _startDate = null;
      _endDate = null;
      _selectedType = null;
      _selectedWalletId = null;
      _minAmount = null;
      _maxAmount = null;
    });
    ref.read(transactionNotifierProvider.notifier).clearFilters();
  }
}
