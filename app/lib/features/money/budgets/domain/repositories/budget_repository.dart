import '../entities/budget_entities.dart';
import '../../../../../shared/models/money.dart';

abstract class BudgetRepository {
  Stream<List<Budget>> watchAll();
  Future<Budget?> getById(String id);
  Future<void> create(Budget budget);
  Future<void> update(Budget budget);
  Future<void> delete(String id);

  Stream<List<BudgetItem>> watchItems(String budgetId);
  Future<void> upsertItem(BudgetItem item);
  Future<void> deleteItem(String id);

  /// Actual spend against a budget item's category within the budget's
  /// period, in the budget's currency.
  Future<Money> spentForItem(BudgetItem item, Budget budget);
}
