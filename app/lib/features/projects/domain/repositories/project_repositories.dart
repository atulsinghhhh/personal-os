import '../entities/project_entities.dart';

abstract class ProjectRepository {
  Stream<List<Project>> watchAll();
  Stream<List<Project>> watchByGoal(String goalId);
  Stream<List<Project>> watchByMilestone(String milestoneId);
  Future<Project?> getById(String id);
  Future<void> create(Project project);
  Future<void> update(Project project);
  Future<void> delete(String id);
}

abstract class TaskRepository {
  Stream<List<Task>> watchAll();
  Stream<List<Task>> watchByProject(String projectId);
  Stream<List<Task>> watchScheduledForDate(DateTime date);
  Stream<List<Task>> watchInbox();
  Future<Task?> getById(String id);
  Future<void> create(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);

  Stream<List<TaskDependency>> watchDependencies(String taskId);
  Future<void> addDependency(TaskDependency dependency);
  Future<void> removeDependency(String dependencyId);
}
