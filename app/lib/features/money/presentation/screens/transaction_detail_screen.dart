import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
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
      backgroundColor: LumaColors.ground,
      body: transaction.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(
            child: Text('Could not load this transaction.',
                style: lumaSans(size: 14, color: LumaColors.ink3))),
        data: (MoneyTransaction? data) {
          if (data == null || data.deletedAt != null) {
            return Center(
                child: Text('Transaction not found.',
                    style: lumaSans(size: 14, color: LumaColors.ink3)));
          }
          return _TransactionDetailBody(
            transactionId: transactionId,
            transaction: data,
          );
        },
      ),
    );
  }
}

class _TransactionDetailBody extends ConsumerWidget {
  const _TransactionDetailBody({
    required this.transactionId,
    required this.transaction,
  });

  final String transactionId;
  final MoneyTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];
    final List<FinancialAccount> accounts =
        ref.watch(moneyAllAccountsProvider).value ?? <FinancialAccount>[];
    final List<Project> projects = ref.watch(moneyProjectsProvider).value ?? <Project>[];

    final TransactionCategory? category = _categoryOf(categories);
    final Project? project = _projectOf(projects);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go('${RoutePaths.money}/transactions'),
                child: Row(
                  children: <Widget>[
                    const LumaIcon(LumaIcons.chevronLeft,
                        size: 22, color: LumaColors.ink2),
                    const SizedBox(width: 2),
                    Text('Back', style: lumaSans(size: 15, color: LumaColors.ink2)),
                  ],
                ),
              ),
            ),
            if (transaction.deletedAt == null)
              Semantics(
                label: 'Delete',
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _confirmDelete(context, ref),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: LumaIcon(LumaIcons.close, size: 20, color: LumaColors.negative),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (transaction.conflictState == TransactionConflictState.pendingReview) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LumaColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(LumaRadius.button),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const LumaIcon(LumaIcons.flag, size: 15, color: LumaColors.warning),
                    const SizedBox(width: 8),
                    Text('Sync conflict',
                        style: lumaSans(
                            size: 14, weight: FontWeight.w500, color: LumaColors.warning)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'It was edited on another device too. Review both versions and choose what to keep.',
                  style: lumaSans(size: 13, color: LumaColors.ink2),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => context.go('/money/conflicts'),
                  child: Text('Resolve conflict',
                      style: lumaSans(
                          size: 13, weight: FontWeight.w500, color: LumaColors.accent)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        LumaEyebrow(transactionKindLabel(transaction.kind)),
        const SizedBox(height: 10),
        SignedAmountText(
          transaction: transaction,
          style: lumaSerif(size: LumaType.metric, height: 1),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEEE, MMM d, y · HH:mm').format(transaction.occurredAt.toLocal()),
          style: lumaSans(size: 13, color: LumaColors.ink3),
        ),
        const SizedBox(height: 28),
        const LumaEyebrow('Details'),
        LumaMetaRow(label: 'Account', value: _accountName(accounts)),
        LumaMetaRow(
          label: 'Category',
          value: category?.name ?? 'None',
          onTap: () => _editCategory(context, ref, categories),
        ),
        LumaMetaRow(
          label: 'Project',
          value: project?.title ?? 'Not linked',
          onTap: () => _editProject(context, ref, projects),
        ),
        LumaMetaRow(
          label: 'Note',
          value: (transaction.note?.isNotEmpty ?? false) ? transaction.note! : 'No note',
          onTap: () => _editNote(context, ref),
        ),
        const SizedBox(height: 28),
        const LumaEyebrow('Record'),
        LumaMetaRow(
          label: 'Created',
          value: DateFormat.yMMMd().add_Hm().format(transaction.createdAt.toLocal()),
        ),
        LumaMetaRow(
          label: 'Last updated',
          value: DateFormat.yMMMd().add_Hm().format(transaction.updatedAt.toLocal()),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'It will be removed from balances and reports. This syncs to your other devices.',
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

  Future<void> _save(WidgetRef ref, MoneyTransaction updated) async {
    final DateTime now = DateTime.now().toUtc();
    await ref
        .read(transactionRepositoryProvider)
        .update(updated.copyWith(clientUpdatedAt: now, updatedAt: now));
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    List<TransactionCategory> categories,
  ) async {
    final CategoryKind kind =
        transaction.kind == TransactionKind.income ? CategoryKind.income : CategoryKind.expense;
    final List<TransactionCategory> matching =
        categories.where((TransactionCategory c) => c.kind == kind).toList(growable: false);
    final TransactionCategory? picked = await showCategoryPicker(context, categories: matching);
    if (picked == null) return;
    await _save(ref, transaction.copyWith(categoryId: picked.id));
  }

  Future<void> _editProject(
    BuildContext context,
    WidgetRef ref,
    List<Project> projects,
  ) async {
    final ProjectPick? picked =
        await showProjectPicker(context, projects: projects, allowClear: true);
    if (picked == null) return;
    await _save(ref, transaction.copyWith(projectId: picked.project?.id));
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final TextEditingController note = TextEditingController(text: transaction.note ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LumaColors.ground,
      barrierColor: const Color(0x521B1B19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: LumaColors.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const LumaEyebrow('Edit note'),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  autofocus: true,
                  maxLines: 3,
                  style: lumaSans(size: 15),
                  cursorColor: LumaColors.ink,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'What was it for?',
                    hintStyle: lumaSans(size: 15, color: LumaColors.ink3),
                  ),
                ),
                const SizedBox(height: 24),
                LumaPrimaryButton(
                  label: 'Save',
                  height: 52,
                  onTap: () async {
                    final String value = note.text.trim();
                    await _save(ref, transaction.copyWith(note: value.isEmpty ? null : value));
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
