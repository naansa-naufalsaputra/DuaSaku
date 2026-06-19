import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/local_db/app_database_provider.dart';
import '../domain/models/category_model.dart';
import '../domain/category_repository_interface.dart';

final categoryRepositoryProvider = Provider<CategoryRepositoryInterface>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

class CategoryRepository implements CategoryRepositoryInterface {
  final AppDatabase _db;

  CategoryRepository(this._db);

  @override
  Future<List<CategoryModel>> getCategories(String userId) async {
    final rows = await (_db.select(
      _db.categories,
    )..where((c) => c.userId.equals(userId))).get();
    return rows
        .map(
          (c) => CategoryModel(
            id: c.id,
            userId: c.userId,
            name: c.name,
            type: c.type,
            icon: c.icon,
            color: c.color,
            createdAt: c.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<CategoryModel> addCategory(CategoryModel category) async {
    final generatedId =
        category.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final companion = CategoriesCompanion.insert(
      id: generatedId,
      userId: category.userId,
      name: category.name,
      type: category.type,
      icon: Value(category.icon),
      color: Value(category.color),
      createdAt: category.createdAt,
    );

    await _db.into(_db.categories).insert(companion);

    return CategoryModel(
      id: generatedId,
      userId: category.userId,
      name: category.name,
      type: category.type,
      icon: category.icon,
      color: category.color,
      createdAt: category.createdAt,
    );
  }

  @override
  Future<void> updateCategory(CategoryModel category) async {
    await (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(category.id!))).write(
      CategoriesCompanion(
        name: Value(category.name),
        icon: Value(category.icon),
        color: Value(category.color),
        type: Value(category.type),
      ),
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}
