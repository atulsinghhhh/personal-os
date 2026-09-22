import 'package:drift/drift.dart';

import 'sync_columns.dart';

class Notes extends Table with SyncableColumns {
  TextColumn get title => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get projectId => text().named('project_id').nullable()();
  TextColumn get goalId => text().named('goal_id').nullable()();
  TextColumn get taskId => text().named('task_id').nullable()();
}

class DailyReviews extends Table with SyncableColumns {
  DateTimeColumn get date => dateTime()();
  IntColumn get energy => integer().nullable()();
  IntColumn get focus => integer().nullable()();
  IntColumn get mood => integer().nullable()();
  TextColumn get accomplished => text().nullable()();
  TextColumn get blockedBy => text().named('blocked_by').nullable()();
  TextColumn get changeTomorrow =>
      text().named('change_tomorrow').nullable()();
}

class WeeklyReviews extends Table with SyncableColumns {
  DateTimeColumn get weekStart => dateTime().named('week_start')();
  TextColumn get wentWell => text().named('went_well').nullable()();
  TextColumn get wentPoorly => text().named('went_poorly').nullable()();
  TextColumn get learned => text().nullable()();
  TextColumn get stopDoing => text().named('stop_doing').nullable()();
  TextColumn get continueDoing =>
      text().named('continue_doing').nullable()();
  TextColumn get nextWeekFocus =>
      text().named('next_week_focus').nullable()();
}

class MonthlyReviews extends Table with SyncableColumns {
  DateTimeColumn get month => dateTime()();
  TextColumn get summary => text().nullable()();
  TextColumn get whatMattered => text().named('what_mattered').nullable()();
  TextColumn get whatWastedTime =>
      text().named('what_wasted_time').nullable()();
  TextColumn get whatWasWorthTheMoney =>
      text().named('what_was_worth_the_money').nullable()();
  TextColumn get changeNextMonth =>
      text().named('change_next_month').nullable()();
}
