import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_chart.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../assets/domain/entities/asset.dart';
import '../../net_worth/domain/entities/net_worth.dart';
import '../widgets/money_ui.dart';

final FutureProvider<Map<String, NetWorthEntry>> currentNetWorthProvider =
    FutureProvider<Map<String, NetWorthEntry>>((Ref ref) async {
  final String? userId =
      ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return <String, NetWorthEntry>{};
  return ref.watch(netWorthRepositoryProvider).computeCurrent(userId);
});

final StreamProvider<List<NetWorthSnapshot>> netWorthHistoryProvider =
    StreamProvider<List<NetWorthSnapshot>>((Ref ref) {
  return ref.watch(netWorthRepositoryProvider).watchSnapshots();
});

final StreamProvider<List<Asset>> assetsProvider =
    StreamProvider<List<Asset>>((Ref ref) {
  return ref.watch(assetRepositoryProvider).watchAll();
});

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, NetWorthEntry>> current =
        ref.watch(currentNetWorthProvider);
    final AsyncValue<List<NetWorthSnapshot>> history =
        ref.watch(netWorthHistoryProvider);
    final AsyncValue<List<Asset>> assets = ref.watch(assetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Net worth'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Save snapshot for today',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => _saveSnapshot(ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          current.when(
            loading: () => const LoadingShimmer(height: 120),
            error: (Object error, _) =>
                ErrorStateView(message: 'Could not compute net worth.'),
            data: (Map<String, NetWorthEntry> byCurrency) {
              if (byCurrency.isEmpty) {
                return const AppCard(
                  child: Text(
                    'Add accounts, assets, or debts to see your net worth.',
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final MapEntry<String, NetWorthEntry> entry
                      in byCurrency.entries) ...<Widget>[
                    _NetWorthCard(
                      currency: entry.key,
                      entry: entry.value,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'HISTORY',
            style: AppTypography.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          history.when(
            loading: () => const LoadingShimmer(height: 120),
            error: (Object error, _) =>
                ErrorStateView(message: 'Could not load history.'),
            data: (List<NetWorthSnapshot> snapshots) {
              if (snapshots.length < 2) {
                return const AppCard(
                  child: Text(
                    'Save snapshots over time to see your trajectory here.',
                  ),
                );
              }
              // One line per snapshot in the user's dominant currency:
              // use the currency with the most snapshots carrying it.
              final Map<String, int> currencyCounts = <String, int>{};
              for (final NetWorthSnapshot snapshot in snapshots) {
                for (final String currency in snapshot.breakdown.keys) {
                  currencyCounts.update(
                    currency,
                    (int v) => v + 1,
                    ifAbsent: () => 1,
                  );
                }
              }
              final String chartCurrency = currencyCounts.entries
                  .reduce(
                    (MapEntry<String, int> a, MapEntry<String, int> b) =>
                        a.value >= b.value ? a : b,
                  )
                  .key;
              final List<double> values = <double>[
                for (final NetWorthSnapshot snapshot in snapshots)
                  if (snapshot.breakdown[chartCurrency] != null)
                    snapshot.breakdown[chartCurrency]!.assets -
                        snapshot.breakdown[chartCurrency]!.liabilities,
              ];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$chartCurrency net worth over '
                      '${values.length} snapshots',
                      style: AppTypography.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppLineChart(values: values),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${DateFormat.yMMMd().format(snapshots.first.date)} — '
                      '${DateFormat.yMMMd().format(snapshots.last.date)}',
                      style: AppTypography.labelSmall.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'MANUAL ASSETS',
                style: AppTypography.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () => _showAddAssetSheet(context, ref),
                child: const Text('Add'),
              ),
            ],
          ),
          assets.when(
            loading: () => const LoadingShimmer(height: 72),
            error: (Object error, _) =>
                ErrorStateView(message: 'Could not load assets.'),
            data: (List<Asset> all) {
              if (all.isEmpty) {
                return const AppCard(
                  child: Text(
                    'Track property, vehicles, or valuables here — values '
                    'are yours to enter, never estimated.',
                  ),
                );
              }
              return AppCard(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    for (final Asset asset in all)
                      AppListRow(
                        title: asset.name,
                        subtitle: asset.note,
                        trailing: Text(
                          formatMoney(
                            Money(
                              amount: asset.value,
                              currency: asset.currency,
                            ),
                          ),
                          style: AppTypography.currencyMedium,
                        ),
                        onTap: () =>
                            _showAddAssetSheet(context, ref, existing: asset),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveSnapshot(WidgetRef ref) async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final Map<String, NetWorthEntry> breakdown =
        await ref.read(netWorthRepositoryProvider).computeCurrent(userId);
    if (breakdown.isEmpty) return;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime.utc(now.year, now.month, now.day);
    // Stable id per user+date so re-saving the same day replaces it.
    final String id = const Uuid().v5(
      Namespace.url.value,
      'net-worth/$userId/${today.toIso8601String()}',
    );
    await ref.read(netWorthRepositoryProvider).upsertSnapshot(
          NetWorthSnapshot(
            id: id,
            userId: userId,
            date: today,
            breakdown: breakdown,
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
          ),
        );
  }

  Future<void> _showAddAssetSheet(
    BuildContext context,
    WidgetRef ref, {
    Asset? existing,
  }) {
    final TextEditingController name =
        TextEditingController(text: existing?.name);
    final TextEditingController value = TextEditingController(
      text: existing?.value.toStringAsFixed(0),
    );
    final String currency = existing?.currency ??
        ref.read(currentProfileProvider).value?.defaultCurrency ??
        'USD';

    return showAppBottomSheet<void>(
      context: context,
      title: existing == null ? 'New asset' : 'Edit asset',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: name,
              hint: 'e.g. Car',
              autofocus: existing == null,
            ),
            const SizedBox(height: AppSpacing.md),
            CurrencyInput(
              currencyCode: currency,
              controller: value,
              autofocus: false,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                if (existing != null)
                  AppButton(
                    label: 'Delete',
                    variant: AppButtonVariant.danger,
                    onPressed: () async {
                      await ref
                          .read(assetRepositoryProvider)
                          .delete(existing.id);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                const Spacer(),
                AppButton(
                  label: 'Save',
                  onPressed: () async {
                    final String? userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
                    final double? amount = double.tryParse(value.text);
                    if (userId == null ||
                        name.text.trim().isEmpty ||
                        amount == null ||
                        amount < 0) {
                      return;
                    }
                    final DateTime now = DateTime.now().toUtc();
                    final Asset asset = Asset(
                      id: existing?.id ?? const Uuid().v4(),
                      userId: userId,
                      name: name.text.trim(),
                      value: amount,
                      currency: currency,
                      note: existing?.note,
                      createdAt: existing?.createdAt ?? now,
                      updatedAt: now,
                    );
                    if (existing == null) {
                      await ref.read(assetRepositoryProvider).create(asset);
                    } else {
                      await ref.read(assetRepositoryProvider).update(asset);
                    }
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({required this.currency, required this.entry});

  final String currency;
  final NetWorthEntry entry;

  @override
  Widget build(BuildContext context) {
    final double net = entry.assets - entry.liabilities;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'NET WORTH ($currency)',
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatMoney(Money(amount: net, currency: currency)),
            style: AppTypography.currencyLarge.copyWith(
              color: net < 0 ? context.semanticColors.expense : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Assets ${formatMoney(Money(amount: entry.assets, currency: currency))} '
            '− liabilities ${formatMoney(Money(amount: entry.liabilities, currency: currency))}. '
            'Computed from account balances, manual assets, and debts.',
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
