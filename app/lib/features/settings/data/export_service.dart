import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/repository_providers.dart';
import '../../goals/domain/entities/goal_entities.dart';
import '../../money/accounts/domain/entities/financial_account.dart';
import '../../money/transactions/data/transaction_repositories_impl.dart'
    show transactionKindToWire;
import '../../money/transactions/domain/entities/transaction_entities.dart';
import '../../notes/domain/entities/note.dart';
import '../../projects/data/task_repository_impl.dart'
    show taskStatusToWire;
import '../../projects/domain/entities/project_entities.dart';

/// Builds CSV/JSON export files from the LOCAL database and returns the
/// written file paths. The user owns their data; nothing leaves the device
/// unless they choose to share the file.
class ExportService {
  ExportService(this._ref);

  final Ref _ref;

  Future<String> exportTransactionsCsv() async {
    final List<MoneyTransaction> transactions = await _ref
        .read(transactionRepositoryProvider)
        .watchRecent(100000)
        .first;
    final List<FinancialAccount> accounts = await _ref
        .read(financialAccountRepositoryProvider)
        .watchAll(includeArchived: true)
        .first;
    final List<TransactionCategory> categories = await _ref
        .read(transactionCategoryRepositoryProvider)
        .watchAll()
        .first;
    final List<Project> projects =
        await _ref.read(projectRepositoryProvider).watchAll().first;

    String nameOf<T>(
      List<T> items,
      String? id,
      String Function(T) idOf,
      String Function(T) nameOf,
    ) {
      if (id == null) return '';
      for (final T item in items) {
        if (idOf(item) == id) return nameOf(item);
      }
      return '';
    }

    final StringBuffer csv = StringBuffer(
      'id,date,kind,amount,currency,account,category,project,note\n',
    );
    for (final MoneyTransaction t in transactions) {
      csv.writeln(
        <String>[
          t.id,
          t.occurredAt.toIso8601String(),
          transactionKindToWire(t.kind),
          t.amount.amount.toString(),
          t.amount.currency,
          nameOf<FinancialAccount>(
            accounts,
            t.accountId,
            (FinancialAccount a) => a.id,
            (FinancialAccount a) => a.name,
          ),
          nameOf<TransactionCategory>(
            categories,
            t.categoryId,
            (TransactionCategory c) => c.id,
            (TransactionCategory c) => c.name,
          ),
          nameOf<Project>(
            projects,
            t.projectId,
            (Project p) => p.id,
            (Project p) => p.title,
          ),
          t.note ?? '',
        ].map(_escapeCsv).join(','),
      );
    }
    return _write('transactions', 'csv', csv.toString());
  }

  Future<String> exportTasksCsv() async {
    final List<Task> tasks =
        await _ref.read(taskRepositoryProvider).watchAll().first;
    final List<Project> projects =
        await _ref.read(projectRepositoryProvider).watchAll().first;

    final Map<String, String> projectNames = <String, String>{
      for (final Project p in projects) p.id: p.title,
    };

    final StringBuffer csv = StringBuffer(
      'id,title,status,project,scheduled,due,actual_minutes\n',
    );
    for (final Task t in tasks) {
      csv.writeln(
        <String>[
          t.id,
          t.title,
          taskStatusToWire(t.status),
          projectNames[t.projectId] ?? '',
          t.scheduledDate?.toIso8601String().substring(0, 10) ?? '',
          t.dueDate?.toIso8601String().substring(0, 10) ?? '',
          t.actualMinutes.toString(),
        ].map(_escapeCsv).join(','),
      );
    }
    return _write('tasks', 'csv', csv.toString());
  }

  Future<String> exportEverythingJson() async {
    final List<Goal> goals =
        await _ref.read(goalRepositoryProvider).watchAll().first;
    final List<Project> projects =
        await _ref.read(projectRepositoryProvider).watchAll().first;
    final List<Task> tasks =
        await _ref.read(taskRepositoryProvider).watchAll().first;
    final List<MoneyTransaction> transactions = await _ref
        .read(transactionRepositoryProvider)
        .watchRecent(100000)
        .first;
    final List<FinancialAccount> accounts = await _ref
        .read(financialAccountRepositoryProvider)
        .watchAll(includeArchived: true)
        .first;
    final List<Note> notes =
        await _ref.read(noteRepositoryProvider).watchAll().first;

    final Map<String, dynamic> dump = <String, dynamic>{
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'goals': <Map<String, dynamic>>[
        for (final Goal g in goals)
          <String, dynamic>{
            'id': g.id,
            'title': g.title,
            'description': g.description,
            'status': g.status.name,
            'life_area_id': g.lifeAreaId,
            'vision_id': g.visionId,
            'target_date':
                g.targetDate?.toIso8601String().substring(0, 10),
          },
      ],
      'projects': <Map<String, dynamic>>[
        for (final Project p in projects)
          <String, dynamic>{
            'id': p.id,
            'title': p.title,
            'status': p.status.name,
            'goal_id': p.goalId,
            'milestone_id': p.milestoneId,
          },
      ],
      'tasks': <Map<String, dynamic>>[
        for (final Task t in tasks)
          <String, dynamic>{
            'id': t.id,
            'title': t.title,
            'status': taskStatusToWire(t.status),
            'project_id': t.projectId,
            'scheduled':
                t.scheduledDate?.toIso8601String().substring(0, 10),
            'due': t.dueDate?.toIso8601String().substring(0, 10),
            'actual_minutes': t.actualMinutes,
          },
      ],
      'accounts': <Map<String, dynamic>>[
        for (final FinancialAccount a in accounts)
          <String, dynamic>{
            'id': a.id,
            'name': a.name,
            'type': a.type.name,
            'currency': a.openingBalance.currency,
            'opening_balance': a.openingBalance.amount,
          },
      ],
      'transactions': <Map<String, dynamic>>[
        for (final MoneyTransaction t in transactions)
          <String, dynamic>{
            'id': t.id,
            'kind': transactionKindToWire(t.kind),
            'amount': t.amount.amount,
            'currency': t.amount.currency,
            'occurred_at': t.occurredAt.toIso8601String(),
            'account_id': t.accountId,
            'category_id': t.categoryId,
            'project_id': t.projectId,
            'goal_id': t.goalId,
            'note': t.note,
          },
      ],
      'notes': <Map<String, dynamic>>[
        for (final Note n in notes)
          <String, dynamic>{
            'id': n.id,
            'title': n.title,
            'body': n.body,
            'project_id': n.projectId,
            'goal_id': n.goalId,
            'task_id': n.taskId,
          },
      ],
    };

    return _write(
      'everything',
      'json',
      const JsonEncoder.withIndent('  ').convert(dump),
    );
  }

  Future<String> _write(String kind, String extension, String content) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final File file =
        File('${dir.path}/personal_os_${kind}_$stamp.$extension');
    await file.writeAsString(content);
    return file.path;
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

final Provider<ExportService> exportServiceProvider =
    Provider<ExportService>((Ref ref) => ExportService(ref));
