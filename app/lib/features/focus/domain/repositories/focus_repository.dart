import '../entities/focus_session.dart';

abstract class FocusSessionRepository {
  Stream<List<FocusSession>> watchByTask(String taskId);
  Stream<List<FocusSession>> watchForDateRange(DateTime start, DateTime end);
  Stream<FocusSession?> watchActive();
  Future<void> create(FocusSession session);
  Future<void> update(FocusSession session);
  Future<void> delete(String id);

  /// Sum of completed session minutes for a task (source of truth for
  /// Task.actualMinutes and Project/Goal time-invested rollups).
  Future<int> totalMinutesForTask(String taskId);
  Future<int> totalMinutesForProject(String projectId);
  Future<int> totalMinutesForGoal(String goalId);
}
