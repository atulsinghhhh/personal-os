import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../subscriptions/domain/entities/subscription.dart';
import '../widgets/money_ui.dart';

final StreamProvider<List<Subscription>> subscriptionsProvider =
    StreamProvider<List<Subscription>>((Ref ref) {
  return ref.watch(subscriptionRepositoryProvider).watchAll();
});

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Subscription>> subscriptions =
        ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Subscription'),
      ),
      body: subscriptions.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LoadingShimmer(height: 100),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load subscriptions.'),
        data: (List<Subscription> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message: 'No subscriptions tracked yet.',
              icon: Icons.subscriptions_outlined,
              ctaLabel: 'Add a subscription',
              onCta: () => _showCreateSheet(context, ref),
            );
          }

          // Monthly/annualized totals per currency, active subs only —
          // transparent arithmetic (weekly x52/12, yearly /12).
          final Map<String, double> monthlyByCurrency = <String, double>{};
          for (final Subscription s in all.where(
            (Subscription s) => s.isActive,
          )) {
            monthlyByCurrency.update(
              s.amount.currency,
              (double v) => v + subscriptionMonthlyCost(s),
              ifAbsent: () => subscriptionMonthlyCost(s),
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
                      'MONTHLY COST (ACTIVE)',
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final MapEntry<String, double> entry
                        in monthlyByCurrency.entries) ...<Widget>[
                      Text(
                        formatMoney(
                          Money(amount: entry.value, currency: entry.key),
                        ),
                        style: AppTypography.currencyLarge,
                      ),
                      Text(
                        '≈ ${formatMoney(Money(amount: entry.value * 12, currency: entry.key))}/year '
                        '(weekly ×52⁄12, yearly ÷12)',
                        style: AppTypography.labelSmall.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (monthlyByCurrency.isEmpty)
                      Text(
                        'No active subscriptions.',
                        style: AppTypography.bodyMedium,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    for (final Subscription s in all)
                      AppListRow(
                        title: s.service,
                        subtitle: <String>[
                          '${formatMoney(s.amount)} · ${_cycleLabel(s.billingCycle)}',
                          if (s.renewalDate != null)
                            'renews ${DateFormat.MMMd().format(s.renewalDate!)}',
                          if (!s.isActive) 'inactive',
                        ].join(' · '),
                        trailing: IconButton(
                          tooltip:
                              s.isActive ? 'Mark inactive' : 'Mark active',
                          icon: Icon(
                            s.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          onPressed: () => ref
                              .read(subscriptionRepositoryProvider)
                              .update(
                                s.copyWith(
                                  isActive: !s.isActive,
                                  updatedAt: DateTime.now().toUtc(),
                                ),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _cycleLabel(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'weekly',
        BillingCycle.monthly => 'monthly',
        BillingCycle.yearly => 'yearly',
      };

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController service = TextEditingController();
    final TextEditingController amount = TextEditingController();
    BillingCycle cycle = BillingCycle.monthly;
    final String currency =
        ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return showAppBottomSheet<void>(
      context: context,
      title: 'New subscription',
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: service,
                  hint: 'e.g. Netflix',
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.md),
                CurrencyInput(
                  currencyCode: currency,
                  controller: amount,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<BillingCycle>(
                  segments: const <ButtonSegment<BillingCycle>>[
                    ButtonSegment<BillingCycle>(
                      value: BillingCycle.weekly,
                      label: Text('Weekly'),
                    ),
                    ButtonSegment<BillingCycle>(
                      value: BillingCycle.monthly,
                      label: Text('Monthly'),
                    ),
                    ButtonSegment<BillingCycle>(
                      value: BillingCycle.yearly,
                      label: Text('Yearly'),
                    ),
                  ],
                  selected: <BillingCycle>{cycle},
                  onSelectionChanged: (Set<BillingCycle> selection) =>
                      setState(() => cycle = selection.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save subscription',
                  expand: true,
                  onPressed: () async {
                    final String? userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
                    final double? value = double.tryParse(amount.text);
                    if (userId == null ||
                        service.text.trim().isEmpty ||
                        value == null ||
                        value <= 0) {
                      return;
                    }
                    final DateTime now = DateTime.now().toUtc();
                    await ref.read(subscriptionRepositoryProvider).create(
                          Subscription(
                            id: const Uuid().v4(),
                            userId: userId,
                            service: service.text.trim(),
                            amount:
                                Money(amount: value, currency: currency),
                            billingCycle: cycle,
                            isActive: true,
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
