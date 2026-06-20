import '../domain/models/budget_model.dart';

/// Abstract interface for budget data operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than the concrete BudgetRepository.
abstract class BudgetRepositoryInterface {
  /// Retrieves all budgets for a specific user and month.
  ///
  /// [userId] - The user identifier
  /// [month] - The month in 'YYYY-MM' format
  ///
  /// Returns a list of budget models with category names resolved.
  Future<List<BudgetModel>> getBudgets(String userId, String month);

  /// Creates or updates a budget for a specific category and month.
  ///
  /// If a budget already exists for the same userId, categoryId, and month,
  /// it will be replaced (upsert behavior).
  ///
  /// [budget] - The budget model to set
  ///
  /// Returns the created/updated budget model with assigned ID.
  Future<BudgetModel> setBudget(BudgetModel budget);

  /// Deletes a budget by its ID.
  ///
  /// [id] - The budget identifier
  Future<void> deleteBudget(String id);

  /// Gets suggested budget amount based on 3-month average spending.
  ///
  /// [userId] - The user identifier
  /// [categoryId] - The category identifier
  ///
  /// Returns suggested budget amount (average of last 3 months spending).
  /// Returns null if no transaction history exists.
  Future<double?> getSuggestedBudget(String userId, String categoryId);

  /// Retrieves a budget for a specific category and month.
  Future<BudgetModel?> getBudgetByCategoryAndMonth(
    String userId,
    String categoryId,
    String month,
  );

  /// Retrieves the sum of all budget limits for a specific user and month.
  Future<double?> getOverallBudgetLimit(String userId, String month);
}
