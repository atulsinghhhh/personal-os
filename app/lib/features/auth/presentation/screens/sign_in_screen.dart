import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/luma_logo.dart';
import '../../../../luma/widgets/luma_scaffold.dart';
import '../../../../luma/widgets/luma_text_field.dart';
import '../controllers/auth_controller.dart';
import 'sign_up_screen.dart' show AuthBackRow, AuthOrDivider;

/// Design 04 "Log in".
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
    });

    return LumaScreen(
      padding: const EdgeInsets.fromLTRB(24, 52, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthBackRow(),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: LumaLogo(size: 40)),
          const SizedBox(height: 14),
          Text('Welcome back', style: lumaSerif(size: 40, height: 1.05)),
          const SizedBox(height: 24),
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
            trailingLabel: Text('Forgot?',
                style: lumaSans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: LumaColors.accent)),
          ),
          const SizedBox(height: 24),
          LumaPrimaryButton(
            label: authState.isLoading ? 'Logging in…' : 'Log in',
            onTap: authState.isLoading
                ? null
                : () =>
                    ref.read(authControllerProvider.notifier).signInWithPassword(
                          email: _email.text.trim(),
                          password: _password.text,
                        ),
          ),
          const SizedBox(height: 24),
          const LumaSecondaryButton(
            label: 'Use a passkey',
            leading: LumaIcon(LumaIcons.passkey, size: 18),
          ),
          const SizedBox(height: 24),
          const AuthOrDivider(),
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
          Text.rich(
            TextSpan(
              style: lumaSans(size: 14, color: LumaColors.ink2),
              children: [
                const TextSpan(text: 'New here? '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => context.pushReplacement(RoutePaths.signUp),
                    child: Text('Create an account',
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
