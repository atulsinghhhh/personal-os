import '../entities/review_entities.dart';

abstract class DailyReviewRepository {
  Stream<DailyReview?> watchForDate(DateTime date);
  Stream<List<DailyReview>> watchRecent(int limit);
  Future<void> upsert(DailyReview review);
}

abstract class WeeklyReviewRepository {
  Stream<WeeklyReview?> watchForWeek(DateTime weekStart);
  Future<void> upsert(WeeklyReview review);
}

abstract class MonthlyReviewRepository {
  Stream<MonthlyReview?> watchForMonth(DateTime month);
  Future<void> upsert(MonthlyReview review);
}
