import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../data/export_service.dart';

/// Data export: CSV for spreadsheets, JSON for everything. Files are
/// written locally; sharing is the user's explicit choice.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String? _busy;

  Future<void> _run(
    String label,
    Future<String> Function() export,
  ) async {
    setState(() => _busy = label);
    try {
      final String path = await export();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $path')),
      );
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(path)]),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExportService service = ref.read(exportServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Data export')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Your data is yours', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Exports are written to this device. Sharing them '
                  'anywhere is your choice in the next step.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _busy == 'transactions'
                ? 'Exporting…'
                : 'Transactions (CSV)',
            expand: true,
            onPressed: _busy != null
                ? null
                : () => _run('transactions', service.exportTransactionsCsv),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _busy == 'tasks' ? 'Exporting…' : 'Tasks (CSV)',
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: _busy != null
                ? null
                : () => _run('tasks', service.exportTasksCsv),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _busy == 'everything'
                ? 'Exporting…'
                : 'Everything (JSON)',
            expand: true,
            variant: AppButtonVariant.secondary,
            onPressed: _busy != null
                ? null
                : () => _run('everything', service.exportEverythingJson),
          ),
        ],
      ),
    );
  }
}
