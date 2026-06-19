import '../domain/models/category_model.dart';

/// Abstract interface for category data operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than the concrete CategoryRepository.
abstract class CategoryRepositoryInterface {
  /// Retrieves all categories for a specific user.
  /// 
  /// [userId] - The user identifier
  /// 
  /// Returns a list of category models.
  Future<List<CategoryModel>> getCategories(String userId);

  /// Adds a new category to the database.
  /// 
  /// [category] - The category model to add
  /// 
  /// Returns the created category model with assigned ID.
  Future<CategoryModel> addCategory(CategoryModel category);

  /// Updates an existing category's properties.
  /// 
  /// [category] - The category model with updated properties
  Future<void> updateCategory(CategoryModel category);

  /// Deletes a category by its ID.
  /// 
  /// [id] - The category identifier
  Future<void> deleteCategory(String id);
}
