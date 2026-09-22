@Tags(<String>['integration'])
library;

import 'package:app/core/sync/outbox/outbox_writer.dart';
import 'package:app/core/sync/sync_engine.dart';
import 'package:app/data/local/database.dart' show AppDatabase;
import 'package:app/features/calendar/data/calendar_repositories_impl.dart';
import 'package:app/features/focus/data/focus_repository_impl.dart';
import 'package:app/features/future/data/future_repositories_impl.dart';
import 'package:app/features/goals/data/goal_repository_impl.dart';
import 'package:app/features/goals/domain/entities/goal_entities.dart';
import 'package:app/features/future/domain/entities/future_entities.dart';
import 'package:app/features/focus/domain/entities/focus_session.dart';
import 'package:app/features/money/accounts/data/account_repository_impl.dart';
import 'package:app/features/money/accounts/domain/entities/financial_account.dart';
import 'package:app/features/money/transactions/data/transaction_repositories_impl.dart';
import 'package:app/features/money/transactions/domain/entities/transaction_entities.dart';
import 'package:app/features/projects/data/project_repository_impl.dart';
import 'package:app/features/projects/data/task_repository_impl.dart';
import 'package:app/features/projects/domain/entities/project_entities.dart';
import 'package:app/shared/models/money.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// The Phase 1 core-loop regression guard, at the repository level, against
/// the real local Supabase stack (`supabase start` required):
///
///   vision -> life area -> goal -> milestone -> project -> task
///   -> focus session (time invested) -> expense linked to project
///   -> rollups visible -> everything lands in Supabase after sync
///   -> a fresh local DB reconstructs it all via pull.
const String supabaseUrl = 'http://127.0.0.1:54321';
const String publishableKey = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

void main() {
  late SupabaseClient client;
  late String userId;

  setUpAll(() async {
    client = SupabaseClient(
      supabaseUrl,
      publishableKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final AuthResponse response = await client.auth.signUp(
      email: 'core-loop-${DateTime.now().millisecondsSinceEpoch}@example.com',
      password: 'CoreLoop123!',
    );
    userId = response.user!.id;
  });

  tearDownAll(() async {
    await client.auth.signOut();
    await client.dispose();
  });

  test('full core loop: future -> execution -> money -> rollups -> sync',
      () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final OutboxWriter outbox = OutboxWriter(db);
    final SyncEngine engine = SyncEngine(
      db: db,
      client: client,
      currentUserId: () => userId,
    );
    addTearDown(engine.dispose);
    void noop() {}

    final DriftLifeAreaRepository lifeAreas =
        DriftLifeAreaRepository(db, outbox, noop);
    final DriftVisionRepository visions =
        DriftVisionRepository(db, outbox, noop);
    final DriftGoalRepository goals = DriftGoalRepository(db, outbox, noop);
    final DriftProjectRepository projects =
        DriftProjectRepository(db, outbox, noop);
    final DriftTaskRepository tasks = DriftTaskRepository(db, outbox, noop);
    final DriftFocusSessionRepository focus =
        DriftFocusSessionRepository(db, outbox, noop);
    final DriftFinancialAccountRepository accounts =
        DriftFinancialAccountRepository(db, outbox, noop);
    final DriftTransactionRepository transactions =
        DriftTransactionRepository(db, outbox, noop);
    // Exercised only to prove the calendar repo constructs and queries.
    DriftTimeBlockRepository(db, outbox, noop);

    final DateTime now = DateTime.now().toUtc();
    final String lifeAreaId = const Uuid().v4();
    final String visionId = const Uuid().v4();
    final String goalId = const Uuid().v4();
    final String milestoneId = const Uuid().v4();
    final String projectId = const Uuid().v4();
    final String taskId = const Uuid().v4();
    final String accountId = const Uuid().v4();
    final String expenseId = const Uuid().v4();

    // 1. Future: life area -> vision -> goal -> milestone.
    await lifeAreas.create(LifeArea(
      id: lifeAreaId,
      userId: userId,
      name: 'Business',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ));
    await visions.create(Vision(
      id: visionId,
      userId: userId,
      lifeAreaId: lifeAreaId,
      title: 'Financial independence through software',
      createdAt: now,
      updatedAt: now,
    ));
    await goals.create(Goal(
      id: goalId,
      userId: userId,
      visionId: visionId,
      lifeAreaId: lifeAreaId,
      title: 'Build profitable SaaS',
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
    ));
    await goals.createMilestone(Milestone(
      id: milestoneId,
      userId: userId,
      goalId: goalId,
      title: 'Launch',
      status: MilestoneStatus.pending,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ));

    // 2. Execution: project -> task.
    await projects.create(Project(
      id: projectId,
      userId: userId,
      goalId: goalId,
      milestoneId: milestoneId,
      title: 'Livqeno',
      status: ProjectStatus.active,
      createdAt: now,
      updatedAt: now,
    ));
    await tasks.create(Task(
      id: taskId,
      userId: userId,
      projectId: projectId,
      title: 'Publish SDK documentation',
      status: TaskStatus.todo,
      priority: 1,
      scheduledDate: DateTime.utc(now.year, now.month, now.day),
      actualMinutes: 0,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ));

    // 3. Time invested: a completed focus session on the task.
    await focus.create(FocusSession(
      id: const Uuid().v4(),
      userId: userId,
      taskId: taskId,
      startedAt: now.subtract(const Duration(minutes: 45)),
      endedAt: now,
      durationMinutes: 45,
      wasCompleted: true,
      createdAt: now,
      updatedAt: now,
    ));

    // 4. Money invested: an expense linked to the project AND goal.
    await accounts.create(FinancialAccount(
      id: accountId,
      userId: userId,
      name: 'HDFC',
      type: AccountType.bank,
      openingBalance: const Money(amount: 10000, currency: 'INR'),
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ));
    await transactions.create(MoneyTransaction(
      id: expenseId,
      userId: userId,
      accountId: accountId,
      projectId: projectId,
      goalId: goalId,
      kind: TransactionKind.expense,
      amount: const Money(amount: 2500, currency: 'INR'),
      occurredAt: now,
      note: 'Laptop accessories',
      clientUpdatedAt: now,
      serverUpdatedAt: now,
      conflictState: TransactionConflictState.none,
      createdAt: now,
      updatedAt: now,
    ));

    // 5. Rollups are visible locally BEFORE any sync (offline-first).
    expect(await focus.totalMinutesForTask(taskId), 45);
    expect(await focus.totalMinutesForProject(projectId), 45);
    expect(await focus.totalMinutesForGoal(goalId), 45);

    final List<Money> projectSpend =
        await transactions.totalSpentForProject(projectId);
    expect(projectSpend.single.amount, 2500);
    expect(projectSpend.single.currency, 'INR');
    final List<Money> goalSpend =
        await transactions.totalSpentForGoal(goalId);
    expect(goalSpend.single.amount, 2500);

    final Money balance = await accounts.currentBalance(accountId);
    expect(balance.amount, 7500); // 10000 opening - 2500 expense

    // 6. Complete the task; sync everything up.
    final Task? created = await tasks.getById(taskId);
    await tasks.update(created!.copyWith(
      status: TaskStatus.done,
      actualMinutes: 45,
      updatedAt: DateTime.now().toUtc(),
    ));
    await engine.kick();

    final List<dynamic> remoteTasks =
        await client.from('tasks').select().eq('id', taskId);
    expect(
      (remoteTasks.single as Map<String, dynamic>)['status'],
      'done',
    );
    final List<dynamic> remoteTxn =
        await client.from('transactions').select().eq('id', expenseId);
    expect(
      (remoteTxn.single as Map<String, dynamic>)['project_id'],
      projectId,
    );

    // 7. Cold start on a "new device": a fresh local DB reconstructs the
    // full chain via pull, and the rollups still hold.
    final AppDatabase db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final SyncEngine engine2 = SyncEngine(
      db: db2,
      client: client,
      currentUserId: () => userId,
    );
    addTearDown(engine2.dispose);
    await engine2.kick();

    final OutboxWriter outbox2 = OutboxWriter(db2);
    final DriftTaskRepository tasks2 =
        DriftTaskRepository(db2, outbox2, noop);
    final DriftFocusSessionRepository focus2 =
        DriftFocusSessionRepository(db2, outbox2, noop);
    final DriftTransactionRepository transactions2 =
        DriftTransactionRepository(db2, outbox2, noop);

    final Task? pulledTask = await tasks2.getById(taskId);
    expect(pulledTask, isNotNull);
    expect(pulledTask!.status, TaskStatus.done);
    expect(pulledTask.projectId, projectId);
    expect(await focus2.totalMinutesForGoal(goalId), 45);
    final List<Money> pulledSpend =
        await transactions2.totalSpentForProject(projectId);
    expect(pulledSpend.single.amount, 2500);
  });
}
