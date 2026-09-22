import '../entities/plan_entities.dart';

abstract class DailyPlanRepository {
  Stream<DailyPlan?> watchForDate(DateTime date);
  Future<void> upsert(DailyPlan plan);
}

abstract class WeeklyPlanRepository {
  Stream<WeeklyPlan?> watchForWeek(DateTime weekStart);
  Future<void> upsert(WeeklyPlan plan);
}

abstract class MonthlyPlanRepository {
  Stream<MonthlyPlan?> watchForMonth(DateTime month);
  Future<void> upsert(MonthlyPlan plan);
}

abstract class YearlyPlanRepository {
  Stream<YearlyPlan?> watchForYear(int year);
  Future<void> upsert(YearlyPlan plan);
}
