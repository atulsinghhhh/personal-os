import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/currencies.dart';
import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/luma_text_field.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/models/profile.dart';
import '../../../future/domain/entities/future_entities.dart';

/// Designs 05–07: life areas → first goal → rhythm & privacy. Every step is
/// skippable; writes go through the normal repository/outbox path so
/// onboarding works fully offline.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _goal =
      TextEditingController(text: 'Financial independence');
  final TextEditingController _target = TextEditingController();

  int _page = 0;
  bool _saving = false;

  static const List<(String, String)> _areas = <(String, String)>[
    ('Business', 'Work, side projects'),
    ('Health', 'Training, sleep, energy'),
    ('Learning', 'Skills, languages'),
    ('Relationships', 'Family, friends'),
    ('Finance', 'Saving, investing'),
    ('Personal', 'Travel, creativity'),
  ];

  final Set<String> _selectedAreas = <String>{'Business', 'Health', 'Finance'};
  String _goalArea = 'Finance';
  String _goalWhen = '2027';

  bool _morningPlan = true;
  bool _eveningReview = true;
  bool _trackMoney = true;
  bool _faceId = false;
  String _currency = 'INR';

  @override
  void dispose() {
    _pageController.dispose();
    _goal.dispose();
    _target.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 2) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);

    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final List<Color> accents = AppSemanticColors.light.lifeAreaAccents;

    try {
      int order = 0;
      String? goalAreaId;
      for (final String areaName in _selectedAreas) {
        final String id = const Uuid().v4();
        if (areaName == _goalArea) goalAreaId = id;
        final Color accent = accents[order % accents.length];
        await ref.read(lifeAreaRepositoryProvider).create(
              LifeArea(
                id: id,
                userId: userId,
                name: areaName,
                color:
                    '#${accent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                icon: null,
                sortOrder: order++,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      if (_goal.text.trim().isNotEmpty) {
        await ref.read(visionRepositoryProvider).create(
              Vision(
                id: const Uuid().v4(),
                userId: userId,
                lifeAreaId: goalAreaId,
                title: _goal.text.trim(),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final Profile? existing =
          await ref.read(profileRepositoryProvider).get(userId);
      await ref.read(profileRepositoryProvider).save(
            Profile(
              id: userId,
              displayName: existing?.displayName,
              defaultCurrency: _currency,
              onboardingCompletedAt: now,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
            ),
          );

      if (mounted) context.go(RoutePaths.today);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCurrency() async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: LumaColors.ground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: <Widget>[
            for (final CurrencyInfo c in supportedCurrencies)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(c.code),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: LumaColors.hairline)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text('${c.symbol} ${c.name}',
                          style:
                              lumaSans(size: 15, weight: FontWeight.w500)),
                      const Spacer(),
                      if (c.code == _currency)
                        const LumaIcon(LumaIcons.check,
                            size: 16, color: LumaColors.accent),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (code != null) setState(() => _currency = code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int page) => setState(() => _page = page),
        children: <Widget>[
          _buildAreasStep(),
          _buildGoalStep(),
          _buildRhythmStep(),
        ],
      ),
    );
  }

  // Design 05 — "Which parts of life do you want to shape?"
  Widget _buildAreasStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StepProgress(step: 1),
          const SizedBox(height: 26),
          Text('Which parts of life do you want to shape?',
              style: lumaSerif(size: 36, height: 1.05)),
          const SizedBox(height: 10),
          Text(
            'These become your life areas. Goals, projects and money all roll up to them.',
            style: lumaSans(size: 15, color: LumaColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 26),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 166 / 92,
              children: <Widget>[
                for (final (String name, String sub) in _areas)
                  _AreaCard(
                    name: name,
                    sub: sub,
                    selected: _selectedAreas.contains(name),
                    onTap: () => setState(() =>
                        _selectedAreas.contains(name)
                            ? _selectedAreas.remove(name)
                            : _selectedAreas.add(name)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_selectedAreas.length} selected · you can change these anytime',
            textAlign: TextAlign.center,
            style: lumaSans(size: 13, color: LumaColors.ink3),
          ),
          const SizedBox(height: 12),
          LumaPrimaryButton(label: 'Continue', onTap: _next),
          const SizedBox(height: 12),
          LumaTextButton(
            label: 'Skip for now',
            height: 44,
            color: LumaColors.ink2,
            fontWeight: FontWeight.w400,
            onTap: _next,
          ),
        ],
      ),
    );
  }

  // Design 06 — "Where do you want to be?"
  Widget _buildGoalStep() {
    final List<String> areaOptions = <String>[
      _goalArea,
      ..._selectedAreas.where((String a) => a != _goalArea),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StepProgress(step: 2),
          const SizedBox(height: 24),
          Text('Where do you want to be?',
              style: lumaSerif(size: 38, height: 1.05)),
          const SizedBox(height: 10),
          Text(
            'Start with one goal. Everything you do each day can point back to it.',
            style: lumaSans(size: 15, color: LumaColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text('Your first goal',
              style: lumaSans(
                  size: 13, weight: FontWeight.w500, color: LumaColors.ink2)),
          const SizedBox(height: 8),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: LumaColors.hairline)),
            ),
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _goal,
              style: lumaSerif(size: 30),
              cursorColor: LumaColors.ink,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _ChipGroup(
            label: 'Life area',
            options: areaOptions,
            selected: _goalArea,
            onSelect: (String v) => setState(() => _goalArea = v),
          ),
          const SizedBox(height: 24),
          _ChipGroup(
            label: 'By when',
            options: const <String>['2026', '2027', '2028', 'Later'],
            selected: _goalWhen,
            onSelect: (String v) => setState(() => _goalWhen = v),
          ),
          const SizedBox(height: 24),
          LumaTextField(
              label: 'Target amount (optional)',
              controller: _target,
              hint: '₹10,00,000'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LumaColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const LumaIcon(LumaIcons.sparkle,
                        size: 17, color: LumaColors.accent),
                    const SizedBox(width: 8),
                    Text('SUGGESTED MILESTONES',
                        style: lumaEyebrow(color: LumaColors.accent)),
                  ],
                ),
                const SizedBox(height: 12),
                const _Milestone('Emergency fund · ₹2L'),
                const SizedBox(height: 12),
                const _Milestone('₹5L saved and invested'),
                const SizedBox(height: 12),
                const _Milestone('₹10L — independence'),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    SizedBox(
                      height: 36,
                      child: Center(
                        child: Text('Use these',
                            style: lumaSans(
                                size: 14,
                                weight: FontWeight.w600,
                                color: LumaColors.accent)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 36,
                      child: Center(
                        child: Text('Edit',
                            style: lumaSans(size: 14, color: LumaColors.ink2)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LumaPrimaryButton(label: 'Continue', onTap: _next),
          const SizedBox(height: 14),
          LumaTextButton(
            label: 'Skip for now',
            height: 40,
            color: LumaColors.ink2,
            fontWeight: FontWeight.w400,
            onTap: _next,
          ),
        ],
      ),
    );
  }

  // Design 07 — "Set your rhythm"
  Widget _buildRhythmStep() {
    final CurrencyInfo currency = supportedCurrencies.firstWhere(
      (CurrencyInfo c) => c.code == _currency,
      orElse: () => supportedCurrencies.first,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StepProgress(step: 3),
          const SizedBox(height: 24),
          Text('Set your rhythm', style: lumaSerif(size: 38, height: 1.05)),
          const SizedBox(height: 10),
          Text(
            'Two quiet check-ins a day. No streaks, no pressure.',
            style: lumaSans(size: 15, color: LumaColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 24),
          _SettingRow(
            title: 'Morning plan',
            sub: '08:30 · a suggested plan for the day',
            on: _morningPlan,
            onChanged: (bool v) => setState(() => _morningPlan = v),
          ),
          _SettingRow(
            title: 'Evening review',
            sub: '21:30 · five minutes to reflect',
            on: _eveningReview,
            onChanged: (bool v) => setState(() => _eveningReview = v),
          ),
          _SettingRow(
            title: 'Track money',
            sub: 'Add expenses by hand or import a statement',
            on: _trackMoney,
            onChanged: (bool v) => setState(() => _trackMoney = v),
          ),
          _SettingRow(
            title: 'Lock with Face ID',
            sub: 'Ask every time the app opens',
            on: _faceId,
            onChanged: (bool v) => setState(() => _faceId = v),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickCurrency,
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: LumaColors.hairline),
                  bottom: BorderSide(color: LumaColors.hairline),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Text('Currency',
                      style: lumaSans(size: 15, weight: FontWeight.w500)),
                  const Spacer(),
                  Text('${currency.symbol} ${currency.name}',
                      style: lumaSans(size: 15, color: LumaColors.ink2)),
                  const SizedBox(width: 4),
                  const LumaIcon(LumaIcons.chevronRight,
                      size: 16, color: LumaColors.ink3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LumaColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: LumaColors.hairline, offset: Offset(0, 1)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const LumaIcon(LumaIcons.lock, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: lumaSans(
                          size: 13.5, height: 1.5, color: LumaColors.ink2),
                      children: <InlineSpan>[
                        TextSpan(
                            text: 'Your data stays yours. ',
                            style: lumaSans(
                                size: 13.5,
                                height: 1.5,
                                weight: FontWeight.w600,
                                color: LumaColors.ink)),
                        const TextSpan(
                            text:
                                'Encrypted, exportable anytime, never sold, no ads, no social feed.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LumaPrimaryButton(
            label: _saving ? 'Opening…' : 'Open Today',
            onTap: _saving ? null : _finish,
          ),
        ],
      ),
    );
  }
}

/// Shared 3-segment onboarding progress header.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 1; i <= 3; i++) ...<Widget>[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= step ? LumaColors.ink : LumaColors.sunken,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text('Step $step of 3',
            style: lumaSans(size: 12, color: LumaColors.ink3)),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.name,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? LumaColors.ink : LumaColors.surface,
          border: Border.all(
              color: selected ? LumaColors.ink : LumaColors.hairline),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: lumaSans(
                          size: 16,
                          weight: FontWeight.w600,
                          color:
                              selected ? LumaColors.surface : LumaColors.ink)),
                ),
                if (selected)
                  Text('✓',
                      style: lumaSans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: LumaColors.surface)),
              ],
            ),
            Text(sub,
                style: lumaSans(
                    size: 12.5,
                    color: selected
                        ? LumaColors.surface.withValues(alpha: 0.72)
                        : LumaColors.ink3)),
          ],
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: lumaSans(
                size: 13, weight: FontWeight.w500, color: LumaColors.ink2)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String o in options)
              LumaChip(
                label: o,
                selected: o == selected,
                onTap: () => onSelect(o),
              ),
          ],
        ),
      ],
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: LumaColors.accent, width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: lumaSans(size: 14)),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.sub,
    required this.on,
    required this.onChanged,
  });

  final String title;
  final String sub;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: lumaSans(size: 15, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(sub, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          LumaToggle(on: on, onChanged: onChanged, label: title),
        ],
      ),
    );
  }
}
