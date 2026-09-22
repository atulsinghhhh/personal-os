import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_logo.dart';

/// Design 02 "Welcome" — the signed-out landing screen: brand lockup,
/// promise, and the Future → Goal → Project → Today ladder.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LumaLogo(size: 30),
                const SizedBox(width: 10),
                Text('Luma', style: lumaSerif(size: 20)),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Point your days at the life you want.',
              style: lumaSerif(size: 44, height: 1.04),
            ),
            const SizedBox(height: 20),
            Text(
              'Decide where you’re headed, give today one clear job, and watch your time, tasks and money pull in the same direction.',
              style: lumaSans(size: 16, height: 1.5, color: LumaColors.ink2),
            ),
            const SizedBox(height: 32),
            const _TimelineRow(
              eyebrow: 'Future',
              child: _SerifTitle('Work independently, stay strong'),
            ),
            const _TimelineRow(
              eyebrow: 'Goal',
              child: _SansTitle('Financial independence'),
            ),
            const _TimelineRow(
              eyebrow: 'Project',
              child: _SansTitle('Livqeno launch'),
            ),
            const _TimelineRow(
              eyebrow: 'Today',
              active: true,
              last: true,
              child: _SansTitle('Finish SDK documentation · 09:00',
                  color: LumaColors.accent),
            ),
            const Spacer(),
            LumaPrimaryButton(
              label: 'Get started',
              onTap: () => context.push(RoutePaths.signUp),
            ),
            const SizedBox(height: 12),
            LumaTextButton(
              label: 'I already have an account',
              onTap: () => context.push(RoutePaths.signIn),
            ),
          ],
        ),
      ),
    );
  }
}

class _SerifTitle extends StatelessWidget {
  const _SerifTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: lumaSerif(size: 22));
}

class _SansTitle extends StatelessWidget {
  const _SansTitle(this.text, {this.color = LumaColors.ink});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: lumaSans(size: 16, weight: FontWeight.w500, color: color));
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.eyebrow,
    required this.child,
    this.active = false,
    this.last = false,
  });

  final String eyebrow;
  final Widget child;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 12,
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: active
                        ? const BoxDecoration(
                            color: LumaColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: LumaColors.accentSoft,
                                spreadRadius: 4,
                              ),
                            ],
                          )
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: LumaColors.ink, width: 1.5),
                          ),
                  ),
                  if (!last) ...[
                    const SizedBox(height: 6),
                    Expanded(
                        child: Container(width: 1, color: LumaColors.hairline)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(eyebrow.toUpperCase(), style: lumaEyebrow()),
                    const SizedBox(height: 4),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
