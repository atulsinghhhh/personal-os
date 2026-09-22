import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_pickers.dart';
import '../widgets/money_ui.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MoneyTransaction?> transaction =
        ref.watch(moneyTransactionByIdProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: transaction.value == null ||
                    transaction.value!.deletedAt != null
                ? null
                : () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: transaction.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load this transaction.'),
        data: (MoneyTransaction? data) {
          if (data == null || data.deletedAt != null) {
            return const EmptyStateView(message: 'Transaction not found.');
          }
          return _TransactionDetailBody(transaction: data);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'It will be removed from balances and reports. This syncs to '
            'your other devices.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(transactionRepositoryProvider).delete(transactionId);
    if (context.mounted) context.go('/money/transactions');
  }
}

class _TransactionDetailBody extends ConsumerWidget {
  const _TransactionDetailBody({required this.transaction});

  final MoneyTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];
    final List<FinancialAccount> accounts =
        ref.watch(moneyAllAccountsProvider).value ?? <FinancialAccount>[];
    final List<Project> projects =
        ref.watch(moneyProjectsProvider).value ?? <Project>[];

    final TransactionCategory? category = _categoryOf(categories);
    final Project? project = _projectOf(projects);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        if (transaction.conflictState ==
            TransactionConflictState.pendingReview) ...<Widget>[
          AppCard(
            color: context.semanticColors.conflict.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.warning_amber_rounded,
                      color: context.semanticColors.conflict,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This transaction has a sync conflict',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.semanticColors.conflict,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'It was edited on another device too. Review both versions '
                  'and choose what to keep.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Resolve conflict',
                  expand: true,
                  onPressed: () => context.go('/money/conflicts'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                transactionKindLabel(transaction.kind).toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SignedAmountText(
                transaction: transaction,
                style: AppTypography.currencyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                DateFormat('EEEE, MMM d, y · HH:mm')
                    .format(transaction.occurredAt.toLocal()),
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('DETAILS', style: moneySectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              AppListRow(
                title: 'Account',
                subtitle: _accountName(accounts),
                dense: true,
                leading: const Icon(Icons.account_balance_outlined),
              ),
              AppListRow(
                title: 'Category',
                subtitle: category?.name ?? 'None',
                dense: true,
                leading: const Icon(Icons.category_outlined),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editCategory(context, ref, categories),
              ),
              AppListRow(
                title: 'Project',
                subtitle: project?.title ?? 'Not linked',
                dense: true,
                leading: const Icon(Icons.folder_outlined),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editProject(context, ref, projects),
              ),
              AppListRow(
                title: 'Note',
                subtitle: (transaction.note?.isNotEmpty ?? false)
                    ? transaction.note
                    : 'No note',
                dense: true,
                leading: const Icon(Icons.notes_outlined),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editNote(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('RECORD', style: moneySectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              AppListRow(
                title: 'Created',
                subtitle: DateFormat.yMMMd()
                    .add_Hm()
                    .format(transaction.createdAt.toLocal()),
                dense: true,
              ),
              AppListRow(
                title: 'Last updated',
                subtitle: DateFormat.yMMMd()
                    .add_Hm()
                    .format(transaction.updatedAt.toLocal()),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  TransactionCategory? _categoryOf(List<TransactionCategory> categories) {
    for (final TransactionCategory category in categories) {
      if (category.id == transaction.categoryId) return category;
    }
    return null;
  }

  Project? _projectOf(List<Project> projects) {
    for (final Project project in projects) {
      if (project.id == transaction.projectId) return project;
    }
    return null;
  }

  String _accountName(List<FinancialAccount> accounts) {
    for (final FinancialAccount account in accounts) {
      if (account.id == transaction.accountId) return account.name;
    }
    return 'Unknown account';
  }

  Future<void> _save(WidgetRef ref, MoneyTransaction updated) async {
    final DateTime now = DateTime.now().toUtc();
    await ref.read(transactionRepositoryProvider).update(
          updated.copyWith(clientUpdatedAt: now, updatedAt: now),
        );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    List<TransactionCategory> categories,
  ) async {
    final CategoryKind kind = transaction.kind == TransactionKind.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final List<TransactionCategory> matching = categories
        .where((TransactionCategory c) => c.kind == kind)
        .toList(growable: false);
    final TransactionCategory? picked =
        await showCategoryPicker(context, categories: matching);
    if (picked == null) return;
    await _save(ref, transaction.copyWith(categoryId: picked.id));
  }

  Future<void> _editProject(
    BuildContext context,
    WidgetRef ref,
    List<Project> projects,
  ) async {
    final ProjectPick? picked = await showProjectPicker(
      context,
      projects: projects,
      allowClear: true,
    );
    if (picked == null) return;
    await _save(ref, transaction.copyWith(projectId: picked.project?.id));
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final TextEditingController note =
        TextEditingController(text: transaction.note ?? '');
    await showAppBottomSheet<void>(
      context: context,
      title: 'Edit note',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: note,
              hint: 'What was it for?',
              autofocus: true,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: () async {
                final String value = note.text.trim();
                await _save(
                  ref,
                  transaction.copyWith(note: value.isEmpty ? null : value),
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
}
