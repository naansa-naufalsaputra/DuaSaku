/// Represents the parsing strategy used by the Smart Input Bar.
enum ParserMode {
  /// TensorFlow Lite (Level 3) model with automatic fallback to Regex (Level 1) if initialization or inference fails.
  auto,

  /// TensorFlow Lite model only. Will throw an error if the model is unavailable.
  tfliteOnly,

  /// Lightweight, rule-based Regex and Fuzzy logic parser only. Saves battery and CPU.
  regexOnly,

  /// Lightweight statistical ML classifier (Level 2) only. Saves native overhead.
  lightweightMlOnly,
}
