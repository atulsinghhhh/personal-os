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
import '../../bills/domain/entities/bill.dart';
import '../widgets/money_ui.dart';

final StreamProvider<List<Bill>> billsProvider = StreamProvider<List<Bill>>((Ref ref) {
  return ref.watch(billRepositoryProvider).watchAll();
});

/// Bills: hairline rows with due-date state and a mark-paid action.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Bill>> bills = ref.watch(billsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Bills', style: lumaSerif(size: 40, height: 1.05)),
              GestureDetector(
                onTap: () => _showCreateSheet(context, ref),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          bills.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load bills.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<Bill> all) {
              if (all.isEmpty) {
                return GestureDetector(
                  onTap: () => _showCreateSheet(context, ref),
                  child: Text('No bills yet — track rent, utilities, and more.',
                      style: lumaSans(
                          size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Bill bill in all) _BillRow(bill: bill),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController name = TextEditingController();
    final TextEditingController amount = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    BillRecurrence recurrence = BillRecurrence.monthly;
    final String currency = ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    const Map<BillRecurrence, String> labels = <BillRecurrence, String>{
      BillRecurrence.none: 'Once',
      BillRecurrence.weekly: 'Weekly',
      BillRecurrence.monthly: 'Monthly',
      BillRecurrence.yearly: 'Yearly',
    };

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
                    const LumaEyebrow('New bill'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: name,
                      autofocus: true,
                      style: lumaSerif(size: 26, height: 1.15),
                      cursorColor: LumaColors.ink,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'e.g. Rent',
                        hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CurrencyInput(currencyCode: currency, controller: amount, autofocus: false),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime(dueDate.year - 1),
                          lastDate: DateTime(dueDate.year + 5),
                        );
                        if (picked != null) setState(() => dueDate = picked);
                      },
                      child: Text('Due ${DateFormat.yMMMd().format(dueDate)}',
                          style: lumaSans(size: 14, color: LumaColors.ink2)),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: <Widget>[
                          for (final BillRecurrence value in BillRecurrence.values) ...<Widget>[
                            if (value != BillRecurrence.values.first) const SizedBox(width: 8),
                            LumaChip(
                              label: labels[value]!,
                              selected: recurrence == value,
                              onTap: () => setState(() => recurrence = value),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    LumaPrimaryButton(
                      label: 'Save bill',
                      height: 52,
                      onTap: () async {
                        final String? userId =
                            ref.read(supabaseClientProvider).auth.currentUser?.id;
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
                                amount: Money(amount: value, currency: currency),
                                dueDate: DateTime.utc(dueDate.year, dueDate.month, dueDate.day),
                                recurrence: recurrence,
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

class _BillRow extends ConsumerWidget {
  const _BillRow({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = DateTime.now();
    final DateTime todayUtc = DateTime.utc(today.year, today.month, today.day);
    final bool overdue = bill.dueDate.isBefore(todayUtc);
    final int daysAway = bill.dueDate.difference(todayUtc).inDays;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text(bill.name, style: lumaSans(size: 16, weight: FontWeight.w500))),
              Text(formatMoney(bill.amount), style: lumaSans(size: 15, weight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            overdue
                ? 'Overdue — was due ${DateFormat.MMMd().format(bill.dueDate)}'
                : daysAway == 0
                    ? 'Due today'
                    : 'Due ${DateFormat.MMMd().format(bill.dueDate)} (${daysAway}d)',
            style: lumaSans(size: 12.5, color: overdue ? LumaColors.warning : LumaColors.ink3),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () async {
                  final String? userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                  if (userId == null) return;
                  await ref.read(billRepositoryProvider).markPaid(bill, userId: userId);
                },
                child: Text('Mark paid',
                    style: lumaSans(
                        size: 13, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => ref.read(billRepositoryProvider).delete(bill.id),
                child: const LumaIcon(LumaIcons.close, size: 16, color: LumaColors.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
