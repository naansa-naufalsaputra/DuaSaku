import 'package:flutter/material.dart';

/// Centralized utility helper to map category name strings to their respective Icons.
class CategoryIconHelper {
  /// Curated premium icons specifically for Expense categories
  static List<String> getExpenseIcons() {
    return [
      // Food & Dining
      'restaurant',
      'local_cafe',
      'fastfood',
      'cake',
      'local_bar',
      // Transport & Travel
      'directions_car',
      'local_gas_station',
      'subway',
      'two_wheeler',
      'flight',
      // Shopping & Lifestyle
      'shopping_bag',
      'shopping_cart',
      'checkroom',
      'dry_cleaning',
      'brush',
      // Bills & Utilities
      'electrical_services',
      'water_drop',
      'wifi',
      'tv',
      'phone_android',
      // Housing & Family
      'home',
      'pets',
      'child_care',
      'family_restroom',
      'build',
      // Health & Leisure
      'medical_services',
      'healing',
      'fitness_center',
      'spa',
      'sports_esports',
      'movie',
      'music_note',
      'book',
      'sports_soccer',
      // Others
      'receipt',
      'warning',
      'card_giftcard',
    ];
  }

  /// Curated premium icons specifically for Income categories
  static List<String> getIncomeIcons() {
    return [
      'work',
      'monetization_on',
      'payments',
      'business_center',
      'trending_up',
      'savings',
      'account_balance',
      'pie_chart',
      'domain',
      'storefront',
      'sell',
      'card_giftcard',
    ];
  }

  /// Map an icon string identifier to its respective Material IconData.
  static IconData getIconData(String? name) {
    switch (name) {
      // Food & Dining
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'fastfood':
        return Icons.fastfood_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'local_bar':
        return Icons.local_bar_rounded;
      // Transport & Travel
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'subway':
        return Icons.subway_rounded;
      case 'two_wheeler':
        return Icons.two_wheeler_rounded;
      case 'flight':
        return Icons.flight_rounded;
      // Shopping & Lifestyle
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'dry_cleaning':
        return Icons.dry_cleaning_rounded;
      case 'brush':
        return Icons.brush_rounded;
      // Bills & Utilities
      case 'electrical_services':
        return Icons.electrical_services_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'phone_android':
        return Icons.phone_android_rounded;
      // Housing & Family
      case 'home':
        return Icons.home_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'child_care':
        return Icons.child_care_rounded;
      case 'family_restroom':
        return Icons.family_restroom_rounded;
      case 'build':
        return Icons.build_rounded;
      // Health & Leisure
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'healing':
        return Icons.healing_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'book':
        return Icons.book_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      // Income specific
      case 'work':
        return Icons.work_rounded;
      case 'monetization_on':
        return Icons.monetization_on_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'business_center':
        return Icons.business_center_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'pie_chart':
        return Icons.pie_chart_rounded;
      case 'domain':
        return Icons.domain_rounded;
      case 'storefront':
        return Icons.storefront_rounded;
      case 'sell':
        return Icons.sell_rounded;
      // Shared / Others
      case 'receipt':
        return Icons.receipt_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
