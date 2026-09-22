import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../debts/domain/entities/debt.dart';
import '../widgets/money_ui.dart';

final StreamProvider<List<Debt>> debtsProvider =
    StreamProvider<List<Debt>>((Ref ref) {
  return ref.watch(debtRepositoryProvider).watchAll();
});

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Debt>> debts = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debt')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Debt'),
      ),
      body: debts.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LoadingShimmer(height: 100),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load debts.'),
        data: (List<Debt> all) {
          if (all.isEmpty) {
            return const EmptyStateView(
              message: 'No debts tracked. Long may it last.',
              icon: Icons.credit_score_outlined,
            );
          }

          final Map<String, double> totalByCurrency = <String, double>{};
          for (final Debt debt in all) {
            totalByCurrency.update(
              debt.currency,
              (double v) => v + debt.currentBalance,
              ifAbsent: () => debt.currentBalance,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'TOTAL DEBT',
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final MapEntry<String, double> entry
                        in totalByCurrency.entries)
                      Text(
                        formatMoney(
                          Money(amount: entry.value, currency: entry.key),
                        ),
                        style: AppTypography.currencyLarge,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final Debt debt in all) ...<Widget>[
                _DebtCard(debt: debt),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController name = TextEditingController();
    final TextEditingController balance = TextEditingController();
    final TextEditingController rate = TextEditingController();
    final TextEditingController minimum = TextEditingController();
    final String currency =
        ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return showAppBottomSheet<void>(
      context: context,
      title: 'New debt',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: name,
              hint: 'e.g. Car loan',
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            CurrencyInput(
              currencyCode: currency,
              controller: balance,
              autofocus: false,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: rate,
              hint: 'Interest rate % per year (optional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: minimum,
              hint: 'Minimum payment (optional)',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save debt',
              expand: true,
              onPressed: () async {
                final String? userId = ref
                    .read(supabaseClientProvider)
                    .auth
                    .currentUser
                    ?.id;
                final double? value = double.tryParse(balance.text);
                if (userId == null ||
                    name.text.trim().isEmpty ||
                    value == null ||
                    value <= 0) {
                  return;
                }
                final DateTime now = DateTime.now().toUtc();
                await ref.read(debtRepositoryProvider).create(
                      Debt(
                        id: const Uuid().v4(),
                        userId: userId,
                        name: name.text.trim(),
                        principal: value,
                        currentBalance: value,
                        currency: currency,
                        interestRatePercent: double.tryParse(rate.text),
                        minimumPayment: double.tryParse(minimum.text),
                        paymentFrequency: PaymentFrequency.monthly,
                        createdAt: now,
                        updatedAt: now,
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
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double paidFraction = debt.principal <= 0
        ? 0
        : ((debt.principal - debt.currentBalance) / debt.principal)
            .clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(debt.name, style: AppTypography.titleMedium),
              ),
              Text(
                formatMoney(
                  Money(
                    amount: debt.currentBalance,
                    currency: debt.currency,
                  ),
                ),
                style: AppTypography.currencyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: paidFraction),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(paidFraction * 100).toStringAsFixed(0)}% of the original '
            '${formatMoney(Money(amount: debt.principal, currency: debt.currency))} paid'
            '${debt.interestRatePercent == null ? '' : ' · ${debt.interestRatePercent}%/yr'}'
            '${debt.minimumPayment == null ? '' : ' · min ${formatMoney(Money(amount: debt.minimumPayment!, currency: debt.currency))}'}',
            style: AppTypography.labelSmall.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              AppButton(
                label: 'Update balance',
                variant: AppButtonVariant.text,
                onPressed: () => _showUpdateBalanceSheet(context, ref),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete debt',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(debtRepositoryProvider).delete(debt.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateBalanceSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController balance = TextEditingController(
      text: debt.currentBalance.toStringAsFixed(0),
    );
    return showAppBottomSheet<void>(
      context: context,
      title: 'Update balance — ${debt.name}',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CurrencyInput(
              currencyCode: debt.currency,
              controller: balance,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: () async {
                final double? value = double.tryParse(balance.text);
                if (value == null || value < 0) return;
                await ref.read(debtRepositoryProvider).update(
                      debt.copyWith(
                        currentBalance: value,
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
}
