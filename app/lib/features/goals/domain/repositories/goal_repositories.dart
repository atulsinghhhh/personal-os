import '../entities/goal_entities.dart';

abstract class GoalRepository {
  Stream<List<Goal>> watchAll();
  Stream<List<Goal>> watchByLifeArea(String lifeAreaId);
  Stream<List<Goal>> watchByVision(String visionId);
  Future<Goal?> getById(String id);
  Future<void> create(Goal goal);
  Future<void> update(Goal goal);
  Future<void> delete(String id);

  Stream<List<GoalMetric>> watchMetrics(String goalId);
  Future<void> createMetric(GoalMetric metric);
  Future<void> updateMetric(GoalMetric metric);
  Future<void> deleteMetric(String id);

  Stream<List<Milestone>> watchMilestones(String goalId);
  Future<void> createMilestone(Milestone milestone);
  Future<void> updateMilestone(Milestone milestone);
  Future<void> deleteMilestone(String id);
}
