import '../entities/financial_goal.dart';

abstract class FinancialGoalRepository {
  Stream<List<FinancialGoal>> watchAll();
  Stream<List<FinancialGoal>> watchByLinkedGoal(String goalId);
  Future<FinancialGoal?> getById(String id);
  Future<void> create(FinancialGoal goal);
  Future<void> update(FinancialGoal goal);
  Future<void> delete(String id);
}
