class FuzzyMatcher {
  /// Computes the Levenshtein distance (edit distance) between two strings.
  /// Lower distance means more similar. Returns 0 if strings are identical.
  static int computeLevenshtein(String a, String b) {
    final s1 = a.toLowerCase().trim();
    final s2 = b.toLowerCase().trim();

    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Use two rows instead of a full matrix to optimize memory usage
    final List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    final List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = s1.codeUnitAt(i) == s2.codeUnitAt(j) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      // Copy v1 values to v0 for the next iteration (avoids allocating new lists)
      v0.setAll(0, v1);
    }
    return v0[s2.length];
  }

  /// Calculates the similarity score between two strings.
  /// Returns a double value from 0.0 (completely different) to 1.0 (identical).
  static double similarity(String a, String b) {
    final cleanA = a.trim();
    final cleanB = b.trim();

    if (cleanA.isEmpty && cleanB.isEmpty) return 1.0;
    if (cleanA.isEmpty || cleanB.isEmpty) return 0.0;

    final distance = computeLevenshtein(cleanA, cleanB);
    final maxLength = cleanA.length > cleanB.length ? cleanA.length : cleanB.length;
    return 1.0 - (distance / maxLength);
  }

  static int _min3(int a, int b, int c) {
    int min = a;
    if (b < min) min = b;
    if (c < min) min = c;
    return min;
  }
}
