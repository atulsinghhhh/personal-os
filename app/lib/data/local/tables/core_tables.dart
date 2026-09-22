import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// Local cache of the single signed-in user's profile. Keyed by the
/// Supabase auth user id (not a separate uuid) since there is exactly one
/// profile per user.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().named('display_name').nullable()();
  TextColumn get defaultCurrency =>
      text().named('default_currency').nullable()();
  DateTimeColumn get onboardingCompletedAt =>
      dateTime().named('onboarding_completed_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(false))();
  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class LifeAreas extends Table with SyncableColumns {
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
}

class Visions extends Table with SyncableColumns {
  TextColumn get lifeAreaId => text().named('life_area_id').nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get horizonYears => integer().named('horizon_years').nullable()();
}

class Goals extends Table with SyncableColumns {
  TextColumn get visionId => text().named('vision_id').nullable()();
  TextColumn get lifeAreaId => text().named('life_area_id').nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get targetDate => dateTime().named('target_date').nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('active'))();
}

class GoalMetrics extends Table with SyncableColumns {
  TextColumn get goalId => text().named('goal_id')();
  TextColumn get name => text()();
  TextColumn get unit => text().nullable()();
  RealColumn get targetValue => real().named('target_value').nullable()();
  RealColumn get currentValue =>
      real().named('current_value').withDefault(const Constant(0))();
}

class Milestones extends Table with SyncableColumns {
  TextColumn get goalId => text().named('goal_id')();
  TextColumn get title => text()();
  DateTimeColumn get targetDate => dateTime().named('target_date').nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
}

class Projects extends Table with SyncableColumns {
  TextColumn get milestoneId => text().named('milestone_id').nullable()();
  TextColumn get goalId => text().named('goal_id').nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
}

class Tasks extends Table with SyncableColumns {
  TextColumn get projectId => text().named('project_id').nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('todo'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();
  DateTimeColumn get scheduledDate =>
      dateTime().named('scheduled_date').nullable()();
  IntColumn get estimateMinutes =>
      integer().named('estimate_minutes').nullable()();
  IntColumn get actualMinutes =>
      integer().named('actual_minutes').withDefault(const Constant(0))();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
}

/// No soft-delete/updated_at — mirrors the Postgres table, which is a plain
/// link row (hard-deleted when a dependency is removed).
class TaskDependencies extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get taskId => text().named('task_id')();
  TextColumn get dependsOnTaskId => text().named('depends_on_task_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
