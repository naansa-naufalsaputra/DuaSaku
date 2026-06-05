/// Abstract interface for financial insights data operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than the concrete InsightsRepository.
abstract class InsightsRepositoryInterface {
  /// Generates financial advice based on the current month's transactions.
  /// Returns a formatted string with insights and recommendations.
  Future<String> getFinancialAdvice();
}
