import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/luma_scaffold.dart';
import '../../../../luma/widgets/luma_text_field.dart';
import '../controllers/auth_controller.dart';

/// Design 03 "Sign up".
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> authState = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return LumaScreen(
      padding: const EdgeInsets.fromLTRB(24, 52, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthBackRow(),
          const SizedBox(height: 24),
          Text('Create your space', style: lumaSerif(size: 40, height: 1.05)),
          const SizedBox(height: 8),
          Text(
            'One account for your plans, reviews and money. Only you can see it.',
            style: lumaSans(size: 15, color: LumaColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 24),
          const LumaSecondaryButton(
            label: 'Continue with Apple',
            leading: LumaIcon(LumaIcons.lock, size: 18),
          ),
          const SizedBox(height: 10),
          const LumaSecondaryButton(
            label: 'Continue with Google',
            leading: LumaIcon(LumaIcons.mail, size: 18),
          ),
          const SizedBox(height: 24),
          const AuthOrDivider(),
          const SizedBox(height: 24),
          LumaTextField(
            label: 'What should we call you?',
            controller: _name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          LumaTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          LumaTextField(
            label: 'Password',
            controller: _password,
            obscure: true,
            textInputAction: TextInputAction.done,
            helper: 'At least 8 characters',
          ),
          const SizedBox(height: 24),
          LumaPrimaryButton(
            label:
                authState.isLoading ? 'Creating account…' : 'Create account',
            onTap: authState.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signUp(
                      email: _email.text.trim(),
                      password: _password.text,
                      displayName: _name.text.trim().isEmpty
                          ? null
                          : _name.text.trim(),
                    ),
          ),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              style: lumaSans(size: 12.5, height: 1.5, color: LumaColors.ink3),
              children: [
                const TextSpan(text: 'By continuing you agree to the '),
                TextSpan(
                    text: 'Terms',
                    style: lumaSans(size: 12.5, color: LumaColors.accent)),
                const TextSpan(text: ' and '),
                TextSpan(
                    text: 'Privacy Policy',
                    style: lumaSans(size: 12.5, color: LumaColors.accent)),
                const TextSpan(text: '. No ads, ever.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              style: lumaSans(size: 14, color: LumaColors.ink2),
              children: [
                const TextSpan(text: 'Already have an account? '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => context.pushReplacement(RoutePaths.signIn),
                    child: Text('Log in',
                        style: lumaSans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: LumaColors.accent)),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 44px "‹ Back" header row shared by the auth screens.
class AuthBackRow extends StatelessWidget {
  const AuthBackRow({super.key, this.label = 'Back', this.onTap, this.trailing});

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap ??
                () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.welcome),
            child: Row(
              children: [
                const LumaIcon(LumaIcons.chevronLeft,
                    size: 22, color: LumaColors.ink2),
                const SizedBox(width: 2),
                Text(label, style: lumaSans(size: 15, color: LumaColors.ink2)),
              ],
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
            child: SizedBox(
                height: 1, child: ColoredBox(color: LumaColors.hairline))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: lumaSans(size: 12, color: LumaColors.ink3)),
        ),
        const Expanded(
            child: SizedBox(
                height: 1, child: ColoredBox(color: LumaColors.hairline))),
      ],
    );
  }
}
