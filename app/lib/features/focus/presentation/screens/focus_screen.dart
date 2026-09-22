import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../../today/presentation/providers/today_providers.dart';
import '../../domain/entities/focus_session.dart';

/// Design 11 "Focus mode": a dark, distraction-free stopwatch inside a
/// progress ring. Finishing records a FocusSession and rolls the minutes up
/// into the task's actualMinutes.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, required this.taskId});

  final String taskId;

  /// The session length the ring fills toward.
  static const Duration target = Duration(minutes: 50);

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
          _elapsed =
              DateTime.now().difference(_startedAt) - _pausedAccumulated;
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
        _pausedAccumulated += DateTime.now().difference(_pauseStartedAt!);
        _pauseStartedAt = null;
      } else {
        _pauseStartedAt = DateTime.now();
      }
      _paused = !_paused;
    });
  }

  Future<void> _finish({required bool markDone}) async {
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
            task.copyWith(
              actualMinutes: total,
              status: markDone ? TaskStatus.done : task.status,
              updatedAt: now,
            ),
          );
    }

    ref.invalidate(chainForTaskProvider(widget.taskId));
    if (mounted) {
      if (markDone) {
        context.go(RoutePaths.today);
      } else {
        context.go('/future/task/${widget.taskId}');
      }
    }
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
    final EntityChain? chain =
        ref.watch(chainForTaskProvider(widget.taskId)).value;
    final int todayFocusMinutes =
        ref.watch(todayFocusMinutesProvider).value ?? 0;
    final double progress =
        (_elapsed.inSeconds / FocusScreen.target.inSeconds).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: LumaColors.darkGround,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const LumaIcon(LumaIcons.moon,
                          size: 15, color: LumaColors.darkInk2),
                      const SizedBox(width: 8),
                      Text('Do not disturb is on',
                          style: lumaSans(
                              size: 13, color: LumaColors.darkInk2)),
                    ],
                  ),
                  Semantics(
                    label: 'End session',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          _finishing ? null : () => _finish(markDone: false),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: LumaIcon(LumaIcons.close,
                              size: 20, color: LumaColors.darkInk2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 290,
                height: 290,
                child: CustomPaint(
                  painter: _RingPainter(progress: progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Semantics(
                          liveRegion: false,
                          child: Text(
                            _clock,
                            style: lumaSerif(
                                size: 84,
                                height: 1,
                                color: LumaColors.darkInk),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'of ${FocusScreen.target.inMinutes} min',
                            style: lumaSans(
                                size: 12.5, color: LumaColors.darkInk2)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 38),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: <Widget>[
                    Text(
                      chain?.task?.title ?? '',
                      textAlign: TextAlign.center,
                      style: lumaSans(
                          size: 20,
                          weight: FontWeight.w500,
                          color: LumaColors.darkInk),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chain?.project?.title ?? '',
                      textAlign: TextAlign.center,
                      style:
                          lumaSans(size: 13, color: LumaColors.darkInk2),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Semantics(
                label: _paused ? 'Resume' : 'Pause',
                button: true,
                child: GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: LumaColors.darkInk2, width: 1.5),
                    ),
                    child: Center(
                      child: _paused
                          ? const LumaPlayIcon(
                              size: 26, color: LumaColors.darkInk)
                          : const LumaIcon(LumaIcons.pause,
                              size: 26,
                              color: LumaColors.darkInk,
                              strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(_paused ? 'Resume' : 'Pause',
                  style: lumaSans(size: 13, color: LumaColors.darkInk2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.only(top: 16, bottom: 20),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: LumaColors.darkHairline)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Today',
                        style:
                            lumaSans(size: 13, color: LumaColors.darkInk2)),
                    Text('${_fmtMinutes(todayFocusMinutes)} focused',
                        style: lumaSans(
                            size: 14,
                            weight: FontWeight.w500,
                            color: LumaColors.darkInk)),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap:
                          _finishing ? null : () => _finish(markDone: true),
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text(
                              _finishing ? 'Saving…' : 'Mark done',
                              style: lumaSans(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: LumaColors.darkAccent)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtMinutes(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// 290pt ring: hairline track + accent progress arc from 12 o'clock.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double radius = 130;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = LumaColors.darkHairline;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final Paint arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = LumaColors.darkAccent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
