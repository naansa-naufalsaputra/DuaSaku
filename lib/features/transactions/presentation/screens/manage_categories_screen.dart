import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/category_provider.dart';
import '../../domain/models/category_model.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  String _selectedType = 'expense';

  // Curated premium financial & lifestyle icons (including default ones)
  final List<String> _iconNames = [
    'restaurant',
    'local_cafe',
    'attach_money',
    'receipt',
    'shopping_bag',
    'directions_car',
    'local_gas_station',
    'home',
    'electrical_services',
    'water_drop',
    'wifi',
    'medical_services',
    'sports_esports',
    'movie',
    'flight',
    'school',
    'fitness_center',
    'pets',
    'card_giftcard',
    'work',
    'trending_up',
    'savings',
    'account_balance',
    'build',
    'spa',
    'payments',
  ];

  // 10 premium curated colors
  final List<String> _customColors = [
    'F43F5E', // Rose/Red
    'F97316', // Orange
    'F59E0B', // Amber
    '10B981', // Emerald
    '14B8A6', // Teal
    '06B6D4', // Cyan
    '3B82F6', // Blue
    '6366F1', // Indigo
    '8B5CF6', // Purple
    'EC4899', // Pink
  ];

  IconData _getIconData(String? name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'receipt':
        return Icons.receipt_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'electrical_services':
        return Icons.electrical_services_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'payments':
        return Icons.payments_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String? colorHex, String type) {
    if (colorHex == null || colorHex.isEmpty || colorHex == 'system') {
      return type == 'expense'
          ? const Color(0xFFF43F5E)
          : const Color(0xFF10B981);
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return type == 'expense'
          ? const Color(0xFFF43F5E)
          : const Color(0xFF10B981);
    }
  }

  void _showCategoryModal({CategoryModel? categoryToEdit}) {
    final nameCtrl = TextEditingController(text: categoryToEdit?.name ?? '');
    String type = categoryToEdit?.type ?? 'expense';
    String selectedIcon = categoryToEdit?.icon ?? 'restaurant';

    // Determine color selection mode: default or custom
    bool isCustomColor =
        categoryToEdit?.color != null && categoryToEdit?.color != 'system';
    String selectedColor = isCustomColor
        ? categoryToEdit!.color!.replaceAll('#', '')
        : 'F43F5E';

    double currentHue = 0.0;
    try {
      final parsedColor = Color(int.parse('0xFF$selectedColor'));
      final hsv = HSVColor.fromColor(parsedColor);
      currentHue = hsv.hue;
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modal Title
                    Text(
                      categoryToEdit == null ? 'Add Category' : 'Edit Category',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Category Name Field
                    GlassInputField(
                      controller: nameCtrl,
                      labelText: 'Category Name',
                    ),
                    const SizedBox(height: 16),

                    // Type Segmented Choice
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            variant: GlassButtonVariant.secondary,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => type = 'expense');
                            },
                            child: const Text(
                              'Expense',
                              style: TextStyle(
                                color: Color(0xFFF43F5E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassButton(
                            variant: GlassButtonVariant.secondary,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => type = 'income');
                            },
                            child: const Text(
                              'Income',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Color Mode Choice
                    Text(
                      'Category Color',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Ikuti Sistem'),
                            selected: !isCustomColor,
                            onSelected: (selected) {
                              HapticFeedback.lightImpact();
                              setModalState(() {
                                isCustomColor = false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Warna Sendiri'),
                            selected: isCustomColor,
                            onSelected: (selected) {
                              HapticFeedback.lightImpact();
                              setModalState(() {
                                isCustomColor = true;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Custom Color Picker Grid if active
                    if (isCustomColor) ...[
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _customColors.length,
                          itemBuilder: (context, idx) {
                            final colorHex = _customColors[idx];
                            final color = Color(int.parse('0xFF$colorHex'));
                            final isSelected =
                                selectedColor.toUpperCase() ==
                                colorHex.toUpperCase();
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setModalState(() {
                                  selectedColor = colorHex;
                                  try {
                                    final parsedColor = Color(
                                      int.parse('0xFF$colorHex'),
                                    );
                                    final hsv = HSVColor.fromColor(parsedColor);
                                    currentHue = hsv.hue;
                                  } catch (_) {}
                                });
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          width: 3,
                                        )
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Spectrum Hue Slider
                      Text(
                        'Geser Spektrum Warna',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 12,
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Color(int.parse('0xFF$selectedColor')),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 20,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  colors: List.generate(
                                    7,
                                    (i) => HSVColor.fromAHSV(
                                      1.0,
                                      i * 60.0,
                                      0.85,
                                      0.90,
                                    ).toColor(),
                                  ),
                                ),
                              ),
                            ),
                            Slider(
                              value: currentHue,
                              min: 0.0,
                              max: 360.0,
                              onChanged: (val) {
                                if (val.round() != currentHue.round()) {
                                  HapticFeedback.selectionClick();
                                }
                                setModalState(() {
                                  currentHue = val;
                                  final newColor = HSVColor.fromAHSV(
                                    1.0,
                                    val,
                                    0.85,
                                    0.90,
                                  ).toColor();
                                  selectedColor = newColor
                                      .toARGB32()
                                      .toRadixString(16)
                                      .substring(2)
                                      .toUpperCase();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Icon Grid Selector
                    Text(
                      'Select Category Icon',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade200,
                        ),
                      ),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: _iconNames.length,
                        itemBuilder: (context, idx) {
                          final iconName = _iconNames[idx];
                          final isSelected = selectedIcon == iconName;
                          final activeColor = isCustomColor
                              ? Color(int.parse('0xFF$selectedColor'))
                              : (type == 'expense'
                                    ? const Color(0xFFF43F5E)
                                    : const Color(0xFF10B981));

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => selectedIcon = iconName);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? activeColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? activeColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getIconData(iconName),
                                color: isSelected
                                    ? activeColor
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.black45),
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Action Button
                    GlassButton(
                      onPressed: () async {
                        if (nameCtrl.text.isNotEmpty) {
                          HapticFeedback.mediumImpact();
                          final finalColor = isCustomColor
                              ? '#$selectedColor'
                              : 'system';
                          final notifier = ref.read(
                            categoryNotifierProvider.notifier,
                          );
                          final navigator = Navigator.of(ctx);

                          if (categoryToEdit == null) {
                            await notifier.addCategory(
                              nameCtrl.text.trim(),
                              type,
                              icon: selectedIcon,
                              color: finalColor,
                            );
                          } else {
                            await notifier.updateCategory(
                              categoryToEdit.id!,
                              nameCtrl.text.trim(),
                              type,
                              icon: selectedIcon,
                              color: finalColor,
                            );
                          }
                          navigator.pop();
                        }
                      },
                      child: Text(
                        categoryToEdit == null
                            ? 'Create Category'
                            : 'Save Changes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoryNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: const Text(
          'Manage Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Segmented selector to switch expense/income tabs
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedType = 'expense');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedType == 'expense'
                                    ? (isDark
                                          ? const Color(0xFF1e293b)
                                          : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedType == 'expense' && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Expense',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedType == 'expense'
                                      ? const Color(0xFFF43F5E)
                                      : (isDark
                                            ? Colors.white54
                                            : Colors.black54),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedType = 'income');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedType == 'income'
                                    ? (isDark
                                          ? const Color(0xFF1e293b)
                                          : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedType == 'income' && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Income',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedType == 'income'
                                      ? const Color(0xFF10B981)
                                      : (isDark
                                            ? Colors.white54
                                            : Colors.black54),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category List builder
                Expanded(
                  child: categoriesState.when(
                    data: (categories) {
                      final filtered = categories
                          .where((c) => c.type == _selectedType)
                          .toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No custom categories yet.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final cat = filtered[index];
                          final activeColor = _getCategoryColor(
                            cat.color,
                            cat.type,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.grey.withValues(alpha: 0.1),
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: activeColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconData(cat.icon),
                                  color: activeColor,
                                ),
                              ),
                              title: Text(
                                cat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.blueAccent,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _showCategoryModal(categoryToEdit: cat);
                                    },
                                  ),
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      if (cat.id != null) {
                                        HapticFeedback.vibrate();
                                        ref
                                            .read(
                                              categoryNotifierProvider.notifier,
                                            )
                                            .deleteCategory(cat.id!);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error: $err',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showCategoryModal();
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Category',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
