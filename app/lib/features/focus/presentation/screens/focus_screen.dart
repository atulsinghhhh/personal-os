import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../../../shared/widgets/breadcrumb_chain.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/focus_session.dart';

/// Distraction-free focus mode: a big stopwatch, the task, and WHY it
/// matters (the chain up to the future it serves). Finishing records a
/// FocusSession and rolls the minutes up into the task's actualMinutes.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late final DateTime _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  Duration _pausedAccumulated = Duration.zero;
  DateTime? _pauseStartedAt;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused && mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startedAt) -
              _pausedAccumulated;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _togglePause() {
    setState(() {
      if (_paused) {
        _pausedAccumulated +=
            DateTime.now().difference(_pauseStartedAt!);
        _pauseStartedAt = null;
      } else {
        _pauseStartedAt = DateTime.now();
      }
      _paused = !_paused;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    final DateTime now = DateTime.now().toUtc();
    final int minutes = _elapsed.inMinutes.clamp(0, 24 * 60);

    await ref.read(focusSessionRepositoryProvider).create(
          FocusSession(
            id: const Uuid().v4(),
            userId: userId,
            taskId: widget.taskId,
            startedAt: _startedAt.toUtc(),
            endedAt: now,
            durationMinutes: minutes,
            wasCompleted: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Roll up into the task's cached actualMinutes.
    final Task? task =
        await ref.read(taskRepositoryProvider).getById(widget.taskId);
    if (task != null) {
      final int total = await ref
          .read(focusSessionRepositoryProvider)
          .totalMinutesForTask(widget.taskId);
      await ref.read(taskRepositoryProvider).update(
            task.copyWith(actualMinutes: total, updatedAt: now),
          );
    }

    ref.invalidate(chainForTaskProvider(widget.taskId));
    if (mounted) context.go('/future/task/${widget.taskId}');
  }

  String get _clock {
    final int hours = _elapsed.inHours;
    final int minutes = _elapsed.inMinutes % 60;
    final int seconds = _elapsed.inSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForTaskProvider(widget.taskId));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Text(
                _clock,
                style: AppTypography.displayLarge.copyWith(
                  fontSize: 64,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                chain.value?.task?.title ?? '',
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge,
              ),
              if (_paused)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Paused',
                    style: AppTypography.labelLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const Spacer(),
              if (chain.value != null) BreadcrumbChain(chain: chain.value!),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: _paused ? 'Resume' : 'Pause',
                      variant: AppButtonVariant.secondary,
                      onPressed: _togglePause,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: _finishing ? 'Saving…' : 'Finish',
                      onPressed: _finishing ? null : _finish,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
