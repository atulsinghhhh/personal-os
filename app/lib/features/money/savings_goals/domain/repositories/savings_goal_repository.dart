import '../entities/savings_goal.dart';

abstract class SavingsGoalRepository {
  Stream<List<SavingsGoal>> watchAll();
  Future<SavingsGoal?> getById(String id);
  Future<void> create(SavingsGoal goal);
  Future<void> update(SavingsGoal goal);
  Future<void> delete(String id);
}
