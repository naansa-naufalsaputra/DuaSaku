import 'package:drift/drift.dart';
import 'package:duasaku_app/core/local_db/app_database.dart' as db;
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import '../domain/tag_repository_interface.dart';
import '../domain/models/tag_model.dart';

class TagRepository implements TagRepositoryInterface {
  final db.AppDatabase _db;

  TagRepository(this._db);

  @override
  Future<Result<Tag, AppError>> createTag(Tag tag) async {
    try {
      await _db
          .into(_db.tags)
          .insert(
            db.TagsCompanion.insert(
              id: tag.id,
              userId: tag.userId,
              name: tag.name,
              color: Value(tag.color),
              createdAt: tag.createdAt,
            ),
          );
      return Success(tag);
    } catch (e) {
      return Failure(AppError.database('Failed to create tag: $e'));
    }
  }

  @override
  Stream<List<Tag>> watchTags(String userId) {
    return (_db.select(_db.tags)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_tagFromRow).toList());
  }

  @override
  Future<Result<List<Tag>, AppError>> getTags(String userId) async {
    try {
      final rows =
          await (_db.select(_db.tags)
                ..where((t) => t.userId.equals(userId))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();
      return Success(rows.map(_tagFromRow).toList());
    } catch (e) {
      return Failure(AppError.database('Failed to get tags: $e'));
    }
  }

  @override
  Future<Result<void, AppError>> deleteTag(String tagId) async {
    try {
      await (_db.delete(_db.tags)..where((t) => t.id.equals(tagId))).go();
      return const Success(null);
    } catch (e) {
      return Failure(AppError.database('Failed to delete tag: $e'));
    }
  }

  @override
  Future<Result<void, AppError>> attachTagToTransaction({
    required int transactionId,
    required String tagId,
  }) async {
    try {
      // Check if already attached
      final existing =
          await (_db.select(_db.transactionTags)..where(
                (tt) =>
                    tt.transactionId.equals(transactionId) &
                    tt.tagId.equals(tagId),
              ))
              .getSingleOrNull();

      if (existing != null) {
        return const Success(null);
      }

      await _db
          .into(_db.transactionTags)
          .insert(
            db.TransactionTagsCompanion.insert(
              id: _generateId(),
              transactionId: transactionId,
              tagId: tagId,
              createdAt: DateTime.now(),
            ),
          );
      return const Success(null);
    } catch (e) {
      return Failure(AppError.database('Failed to attach tag: $e'));
    }
  }

  @override
  Future<Result<void, AppError>> detachTagFromTransaction({
    required int transactionId,
    required String tagId,
  }) async {
    try {
      await (_db.delete(_db.transactionTags)..where(
            (tt) =>
                tt.transactionId.equals(transactionId) & tt.tagId.equals(tagId),
          ))
          .go();
      return const Success(null);
    } catch (e) {
      return Failure(AppError.database('Failed to detach tag: $e'));
    }
  }

  @override
  Future<Result<List<Tag>, AppError>> getTransactionTags(
    int transactionId,
  ) async {
    try {
      final query = _db.select(_db.tags).join([
        innerJoin(
          _db.transactionTags,
          _db.transactionTags.tagId.equalsExp(_db.tags.id),
        ),
      ])..where(_db.transactionTags.transactionId.equals(transactionId));

      final rows = await query.get();
      final tags = rows.map((row) {
        return _tagFromRow(row.readTable(_db.tags));
      }).toList();

      return Success(tags);
    } catch (e) {
      return Failure(AppError.database('Failed to get transaction tags: $e'));
    }
  }

  @override
  Stream<List<Tag>> watchTransactionTags(int transactionId) {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.transactionTags,
        _db.transactionTags.tagId.equalsExp(_db.tags.id),
      ),
    ])..where(_db.transactionTags.transactionId.equals(transactionId));

    return query.watch().map((rows) {
      return rows.map((row) {
        return _tagFromRow(row.readTable(_db.tags));
      }).toList();
    });
  }

  @override
  Future<Result<List<int>, AppError>> getTransactionIdsByTag(
    String tagId,
  ) async {
    try {
      final rows = await (_db.select(
        _db.transactionTags,
      )..where((tt) => tt.tagId.equals(tagId))).get();
      return Success(rows.map((row) => row.transactionId).toList());
    } catch (e) {
      return Failure(
        AppError.database('Failed to get transactions by tag: $e'),
      );
    }
  }

  Tag _tagFromRow(db.Tag row) {
    return Tag(
      id: row.id,
      userId: row.userId,
      name: row.name,
      color: row.color,
      createdAt: row.createdAt,
    );
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
