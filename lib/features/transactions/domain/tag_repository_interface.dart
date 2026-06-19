import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import '../domain/models/tag_model.dart';

/// Repository interface for tag operations.
///
/// Handles CRUD operations for tags and many-to-many relationship
/// with transactions via TransactionTags junction table.
abstract class TagRepositoryInterface {
  /// Creates a new tag.
  Future<Result<Tag, AppError>> createTag(Tag tag);

  /// Gets all tags for a user.
  Stream<List<Tag>> watchTags(String userId);

  /// Gets all tags for a user (one-time read).
  Future<Result<List<Tag>, AppError>> getTags(String userId);

  /// Deletes a tag by ID.
  Future<Result<void, AppError>> deleteTag(String tagId);

  /// Attaches a tag to a transaction.
  Future<Result<void, AppError>> attachTagToTransaction({
    required int transactionId,
    required String tagId,
  });

  /// Detaches a tag from a transaction.
  Future<Result<void, AppError>> detachTagFromTransaction({
    required int transactionId,
    required String tagId,
  });

  /// Gets all tags for a specific transaction.
  Future<Result<List<Tag>, AppError>> getTransactionTags(int transactionId);

  /// Gets all tags for a specific transaction (stream).
  Stream<List<Tag>> watchTransactionTags(int transactionId);

  /// Gets all transaction IDs that have a specific tag.
  Future<Result<List<int>, AppError>> getTransactionIdsByTag(String tagId);
}
