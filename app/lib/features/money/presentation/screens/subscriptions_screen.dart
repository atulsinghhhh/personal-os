import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/models/money.dart';
import '../../subscriptions/domain/entities/subscription.dart';
import '../widgets/money_ui.dart';

final StreamProvider<List<Subscription>> subscriptionsProvider =
    StreamProvider<List<Subscription>>((Ref ref) {
  return ref.watch(subscriptionRepositoryProvider).watchAll();
});

/// Subscriptions: monthly-cost headline (active only), then hairline rows
/// with pause/resume and cycle detail.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Subscription>> subscriptions = ref.watch(subscriptionsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Subscriptions', style: lumaSerif(size: 32, height: 1.05)),
              GestureDetector(
                onTap: () => _showCreateSheet(context, ref),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          subscriptions.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load subscriptions.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<Subscription> all) {
              if (all.isEmpty) {
                return GestureDetector(
                  onTap: () => _showCreateSheet(context, ref),
                  child: Text('No subscriptions tracked yet.',
                      style: lumaSans(
                          size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                );
              }

              final Map<String, double> monthlyByCurrency = <String, double>{};
              for (final Subscription s in all.where((Subscription s) => s.isActive)) {
                monthlyByCurrency.update(
                  s.amount.currency,
                  (double v) => v + subscriptionMonthlyCost(s),
                  ifAbsent: () => subscriptionMonthlyCost(s),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const LumaEyebrow('Monthly cost (active)'),
                  const SizedBox(height: 10),
                  if (monthlyByCurrency.isEmpty)
                    Text('No active subscriptions.',
                        style: lumaSans(size: 14, color: LumaColors.ink3))
                  else
                    for (final MapEntry<String, double> entry in monthlyByCurrency.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(formatMoney(Money(amount: entry.value, currency: entry.key)),
                                style: lumaSerif(size: 30, height: 1.05)),
                            Text(
                              '≈ ${formatMoney(Money(amount: entry.value * 12, currency: entry.key))}/year '
                              '(weekly ×52⁄12, yearly ÷12)',
                              style: lumaSans(size: 12.5, color: LumaColors.ink3),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 20),
                  for (final Subscription s in all) _SubscriptionRow(subscription: s),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _cycleLabel(BillingCycle cycle) => switch (cycle) {
        BillingCycle.weekly => 'weekly',
        BillingCycle.monthly => 'monthly',
        BillingCycle.yearly => 'yearly',
      };

  static Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController service = TextEditingController();
    final TextEditingController amount = TextEditingController();
    BillingCycle cycle = BillingCycle.monthly;
    final String currency = ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LumaColors.ground,
      barrierColor: const Color(0x521B1B19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    const LumaEyebrow('New subscription'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: service,
                      autofocus: true,
                      style: lumaSerif(size: 26, height: 1.15),
                      cursorColor: LumaColors.ink,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'e.g. Netflix',
                        hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CurrencyInput(currencyCode: currency, controller: amount, autofocus: false),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        for (final BillingCycle value in BillingCycle.values) ...<Widget>[
                          if (value != BillingCycle.values.first) const SizedBox(width: 8),
                          LumaChip(
                            label: _cycleLabel(value),
                            selected: cycle == value,
                            onTap: () => setState(() => cycle = value),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    LumaPrimaryButton(
                      label: 'Save subscription',
                      height: 52,
                      onTap: () async {
                        final String? userId =
                            ref.read(supabaseClientProvider).auth.currentUser?.id;
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
                                amount: Money(amount: value, currency: currency),
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SubscriptionRow extends ConsumerWidget {
  const _SubscriptionRow({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> meta = <String>[
      '${formatMoney(subscription.amount)} · ${SubscriptionsScreen._cycleLabel(subscription.billingCycle)}',
      if (subscription.renewalDate != null)
        'renews ${DateFormat.MMMd().format(subscription.renewalDate!)}',
      if (!subscription.isActive) 'inactive',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(subscription.service, style: lumaSans(size: 15, weight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(meta.join(' · '), style: lumaSans(size: 12.5, color: LumaColors.ink3)),
              ],
            ),
          ),
          Semantics(
            label: subscription.isActive ? 'Mark inactive' : 'Mark active',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(subscriptionRepositoryProvider).update(
                    subscription.copyWith(
                      isActive: !subscription.isActive,
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: LumaIcon(
                    subscription.isActive ? LumaIcons.pause : LumaIcons.check,
                    size: 18,
                    color: LumaColors.ink2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
