import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/models/profile.dart';
import '../../../capture/presentation/quick_capture_sheet.dart';
import '../../../future/domain/entities/future_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../providers/today_providers.dart';

/// The home command center: greeting + direction, today's priorities and
/// tasks, focus/money snapshots. Everything reads from local Drift streams,
/// so this screen renders instantly with no network.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasks = ref.watch(todayTasksProvider);
    final bool isOnline = ref.watch(isOnlineProvider).value ?? true;
    final int conflictCount = ref.watch(conflictCountProvider).value ?? 0;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showQuickCaptureSheet(context),
        tooltip: 'Quick capture',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!isOnline) const OfflineBanner(),
            if (conflictCount > 0)
              ConflictBanner(
                count: conflictCount,
                onTap: () {
                  // Money tab owns conflict resolution; navigate there.
                  DefaultTabController.maybeOf(context);
                },
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(syncEngineProvider).kick(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.huge,
                  ),
                  children: <Widget>[
                    const _Header(),
                    const SizedBox(height: AppSpacing.xl),
                    const _DirectionCard(),
                    const SizedBox(height: AppSpacing.xl),
                    Text('TOP 3', style: _sectionLabel(context)),
                    const SizedBox(height: AppSpacing.sm),
                    _TopPriorities(tasks: tasks),
                    const SizedBox(height: AppSpacing.xl),
                    Text("TODAY'S TASKS", style: _sectionLabel(context)),
                    const SizedBox(height: AppSpacing.sm),
                    _TaskList(tasks: tasks),
                    const SizedBox(height: AppSpacing.xl),
                    Text('PROGRESS', style: _sectionLabel(context)),
                    const SizedBox(height: AppSpacing.sm),
                    const _ProgressRow(),
                    const SizedBox(height: AppSpacing.xl),
                    Text("TODAY'S MONEY", style: _sectionLabel(context)),
                    const SizedBox(height: AppSpacing.sm),
                    const _MoneyToday(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _sectionLabel(BuildContext context) {
    return AppTypography.labelMedium.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 1.2,
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(currentProfileProvider).value;
    final DateTime now = DateTime.now();
    final String greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final String name = profile?.displayName ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          name.isEmpty ? greeting : '$greeting, $name',
          style: AppTypography.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          DateFormat('EEEE · MMMM d').format(now),
          style: AppTypography.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DirectionCard extends ConsumerWidget {
  const _DirectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Vision? vision = ref.watch(directionProvider).value;
    if (vision == null) return const SizedBox.shrink();

    return AppCard(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'YOUR DIRECTION',
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            vision.title,
            style: AppTypography.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPriorities extends ConsumerWidget {
  const _TopPriorities({required this.tasks});

  final AsyncValue<List<Task>> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return tasks.when(
      loading: () => const LoadingShimmer(height: 120),
      error: (Object error, _) =>
          ErrorStateView(message: 'Could not load tasks.'),
      data: (List<Task> all) {
        final List<Task> open = all
            .where((Task t) => t.status != TaskStatus.done)
            .take(3)
            .toList(growable: false);
        if (open.isEmpty) {
          return const AppCard(
            child: Text('No priorities yet — capture a task to get started.'),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < open.length; i++)
                _TaskRow(task: open[i], leadingIndex: i + 1),
            ],
          ),
        );
      },
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});

  final AsyncValue<List<Task>> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return tasks.when(
      loading: () => const LoadingShimmer(height: 160),
      error: (Object error, _) =>
          ErrorStateView(message: 'Could not load tasks.'),
      data: (List<Task> all) {
        if (all.isEmpty) {
          return EmptyStateView(
            message: 'Nothing scheduled for today.',
            icon: Icons.wb_sunny_outlined,
            ctaLabel: 'Add a task',
            onCta: () => showQuickCaptureSheet(context),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (final Task task in all) _TaskRow(task: task),
            ],
          ),
        );
      },
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, this.leadingIndex});

  final Task task;
  final int? leadingIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool done = task.status == TaskStatus.done;

    return CheckboxListTile(
      value: done,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (bool? checked) {
        ref.read(taskRepositoryProvider).update(
              task.copyWith(
                status:
                    (checked ?? false) ? TaskStatus.done : TaskStatus.todo,
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      },
      title: Text(
        leadingIndex == null ? task.title : '$leadingIndex. ${task.title}',
        style: AppTypography.bodyLarge.copyWith(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    );
  }
}

class _ProgressRow extends ConsumerWidget {
  const _ProgressRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasks = ref.watch(todayTasksProvider);
    final int focusMinutes =
        ref.watch(todayFocusMinutesProvider).value ?? 0;

    final int total = tasks.value?.length ?? 0;
    final int done = tasks.value
            ?.where((Task t) => t.status == TaskStatus.done)
            .length ??
        0;

    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            label: 'Deep work',
            value:
                '${focusMinutes ~/ 60}h ${(focusMinutes % 60).toString().padLeft(2, '0')}m',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(label: 'Tasks', value: '$done / $total'),
        ),
      ],
    );
  }
}

class _MoneyToday extends ConsumerWidget {
  const _MoneyToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Money>> spent = ref.watch(todaySpentProvider);

    return spent.when(
      loading: () => const LoadingShimmer(height: 72),
      error: (Object error, _) =>
          ErrorStateView(message: 'Could not load spending.'),
      data: (List<Money> amounts) {
        if (amounts.isEmpty) {
          return const AppCard(child: Text('Nothing spent today.'));
        }
        return Row(
          children: <Widget>[
            for (final Money money in amounts) ...<Widget>[
              Expanded(
                child: _StatCard(
                  label: 'Spent today',
                  value: formatMoney(money),
                  valueColor: context.semanticColors.expense,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
          ]..removeLast(),
        );
      },
    );
  }
}

String formatMoney(Money money) {
  final NumberFormat format = NumberFormat.simpleCurrency(
    name: money.currency,
  );
  return format.format(money.amount);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.currencyMedium.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
