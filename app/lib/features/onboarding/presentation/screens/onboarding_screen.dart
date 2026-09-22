import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/currencies.dart';
import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/radius.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../shared/models/profile.dart';
import '../../../future/domain/entities/future_entities.dart';

/// Progressive onboarding: name -> life areas -> vision -> currency. Every
/// step is skippable; writes go through the normal repository/outbox path
/// so onboarding works fully offline.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _vision = TextEditingController();

  int _page = 0;
  final Set<String> _selectedAreas = <String>{};
  String? _currency;
  bool _saving = false;

  static const List<String> _defaultAreas = <String>[
    'Career',
    'Business',
    'Money',
    'Health',
    'Learning',
    'Relationships',
    'Personal',
    'Experiences',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _name.dispose();
    _vision.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 3) {
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
    final List<Color> accents =
        AppSemanticColors.light.lifeAreaAccents;

    try {
      int order = 0;
      String? firstAreaId;
      for (final String areaName in _selectedAreas) {
        final String id = const Uuid().v4();
        firstAreaId ??= id;
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

      if (_vision.text.trim().isNotEmpty) {
        await ref.read(visionRepositoryProvider).create(
              Vision(
                id: const Uuid().v4(),
                userId: userId,
                lifeAreaId: firstAreaId,
                title: _vision.text.trim(),
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
              displayName: _name.text.trim().isEmpty
                  ? existing?.displayName
                  : _name.text.trim(),
              defaultCurrency: _currency ?? existing?.defaultCurrency,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 4; i++) ...<Widget>[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius:
                              AppRadius.asBorderRadius(AppRadius.full),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) => setState(() => _page = page),
                children: <Widget>[
                  _NameStep(controller: _name),
                  _LifeAreasStep(
                    all: _defaultAreas,
                    selected: _selectedAreas,
                    onToggle: (String area) => setState(() {
                      if (!_selectedAreas.remove(area)) {
                        _selectedAreas.add(area);
                      }
                    }),
                  ),
                  _VisionStep(controller: _vision),
                  _CurrencyStep(
                    selected: _currency,
                    onSelect: (String code) =>
                        setState(() => _currency = code),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  AppButton(
                    label: 'Skip',
                    variant: AppButtonVariant.text,
                    onPressed: _saving ? null : _next,
                  ),
                  const Spacer(),
                  AppButton(
                    label: _page == 3
                        ? (_saving ? 'Finishing…' : 'Finish')
                        : 'Continue',
                    onPressed: _saving ? null : _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "What's your name?",
      subtitle: 'This is how the app greets you.',
      child: AppTextField(
        controller: controller,
        hint: 'Your name',
        autofocus: false,
        textInputAction: TextInputAction.done,
      ),
    );
  }
}

class _LifeAreasStep extends StatelessWidget {
  const _LifeAreasStep({
    required this.all,
    required this.selected,
    required this.onToggle,
  });

  final List<String> all;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Pick your life areas',
      subtitle: 'The parts of life you want to design on purpose.',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final String area in all)
            FilterChip(
              label: Text(area),
              selected: selected.contains(area),
              onSelected: (_) => onToggle(area),
            ),
        ],
      ),
    );
  }
}

class _VisionStep extends StatelessWidget {
  const _VisionStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Describe your future',
      subtitle:
          'In a sentence or two: what does the life you want look like?',
      child: AppTextField(
        controller: controller,
        hint: 'I want to…',
        maxLines: 4,
      ),
    );
  }
}

class _CurrencyStep extends StatelessWidget {
  const _CurrencyStep({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Your currency',
      subtitle: 'Used as the default for accounts and budgets.',
      child: Expanded(
        child: ListView.builder(
          itemCount: supportedCurrencies.length,
          itemBuilder: (BuildContext context, int index) {
            final CurrencyInfo currency = supportedCurrencies[index];
            final bool isSelected = currency.code == selected;
            return ListTile(
              title: Text(currency.code),
              subtitle: Text(currency.name),
              trailing: isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => onSelect(currency.code),
            );
          },
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: AppTypography.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (child is Expanded) child else Flexible(child: child),
        ],
      ),
    );
  }
}
