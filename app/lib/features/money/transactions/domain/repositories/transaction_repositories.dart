import '../entities/transaction_entities.dart';
import '../../../../../shared/models/money.dart';

abstract class TransactionRepository {
  Stream<List<MoneyTransaction>> watchRecent(int limit);
  Stream<List<MoneyTransaction>> watchByAccount(String accountId);
  Stream<List<MoneyTransaction>> watchByProject(String projectId);
  Stream<List<MoneyTransaction>> watchByGoal(String goalId);
  Stream<List<MoneyTransaction>> watchForRange(DateTime start, DateTime end);
  Future<MoneyTransaction?> getById(String id);
  Future<void> create(MoneyTransaction transaction);
  Future<void> update(MoneyTransaction transaction);
  Future<void> delete(String id);

  /// Money-invested rollups (expenses linked to a project/goal), grouped by
  /// currency since amounts in different currencies must never be summed.
  Future<List<Money>> totalSpentForProject(String projectId);
  Future<List<Money>> totalSpentForGoal(String goalId);

  Stream<List<TransactionConflict>> watchUnresolvedConflicts();
  Future<void> resolveConflictKeepLocal(String conflictId);
  Future<void> resolveConflictKeepServer(String conflictId);
  Future<void> resolveConflictMerged(
    String conflictId,
    MoneyTransaction merged,
  );
}

abstract class TransactionCategoryRepository {
  Stream<List<TransactionCategory>> watchAll();
  Future<void> create(TransactionCategory category);
  Future<void> update(TransactionCategory category);
  Future<void> delete(String id);

  /// Inserts the default category set for a new user (first onboarding run).
  Future<void> seedDefaults(String userId, {required String currency});
}
