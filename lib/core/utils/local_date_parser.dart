class LocalDateParser {
  /// Parses Indonesian relative/named date strings into a valid [DateTime] object.
  /// Returns null if no match is found.
  static DateTime? parse(String text, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final cleanText = text.toLowerCase().trim();

    // 1. Days Ago / Weeks Ago / Months Ago Patterns (MUST be evaluated first to avoid matching keywords like "kemarin" inside "3 minggu kemarin")
    // Days ago (e.g. "2 hari lalu", "2 hr")
    final daysAgoMatch = RegExp(
      r'\b(\d+)\s*(?:hari|hr)\s*(?:lalu|kemar[ei]n|yang\s+lalu)?\b',
    ).firstMatch(cleanText);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1) ?? '');
      if (days != null) {
        return DateTime(
          ref.year,
          ref.month,
          ref.day - days,
          ref.hour,
          ref.minute,
        );
      }
    }

    // Weeks ago (e.g. "3 minggu kemaren", "3 mgg")
    final weeksAgoMatch = RegExp(
      r'\b(\d+)\s*(?:minggu|mgg|mg)\s*(?:lalu|kemar[ei]n|yang\s+lalu)?\b',
    ).firstMatch(cleanText);
    if (weeksAgoMatch != null) {
      final weeks = int.tryParse(weeksAgoMatch.group(1) ?? '');
      if (weeks != null) {
        return DateTime(
          ref.year,
          ref.month,
          ref.day - (weeks * 7),
          ref.hour,
          ref.minute,
        );
      }
    }

    // Singular weeks ago: "minggu lalu", "minggu kemaren"
    if (RegExp(
      r'\bminggu\s*(?:lalu|kemar[ei]n|yang\s+lalu)\b',
    ).hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day - 7, ref.hour, ref.minute);
    }

    // Months ago (e.g. "1 bulan lalu", "1 bln")
    final monthsAgoMatch = RegExp(
      r'\b(\d+)\s*(?:bulan|bln)\s*(?:lalu|kemar[ei]n|yang\s+lalu)?\b',
    ).firstMatch(cleanText);
    if (monthsAgoMatch != null) {
      final months = int.tryParse(monthsAgoMatch.group(1) ?? '');
      if (months != null) {
        return _subtractMonths(ref, months);
      }
    }

    // Singular months ago: "bulan lalu", "bulan kemaren"
    if (RegExp(
      r'\bbulan\s*(?:lalu|kemar[ei]n|yang\s+lalu)\b',
    ).hasMatch(cleanText)) {
      return _subtractMonths(ref, 1);
    }

    // 2. Relative dates: "kemarin lusa" / "kemaren lusa" (2 days ago)
    if (RegExp(r'\bkemar[ei]n\s+lusa\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day - 2, ref.hour, ref.minute);
    }
    // "kemarin" / "kemaren" (1 day ago)
    if (RegExp(r'\bkemar[ei]n\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day - 1, ref.hour, ref.minute);
    }
    // "hari ini" / "sekarang" (today)
    if (RegExp(r'\bhari\s+ini\b|\bsekarang\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day, ref.hour, ref.minute);
    }
    // "lusa" (2 days later)
    if (RegExp(r'\blusa\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day + 2, ref.hour, ref.minute);
    }

    // 3. Abbreviated Time Anchors (today, but with custom hours)
    if (RegExp(r'\b(?:tadi|td)\s+pagi\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day, 8, 0); // 8 AM
    }
    if (RegExp(r'\b(?:tadi|td)\s+siang\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day, 12, 0); // 12 PM
    }
    if (RegExp(r'\b(?:tadi|td)\s+sore\b').hasMatch(cleanText)) {
      return DateTime(ref.year, ref.month, ref.day, 16, 0); // 4 PM
    }
    if (RegExp(r'\b(?:tadi|td)\s+malam\b').hasMatch(cleanText)) {
      // "tadi malam" / "td malam" refers to last night (yesterday night)
      return DateTime(
        ref.year,
        ref.month,
        ref.day - 1,
        20,
        0,
      ); // Yesterday 8 PM
    }

    // 4. Weekdays: "senin", "selasa", etc. (closest past weekday)
    final weekdayMap = {
      'senin': 1,
      'selasa': 2,
      'rabu': 3,
      'kamis': 4,
      'jumat': 5,
      "jum'at": 5,
      'sabtu': 6,
      'minggu': 7,
      'ahad': 7,
    };
    for (final entry in weekdayMap.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(cleanText)) {
        final targetDay = entry.value;
        final todayDay = ref.weekday;
        int diff = todayDay - targetDay;
        if (diff < 0) {
          diff += 7;
        }
        return DateTime(
          ref.year,
          ref.month,
          ref.day - diff,
          ref.hour,
          ref.minute,
        );
      }
    }

    // 5. Standard Numeric Dates (DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, DD/MM/YY)
    // Try DD/MM/YYYY first
    final numericDateMatch = RegExp(
      r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b',
    ).firstMatch(cleanText);
    if (numericDateMatch != null) {
      final day = int.tryParse(numericDateMatch.group(1) ?? '');
      final month = int.tryParse(numericDateMatch.group(2) ?? '');
      final rawYear = int.tryParse(numericDateMatch.group(3) ?? '');
      if (day != null && month != null && rawYear != null) {
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          final year = rawYear < 100 ? rawYear + 2000 : rawYear;
          return DateTime(year, month, day, 12, 0);
        }
      }
    }

    // Try DD/MM (year defaults to ref.year)
    final numericDayMonthMatch = RegExp(
      r'\b(\d{1,2})[/\-\.](\d{1,2})\b',
    ).firstMatch(cleanText);
    if (numericDayMonthMatch != null) {
      final day = int.tryParse(numericDayMonthMatch.group(1) ?? '');
      final month = int.tryParse(numericDayMonthMatch.group(2) ?? '');
      if (day != null && month != null) {
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
          return DateTime(ref.year, month, day, 12, 0);
        }
      }
    }

    // 6. Indonesian named months (e.g. "12 Juni", "12 Juni 2026", "12 jun")
    final namedMonthMatch = RegExp(
      r'\b(\d{1,2})\s+(jan(?:uari)?|feb(?:ruari)?|mar(?:et)?|apr(?:il)?|mei|jun(?:i)?|jul(?:i)?|ag(?:ustus|u|s|st)?|sep(?:tember|t)?|okt(?:ober)?|nov(?:ember)?|des(?:ember)?)\s*(\d{4})?\b',
      caseSensitive: false,
    ).firstMatch(cleanText);
    if (namedMonthMatch != null) {
      final day = int.tryParse(namedMonthMatch.group(1) ?? '');
      final monthStr = namedMonthMatch.group(2);
      final yearStr = namedMonthMatch.group(3);
      if (day != null && monthStr != null) {
        final month = _mapMonth(monthStr);
        if (month != null && day >= 1 && day <= 31) {
          final year = yearStr != null
              ? (int.tryParse(yearStr) ?? ref.year)
              : ref.year;
          return DateTime(year, month, day, 12, 0);
        }
      }
    }

    return null;
  }

  static DateTime _subtractMonths(DateTime dt, int months) {
    int y = dt.year;
    int m = dt.month - months;
    while (m <= 0) {
      y -= 1;
      m += 12;
    }
    int d = dt.day;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    if (d > daysInMonth) {
      d = daysInMonth;
    }
    return DateTime(
      y,
      m,
      d,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  static int? _mapMonth(String monthStr) {
    final clean = monthStr.toLowerCase();
    if (clean.startsWith('jan')) return 1;
    if (clean.startsWith('feb')) return 2;
    if (clean.startsWith('mar')) return 3;
    if (clean.startsWith('apr')) return 4;
    if (clean.startsWith('mei') || clean == 'may') return 5;
    if (clean.startsWith('jun')) return 6;
    if (clean.startsWith('jul')) return 7;
    if (clean.startsWith('agu') ||
        clean.startsWith('ags') ||
        clean.startsWith('agt') ||
        clean.startsWith('aug')) {
      return 8;
    }
    if (clean.startsWith('sep')) return 9;
    if (clean.startsWith('okt') || clean.startsWith('oct')) return 10;
    if (clean.startsWith('nov')) return 11;
    if (clean.startsWith('des') || clean.startsWith('dec')) return 12;
    return null;
  }
}
