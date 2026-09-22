import 'package:drift/drift.dart';

import 'sync_columns.dart';

class CalendarEvents extends Table with SyncableColumns {
  TextColumn get title => text()();
  DateTimeColumn get startAt => dateTime().named('start_at')();
  DateTimeColumn get endAt => dateTime().named('end_at')();
  BoolColumn get allDay =>
      boolean().named('all_day').withDefault(const Constant(false))();
  TextColumn get relatedTaskId =>
      text().named('related_task_id').nullable()();
}

class TimeBlocks extends Table with SyncableColumns {
  TextColumn get taskId => text().named('task_id').nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startAt => dateTime().named('start_at').nullable()();
  DateTimeColumn get endAt => dateTime().named('end_at').nullable()();
}

class FocusSessions extends Table with SyncableColumns {
  TextColumn get taskId => text().named('task_id').nullable()();
  DateTimeColumn get startedAt => dateTime().named('started_at')();
  DateTimeColumn get endedAt => dateTime().named('ended_at').nullable()();
  IntColumn get durationMinutes =>
      integer().named('duration_minutes').nullable()();
  BoolColumn get wasCompleted => boolean()
      .named('was_completed')
      .withDefault(const Constant(true))();
}

/// task_ids / focus_goal_ids / goal_ids / vision_ids are stored as
/// JSON-encoded text (SQLite has no native array type); the repository
/// layer encodes/decodes them.
class DailyPlans extends Table with SyncableColumns {
  DateTimeColumn get date => dateTime()();
  TextColumn get intention => text().nullable()();
  TextColumn get taskIdsJson =>
      text().named('task_ids_json').withDefault(const Constant('[]'))();
}

class WeeklyPlans extends Table with SyncableColumns {
  DateTimeColumn get weekStart => dateTime().named('week_start')();
  TextColumn get focusGoalIdsJson => text()
      .named('focus_goal_ids_json')
      .withDefault(const Constant('[]'))();
  TextColumn get outcomes => text().nullable()();
  TextColumn get reflection => text().nullable()();
}

class MonthlyPlans extends Table with SyncableColumns {
  DateTimeColumn get month => dateTime()();
  TextColumn get theme => text().nullable()();
  TextColumn get goalIdsJson =>
      text().named('goal_ids_json').withDefault(const Constant('[]'))();
}

class YearlyPlans extends Table with SyncableColumns {
  IntColumn get year => integer()();
  TextColumn get theme => text().nullable()();
  TextColumn get visionIdsJson =>
      text().named('vision_ids_json').withDefault(const Constant('[]'))();
}
