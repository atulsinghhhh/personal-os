import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/currencies.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/models/profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// App settings: profile (name + default currency), appearance, sync
/// diagnostics entry point, and account (email + sign out).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Profile?> profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.huge,
        ),
        children: <Widget>[
          Text('PROFILE', style: _sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          profile.when(
            loading: () => const LoadingShimmer(height: 120),
            error: (Object error, _) =>
                const ErrorStateView(message: 'Could not load your profile.'),
            data: (Profile? value) => _ProfileSection(profile: value),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('APPEARANCE', style: _sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          const _AppearanceSection(),
          const SizedBox(height: AppSpacing.xl),
          Text('SYNC', style: _sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: 'Sync diagnostics',
              subtitle: 'Status, pending changes, conflicts',
              leading: const Icon(Icons.sync_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/review/settings/sync'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('ACCOUNT', style: _sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          const _AccountSection(),
        ],
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

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? current = profile;
    if (current == null) {
      return const AppCard(
        child: Text('Your profile has not synced yet — pull to sync and '
            'try again.'),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          AppListRow(
            title: 'Display name',
            subtitle: (current.displayName?.isEmpty ?? true)
                ? 'Not set'
                : current.displayName,
            leading: const Icon(Icons.person_outline),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _showDisplayNameSheet(context, ref, current),
          ),
          AppListRow(
            title: 'Default currency',
            subtitle: current.defaultCurrency ?? 'Not set',
            leading: const Icon(Icons.currency_exchange_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCurrencySheet(context, ref, current),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Changing this only affects new records — existing records '
              'keep their original currency.',
              style: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDisplayNameSheet(
    BuildContext context,
    WidgetRef ref,
    Profile current,
  ) {
    final TextEditingController name =
        TextEditingController(text: current.displayName ?? '');
    return showAppBottomSheet<void>(
      context: context,
      title: 'Display name',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: name,
              hint: 'How should we greet you?',
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: () async {
                final String value = name.text.trim();
                await ref.read(profileRepositoryProvider).save(
                      current.copyWith(
                        displayName: value.isEmpty ? null : value,
                        updatedAt: DateTime.now().toUtc(),
                      ),
                    );
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCurrencySheet(
    BuildContext context,
    WidgetRef ref,
    Profile current,
  ) {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Default currency',
      builder: (BuildContext sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.5,
          ),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final CurrencyInfo currency in supportedCurrencies)
                AppListRow(
                  title: currency.code,
                  subtitle: currency.name,
                  dense: true,
                  trailing: currency.code == current.defaultCurrency
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () async {
                    await ref.read(profileRepositoryProvider).save(
                          current.copyWith(
                            defaultCurrency: currency.code,
                            updatedAt: DateTime.now().toUtc(),
                          ),
                        );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Theme', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
              ),
            ],
            selected: <ThemeMode>{mode},
            onSelectionChanged: (Set<ThemeMode> selection) {
              ref.read(themeModeProvider.notifier).set(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? email =
        ref.watch(supabaseClientProvider).auth.currentUser?.email;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.alternate_email, size: 18),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  email ?? 'Signed in',
                  style: AppTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.danger,
            expand: true,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
