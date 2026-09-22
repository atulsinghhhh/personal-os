import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';
import 'sign_up_screen.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Welcome back', style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Sign in to continue planning your future.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: authState.isLoading ? 'Signing in…' : 'Sign in',
                    expand: true,
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithPassword(
                                email: _email.text.trim(),
                                password: _password.text,
                              ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: "Don't have an account? Sign up",
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SignUpScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
