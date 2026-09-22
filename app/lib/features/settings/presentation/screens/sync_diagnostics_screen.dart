import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_providers.dart';

/// Read-only view of the sync engine's health: current phase, queue counts,
/// last success/error, plus a manual "Sync now" kick.
class SyncDiagnosticsScreen extends ConsumerWidget {
  const SyncDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SyncStatus> status = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync diagnostics')),
      body: status.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LoadingShimmer(height: 200),
        ),
        error: (Object error, _) =>
            const ErrorStateView(message: 'Could not read sync status.'),
        data: (SyncStatus value) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          children: <Widget>[
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: <Widget>[
                  _StatusRow(label: 'Status', value: _phaseLabel(value.phase)),
                  _StatusRow(
                    label: 'Pending changes',
                    value: '${value.pendingCount}',
                  ),
                  _StatusRow(label: 'Failed', value: '${value.failedCount}'),
                  _StatusRow(
                    label: 'Conflicts',
                    value: '${value.conflictCount}',
                  ),
                  _StatusRow(
                    label: 'Last synced',
                    value: value.lastSyncedAt == null
                        ? 'Never'
                        : DateFormat('MMM d, HH:mm').format(
                            value.lastSyncedAt!.toLocal(),
                          ),
                  ),
                ],
              ),
            ),
            if (value.lastError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: Theme.of(context)
                    .colorScheme
                    .error
                    .withValues(alpha: 0.12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'LAST ERROR',
                      style: AppTypography.labelSmall.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(value.lastError!, style: AppTypography.bodyMedium),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Sync now',
              icon: Icons.sync,
              expand: true,
              onPressed: () => ref.read(syncEngineProvider).kick(),
            ),
          ],
        ),
      ),
    );
  }

  static String _phaseLabel(SyncPhase phase) {
    return switch (phase) {
      SyncPhase.idle => 'Idle',
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.error => 'Error',
    };
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: AppTypography.titleMedium),
        ],
      ),
    );
  }
}
