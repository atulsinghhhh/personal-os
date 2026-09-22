import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
import '../../../../shared/models/money.dart';
import '../../assets/domain/entities/asset.dart';
import '../../net_worth/domain/entities/net_worth.dart';
import '../widgets/money_ui.dart';

final FutureProvider<Map<String, NetWorthEntry>> currentNetWorthProvider =
    FutureProvider<Map<String, NetWorthEntry>>((Ref ref) async {
  final String? userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
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

/// Design "NetWorth": one big serif figure per currency, a hairline history
/// sparkline, and a manual-assets list — values are entered, never estimated.
class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, NetWorthEntry>> current = ref.watch(currentNetWorthProvider);
    final AsyncValue<List<NetWorthSnapshot>> history = ref.watch(netWorthHistoryProvider);
    final AsyncValue<List<Asset>> assets = ref.watch(assetsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Net worth', style: lumaSerif(size: 40, height: 1.05)),
              Semantics(
                label: 'Save snapshot for today',
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _saveSnapshot(ref),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: LumaIcon(LumaIcons.check, size: 20, color: LumaColors.ink2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          current.when(
            loading: () => const SizedBox(height: 120),
            error: (Object error, _) => Text('Could not compute net worth.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (Map<String, NetWorthEntry> byCurrency) {
              if (byCurrency.isEmpty) {
                return Text('Add accounts, assets, or debts to see your net worth.',
                    style: lumaSans(size: 14, color: LumaColors.ink3));
              }
              final List<MapEntry<String, NetWorthEntry>> entries = byCurrency.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < entries.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 22),
                    _NetWorthFigure(currency: entries[i].key, entry: entries[i].value),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const LumaEyebrow('History'),
          const SizedBox(height: 14),
          history.when(
            loading: () => const SizedBox(height: 120),
            error: (Object error, _) => Text('Could not load history.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<NetWorthSnapshot> snapshots) {
              if (snapshots.length < 2) {
                return Text('Save snapshots over time to see your trajectory here.',
                    style: lumaSans(size: 14, color: LumaColors.ink3));
              }
              final Map<String, int> currencyCounts = <String, int>{};
              for (final NetWorthSnapshot snapshot in snapshots) {
                for (final String currency in snapshot.breakdown.keys) {
                  currencyCounts.update(currency, (int v) => v + 1, ifAbsent: () => 1);
                }
              }
              final String chartCurrency =
                  currencyCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
              final List<double> values = <double>[
                for (final NetWorthSnapshot snapshot in snapshots)
                  if (snapshot.breakdown[chartCurrency] != null)
                    snapshot.breakdown[chartCurrency]!.assets -
                        snapshot.breakdown[chartCurrency]!.liabilities,
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('$chartCurrency · ${values.length} snapshots',
                      style: lumaSans(size: 12.5, color: LumaColors.ink3)),
                  const SizedBox(height: 10),
                  _Sparkline(values: values),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat.yMMMd().format(snapshots.first.date)} — '
                    '${DateFormat.yMMMd().format(snapshots.last.date)}',
                    style: lumaSans(size: 12.5, color: LumaColors.ink3),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          LumaSectionHeader(
            'Manual assets',
            action: 'Add',
            onAction: () => _showAddAssetSheet(context, ref),
          ),
          const SizedBox(height: 14),
          assets.when(
            loading: () => const SizedBox(height: 72),
            error: (Object error, _) => Text('Could not load assets.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<Asset> all) {
              if (all.isEmpty) {
                return Text(
                  'Track property, vehicles, or valuables here — values are '
                  'yours to enter, never estimated.',
                  style: lumaSans(size: 14, color: LumaColors.ink3),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Asset asset in all)
                    LumaMetaRow(
                      label: asset.name,
                      value: formatMoney(Money(amount: asset.value, currency: asset.currency)),
                      onTap: () => _showAddAssetSheet(context, ref, existing: asset),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveSnapshot(WidgetRef ref) async {
    final String? userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final Map<String, NetWorthEntry> breakdown =
        await ref.read(netWorthRepositoryProvider).computeCurrent(userId);
    if (breakdown.isEmpty) return;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime.utc(now.year, now.month, now.day);
    final String id =
        const Uuid().v5(Namespace.url.value, 'net-worth/$userId/${today.toIso8601String()}');
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
    final TextEditingController name = TextEditingController(text: existing?.name);
    final TextEditingController value =
        TextEditingController(text: existing?.value.toStringAsFixed(0));
    final String currency = existing?.currency ??
        ref.read(currentProfileProvider).value?.defaultCurrency ??
        'USD';

    return showModalBottomSheet<void>(
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
                LumaEyebrow(existing == null ? 'New asset' : 'Edit asset'),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  autofocus: existing == null,
                  style: lumaSerif(size: 26, height: 1.15),
                  cursorColor: LumaColors.ink,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'e.g. Car',
                    hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: lumaSans(size: 17, weight: FontWeight.w500),
                  cursorColor: LumaColors.ink,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Value ($currency)',
                    hintStyle: lumaSans(size: 17, color: LumaColors.ink3),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    if (existing != null)
                      Expanded(
                        child: LumaSecondaryButton(
                          label: 'Delete',
                          height: 52,
                          onTap: () async {
                            await ref.read(assetRepositoryProvider).delete(existing.id);
                            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          },
                        ),
                      ),
                    if (existing != null) const SizedBox(width: 10),
                    Expanded(
                      child: LumaPrimaryButton(
                        label: 'Save',
                        height: 52,
                        onTap: () async {
                          final String? userId =
                              ref.read(supabaseClientProvider).auth.currentUser?.id;
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
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NetWorthFigure extends StatelessWidget {
  const _NetWorthFigure({required this.currency, required this.entry});

  final String currency;
  final NetWorthEntry entry;

  @override
  Widget build(BuildContext context) {
    final double net = entry.assets - entry.liabilities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LumaEyebrow(currency),
        const SizedBox(height: 8),
        Text(
          formatMoney(Money(amount: net, currency: currency)),
          style: lumaSerif(
              size: LumaType.metric, height: 1, color: net < 0 ? LumaColors.negative : LumaColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          'Assets ${formatMoney(Money(amount: entry.assets, currency: currency))} '
          '− liabilities ${formatMoney(Money(amount: entry.liabilities, currency: currency))}',
          style: lumaSans(size: 13, color: LumaColors.ink3),
        ),
      ],
    );
  }
}

/// Hairline sparkline over a value series — no axes, just the trend.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values: values)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double min = values.reduce((a, b) => a < b ? a : b);
    final double max = values.reduce((a, b) => a > b ? a : b);
    final double range = (max - min).abs() < 1e-9 ? 1 : max - min;

    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = LumaColors.accent;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.values != values;
}
