import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../data/ai_planning_service.dart';

/// AI-assisted planning: the app assembles a compact context from LOCAL
/// data, the assistant proposes, and NOTHING is applied until the user taps
/// Apply. Deferred/unknown task ids in the proposal are ignored safely.
class AiPlanningScreen extends ConsumerStatefulWidget {
  const AiPlanningScreen({super.key});

  @override
  ConsumerState<AiPlanningScreen> createState() => _AiPlanningScreenState();
}

class _AiPlanningScreenState extends ConsumerState<AiPlanningScreen> {
  bool _loading = false;
  AiPlanResult? _result;
  List<Task> _contextTasks = <Task>[];
  bool _applied = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _result = null;
      _applied = false;
    });

    // Context: open tasks (today + unscheduled + overdue), goals, and the
    // time remaining today — all from the local database.
    final List<Task> allTasks =
        await ref.read(taskRepositoryProvider).watchAll().first;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime.utc(now.year, now.month, now.day);
    final List<Task> open = allTasks
        .where(
          (Task t) =>
              t.status != TaskStatus.done &&
              t.status != TaskStatus.cancelled &&
              (t.scheduledDate == null ||
                  !t.scheduledDate!.isAfter(today)),
        )
        .take(30)
        .toList(growable: false);
    final List<Goal> goals =
        (await ref.read(goalRepositoryProvider).watchAll().first)
            .where((Goal g) => g.status == GoalStatus.active)
            .take(10)
            .toList(growable: false);

    final int minutesLeftToday =
        (DateTime(now.year, now.month, now.day, 22).difference(now).inMinutes)
            .clamp(0, 16 * 60);

    final Map<String, dynamic> context = <String, dynamic>{
      'now_local': now.toIso8601String(),
      'available_minutes_today': minutesLeftToday,
      'tasks': <Map<String, dynamic>>[
        for (final Task t in open)
          <String, dynamic>{
            'id': t.id,
            'title': t.title,
            'priority': t.priority,
            'estimate_minutes': t.estimateMinutes,
            'due_date': t.dueDate?.toIso8601String().substring(0, 10),
            'scheduled_today': t.scheduledDate == today,
          },
      ],
      'goals': <Map<String, dynamic>>[
        for (final Goal g in goals)
          <String, dynamic>{'id': g.id, 'title': g.title},
      ],
    };

    final AiPlanResult result = await ref
        .read(aiPlanningServiceProvider)
        .propose(mode: 'daily', context: context);

    if (mounted) {
      setState(() {
        _loading = false;
        _result = result;
        _contextTasks = open;
      });
    }
  }

  Future<void> _apply() async {
    final Map<String, dynamic>? proposal = _result?.proposal;
    if (proposal == null) return;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime.utc(now.year, now.month, now.day);
    final Map<String, Task> byId = <String, Task>{
      for (final Task t in _contextTasks) t.id: t,
    };

    // Top three get priority 3..1 and today's schedule; other scheduled
    // slots just land on today.
    final List<dynamic> topThree =
        (proposal['top_three'] as List?) ?? <dynamic>[];
    final List<dynamic> schedule =
        (proposal['schedule'] as List?) ?? <dynamic>[];

    int priority = 3;
    for (final dynamic id in topThree) {
      final Task? task = byId[id];
      if (task == null) continue;
      await ref.read(taskRepositoryProvider).update(
            task.copyWith(
              scheduledDate: today,
              priority: priority,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      priority = (priority - 1).clamp(0, 3);
    }
    for (final dynamic slot in schedule) {
      final String? id = (slot as Map)['task_id'] as String?;
      final Task? task = byId[id];
      if (task == null || (topThree.contains(id))) continue;
      await ref.read(taskRepositoryProvider).update(
            task.copyWith(
              scheduledDate: today,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    }
    if (mounted) setState(() => _applied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI planning')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Plan my day', style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The assistant reads your open tasks, goals, and the time '
                  'left today, then proposes a schedule. Nothing changes '
                  'until you apply it.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _loading ? 'Thinking…' : 'Generate proposal',
                  expand: true,
                  onPressed: _loading ? null : _generate,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading) const LoadingShimmer(height: 160),
          if (_result != null && !_result!.isOk)
            AppCard(
              child: Row(
                children: <Widget>[
                  Icon(
                    _result!.notConfigured
                        ? Icons.key_off_outlined
                        : Icons.error_outline,
                    color: context.semanticColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(_result!.errorMessage!)),
                ],
              ),
            ),
          if (_result?.proposal != null)
            _ProposalView(
              proposal: _result!.proposal!,
              tasksById: <String, Task>{
                for (final Task t in _contextTasks) t.id: t,
              },
              applied: _applied,
              onApply: _apply,
            ),
        ],
      ),
    );
  }
}

class _ProposalView extends StatelessWidget {
  const _ProposalView({
    required this.proposal,
    required this.tasksById,
    required this.applied,
    required this.onApply,
  });

  final Map<String, dynamic> proposal;
  final Map<String, Task> tasksById;
  final bool applied;
  final Future<void> Function() onApply;

  String _titleFor(dynamic id) => tasksById[id]?.title ?? '(unknown task)';

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<dynamic> topThree =
        (proposal['top_three'] as List?) ?? <dynamic>[];
    final List<dynamic> schedule =
        (proposal['schedule'] as List?) ?? <dynamic>[];
    final List<dynamic> deferred =
        (proposal['deferred'] as List?) ?? <dynamic>[];
    final List<dynamic> warnings =
        (proposal['warnings'] as List?) ?? <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (proposal['summary'] is String)
          AppCard(
            color: scheme.primaryContainer,
            child: Text(
              proposal['summary'] as String,
              style: AppTypography.titleMedium.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (topThree.isNotEmpty) ...<Widget>[
          Text('PROPOSED TOP 3', style: _label(context)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < topThree.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '${i + 1}. ${_titleFor(topThree[i])}',
                      style: AppTypography.bodyLarge,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (schedule.isNotEmpty) ...<Widget>[
          Text('PROPOSED SCHEDULE', style: _label(context)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final dynamic slot in schedule)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 104,
                          child: Text(
                            ((slot as Map)['slot'] as String?) ?? '—',
                            style: AppTypography.labelLarge,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _titleFor(slot['task_id']),
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (deferred.isNotEmpty) ...<Widget>[
          Text('SUGGESTED TO DEFER', style: _label(context)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final dynamic item in deferred)
                  Text(
                    '• ${_titleFor((item as Map)['task_id'])} — '
                    '${item['reason'] ?? ''}',
                    style: AppTypography.bodyMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        for (final dynamic warning in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '⚠ $warning',
              style: AppTypography.labelMedium.copyWith(
                color: context.semanticColors.warning,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: applied ? 'Applied ✓' : 'Apply this plan',
          expand: true,
          onPressed: applied ? null : () => onApply(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Applying schedules the listed tasks for today and sets Top 3 '
          'priorities. Everything stays editable.',
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static TextStyle _label(BuildContext context) =>
      AppTypography.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      );
}
