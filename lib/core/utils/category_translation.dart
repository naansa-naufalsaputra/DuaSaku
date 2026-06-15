import 'package:easy_localization/easy_localization.dart';

extension CategoryTranslation on String {
  /// Translates a category name dynamically based on defined translation keys.
  /// Falls back to the original string if no translation key is found.
  String toLocalizedCategory() {
    final key = 'categories.${toLowerCase()}';
    final translated = key.tr();
    return translated == key ? this : translated;
  }
}
