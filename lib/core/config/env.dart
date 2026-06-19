class Env {
  static Future<void> init() async {
    // 100% offline local-first app. No runtime .env file required.
    // Future compile-time configuration can be queried via String.fromEnvironment.
  }

  /// Example fallback for future integrations
  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
}
