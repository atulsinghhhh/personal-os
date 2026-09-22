import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/date_selector.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../bills/domain/entities/bill.dart';
import '../widgets/money_ui.dart';

final StreamProvider<List<Bill>> billsProvider =
    StreamProvider<List<Bill>>((Ref ref) {
  return ref.watch(billRepositoryProvider).watchAll();
});

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Bill>> bills = ref.watch(billsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Bill'),
      ),
      body: bills.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LoadingShimmer(height: 100),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load bills.'),
        data: (List<Bill> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message: 'No bills yet — track rent, utilities, and more.',
              icon: Icons.receipt_long_outlined,
              ctaLabel: 'Add a bill',
              onCta: () => _showCreateSheet(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: all.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) =>
                _BillCard(bill: all[index]),
          );
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController name = TextEditingController();
    final TextEditingController amount = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    BillRecurrence recurrence = BillRecurrence.monthly;
    final String currency =
        ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return showAppBottomSheet<void>(
      context: context,
      title: 'New bill',
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: name,
                  hint: 'e.g. Rent',
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.md),
                CurrencyInput(
                  currencyCode: currency,
                  controller: amount,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.md),
                DateSelector(
                  label: 'Due date',
                  value: dueDate,
                  onChanged: (DateTime date) =>
                      setState(() => dueDate = date),
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<BillRecurrence>(
                  segments: const <ButtonSegment<BillRecurrence>>[
                    ButtonSegment<BillRecurrence>(
                      value: BillRecurrence.none,
                      label: Text('Once'),
                    ),
                    ButtonSegment<BillRecurrence>(
                      value: BillRecurrence.weekly,
                      label: Text('Weekly'),
                    ),
                    ButtonSegment<BillRecurrence>(
                      value: BillRecurrence.monthly,
                      label: Text('Monthly'),
                    ),
                    ButtonSegment<BillRecurrence>(
                      value: BillRecurrence.yearly,
                      label: Text('Yearly'),
                    ),
                  ],
                  selected: <BillRecurrence>{recurrence},
                  onSelectionChanged: (Set<BillRecurrence> selection) =>
                      setState(() => recurrence = selection.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save bill',
                  expand: true,
                  onPressed: () async {
                    final String? userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
                    final double? value = double.tryParse(amount.text);
                    if (userId == null ||
                        name.text.trim().isEmpty ||
                        value == null ||
                        value <= 0) {
                      return;
                    }
                    final DateTime now = DateTime.now().toUtc();
                    await ref.read(billRepositoryProvider).create(
                          Bill(
                            id: const Uuid().v4(),
                            userId: userId,
                            name: name.text.trim(),
                            amount:
                                Money(amount: value, currency: currency),
                            dueDate: DateTime.utc(
                              dueDate.year,
                              dueDate.month,
                              dueDate.day,
                            ),
                            recurrence: recurrence,
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BillCard extends ConsumerWidget {
  const _BillCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = DateTime.now();
    final DateTime todayUtc =
        DateTime.utc(today.year, today.month, today.day);
    final bool overdue = bill.dueDate.isBefore(todayUtc);
    final int daysAway = bill.dueDate.difference(todayUtc).inDays;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(bill.name, style: AppTypography.titleMedium),
              ),
              Text(
                formatMoney(bill.amount),
                style: AppTypography.currencyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            overdue
                ? 'Overdue — was due ${DateFormat.MMMd().format(bill.dueDate)}'
                : daysAway == 0
                    ? 'Due today'
                    : 'Due ${DateFormat.MMMd().format(bill.dueDate)} '
                        '(${daysAway}d)',
            style: AppTypography.labelSmall.copyWith(
              color: overdue
                  ? context.semanticColors.warning
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              AppButton(
                label: 'Mark paid',
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  final String? userId = ref
                      .read(supabaseClientProvider)
                      .auth
                      .currentUser
                      ?.id;
                  if (userId == null) return;
                  await ref
                      .read(billRepositoryProvider)
                      .markPaid(bill, userId: userId);
                },
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete bill',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(billRepositoryProvider).delete(bill.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
