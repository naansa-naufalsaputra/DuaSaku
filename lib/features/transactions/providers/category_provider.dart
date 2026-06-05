import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/category_repository.dart';
import '../domain/models/category_model.dart';

final categoryNotifierProvider =
    AsyncNotifierProvider<CategoryNotifier, List<CategoryModel>>(
      CategoryNotifier.new,
    );

class CategoryNotifier extends AsyncNotifier<List<CategoryModel>> {
  @override
  FutureOr<List<CategoryModel>> build() async {
    final user = ref.watch(userProvider);
    if (user == null) {
      return [];
    }
    return _fetchCategories(user.id);
  }

  Future<List<CategoryModel>> _fetchCategories(String userId) async {
    final repo = ref.read(categoryRepositoryProvider);
    return await repo.getCategories(userId);
  }

  Future<void> loadCategories() async {
    final user = ref.read(userProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCategories(user.id));
  }

  Future<void> addCategory(
    String name,
    String type, {
    String? icon,
    String? color,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    final user = ref.read(userProvider);
    if (user == null) return;

    final newCat = CategoryModel(
      userId: user.id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      final created = await repo.addCategory(newCat);
      final currentList = state.value ?? [];
      state = AsyncValue.data([created, ...currentList]);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateCategory(
    String id,
    String name,
    String type, {
    String? icon,
    String? color,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    final user = ref.read(userProvider);
    if (user == null) return;

    final updatedCat = CategoryModel(
      id: id,
      userId: user.id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      await repo.updateCategory(updatedCat);
      final currentList = state.value ?? [];
      state = AsyncValue.data(
        currentList.map((c) => c.id == id ? updatedCat : c).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteCategory(String id) async {
    final repo = ref.read(categoryRepositoryProvider);
    try {
      await repo.deleteCategory(id);
      final currentList = state.value ?? [];
      state = AsyncValue.data(currentList.where((c) => c.id != id).toList());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
