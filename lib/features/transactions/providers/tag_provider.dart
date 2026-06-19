import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duasaku_app/core/local_db/app_database_provider.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/constants/app_constants.dart';
import '../data/tag_repository.dart';
import '../domain/tag_repository_interface.dart';
import '../domain/models/tag_model.dart';

final tagRepositoryProvider = Provider<TagRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TagRepository(db);
});

final tagsProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  return repo.watchTags(AppConstants.defaultUserId);
});

final transactionTagsProvider =
    StreamProvider.autoDispose.family<List<Tag>, int>((ref, transactionId) {
  final repo = ref.watch(tagRepositoryProvider);
  return repo.watchTransactionTags(transactionId);
});

class TagNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> createTag({
    required String name,
    String? color,
  }) async {
    final repo = ref.read(tagRepositoryProvider);
    final tag = Tag(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: AppConstants.defaultUserId,
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );

    await repo.createTag(tag);
  }

  Future<void> deleteTag(String tagId) async {
    final repo = ref.read(tagRepositoryProvider);
    await repo.deleteTag(tagId);
  }

  Future<void> attachTag({
    required int transactionId,
    required String tagId,
  }) async {
    final repo = ref.read(tagRepositoryProvider);
    await repo.attachTagToTransaction(
      transactionId: transactionId,
      tagId: tagId,
    );
  }

  Future<void> detachTag({
    required int transactionId,
    required String tagId,
  }) async {
    final repo = ref.read(tagRepositoryProvider);
    await repo.detachTagFromTransaction(
      transactionId: transactionId,
      tagId: tagId,
    );
  }

  Future<void> setTransactionTags({
    required int transactionId,
    required List<String> tagIds,
  }) async {
    final repo = ref.read(tagRepositoryProvider);

    // Get current tags
    final currentResult = await repo.getTransactionTags(transactionId);
    final currentTagIds = switch (currentResult) {
      Success(:final value) => value.map((t) => t.id).toSet(),
      Failure() => <String>{},
    };

    final newTagIds = tagIds.toSet();

    // Detach removed tags
    for (final tagId in currentTagIds) {
      if (!newTagIds.contains(tagId)) {
        await repo.detachTagFromTransaction(
          transactionId: transactionId,
          tagId: tagId,
        );
      }
    }

    // Attach new tags
    for (final tagId in newTagIds) {
      if (!currentTagIds.contains(tagId)) {
        await repo.attachTagToTransaction(
          transactionId: transactionId,
          tagId: tagId,
        );
      }
    }
  }
}

final tagNotifierProvider = NotifierProvider<TagNotifier, void>(() {
  return TagNotifier();
});
