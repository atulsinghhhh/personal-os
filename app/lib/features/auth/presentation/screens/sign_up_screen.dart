import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';

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

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Create your account', style: AppTypography.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A few details, then straight to planning.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'Name',
                  controller: _name,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
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
                  label: authState.isLoading ? 'Creating account…' : 'Sign up',
                  expand: true,
                  onPressed: authState.isLoading
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .signUp(
                              email: _email.text.trim(),
                              password: _password.text,
                              displayName: _name.text.trim().isEmpty
                                  ? null
                                  : _name.text.trim(),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
