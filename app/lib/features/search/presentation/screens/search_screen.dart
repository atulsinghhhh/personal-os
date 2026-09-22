import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../notes/domain/entities/note.dart';
import '../../../projects/domain/entities/project_entities.dart';

/// Global search over the LOCAL database (works offline). Simple
/// case-insensitive substring matching computed client-side — server-side
/// full-text search is a later optimization if data grows.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  String _term = '';
  bool _searching = false;

  List<Task> _tasks = <Task>[];
  List<Project> _projects = <Project>[];
  List<Goal> _goals = <Goal>[];
  List<Note> _notes = <Note>[];
  List<MoneyTransaction> _transactions = <MoneyTransaction>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final String term = value.trim().toLowerCase();
      if (term == _term) return;
      setState(() {
        _term = term;
        _searching = term.isNotEmpty;
      });
      if (term.isEmpty) return;

      bool matches(String? text) =>
          text != null && text.toLowerCase().contains(term);

      final List<Task> tasks =
          await ref.read(taskRepositoryProvider).watchAll().first;
      final List<Project> projects =
          await ref.read(projectRepositoryProvider).watchAll().first;
      final List<Goal> goals =
          await ref.read(goalRepositoryProvider).watchAll().first;
      final List<Note> notes =
          await ref.read(noteRepositoryProvider).watchAll().first;
      final List<MoneyTransaction> transactions =
          await ref.read(transactionRepositoryProvider).watchRecent(500).first;

      if (!mounted || term != _term) return;
      setState(() {
        _searching = false;
        _tasks = tasks
            .where((Task t) => matches(t.title) || matches(t.notes))
            .take(20)
            .toList(growable: false);
        _projects = projects
            .where(
              (Project p) => matches(p.title) || matches(p.description),
            )
            .take(20)
            .toList(growable: false);
        _goals = goals
            .where((Goal g) => matches(g.title) || matches(g.description))
            .take(20)
            .toList(growable: false);
        _notes = notes
            .where((Note n) => matches(n.title) || matches(n.body))
            .take(20)
            .toList(growable: false);
        _transactions = transactions
            .where((MoneyTransaction t) => matches(t.note))
            .take(20)
            .toList(growable: false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool empty = _term.isEmpty;
    final bool noResults = !empty &&
        !_searching &&
        _tasks.isEmpty &&
        _projects.isEmpty &&
        _goals.isEmpty &&
        _notes.isEmpty &&
        _transactions.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search everything…',
            border: InputBorder.none,
            filled: false,
          ),
        ),
      ),
      body: empty
          ? const EmptyStateView(
              message: 'Search tasks, projects, goals, notes, and '
                  'transactions.',
              icon: Icons.search,
            )
          : _searching
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: LoadingShimmer(height: 120),
                )
              : noResults
                  ? EmptyStateView(
                      message: 'Nothing found for "$_term".',
                      icon: Icons.search_off,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: <Widget>[
                        if (_tasks.isNotEmpty)
                          _Section(
                            title: 'TASKS',
                            children: <Widget>[
                              for (final Task t in _tasks)
                                AppListRow(
                                  title: t.title,
                                  leading: const Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                  ),
                                  onTap: () =>
                                      context.go('/future/task/${t.id}'),
                                ),
                            ],
                          ),
                        if (_projects.isNotEmpty)
                          _Section(
                            title: 'PROJECTS',
                            children: <Widget>[
                              for (final Project p in _projects)
                                AppListRow(
                                  title: p.title,
                                  leading: const Icon(
                                    Icons.folder_outlined,
                                    size: 20,
                                  ),
                                  onTap: () =>
                                      context.go('/future/project/${p.id}'),
                                ),
                            ],
                          ),
                        if (_goals.isNotEmpty)
                          _Section(
                            title: 'GOALS',
                            children: <Widget>[
                              for (final Goal g in _goals)
                                AppListRow(
                                  title: g.title,
                                  leading: const Icon(
                                    Icons.track_changes,
                                    size: 20,
                                  ),
                                  onTap: () =>
                                      context.go('/future/goal/${g.id}'),
                                ),
                            ],
                          ),
                        if (_transactions.isNotEmpty)
                          _Section(
                            title: 'TRANSACTIONS',
                            children: <Widget>[
                              for (final MoneyTransaction t in _transactions)
                                AppListRow(
                                  title: t.note ?? '(no note)',
                                  leading: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 20,
                                  ),
                                  onTap: () => context
                                      .go('/money/transactions/${t.id}'),
                                ),
                            ],
                          ),
                        if (_notes.isNotEmpty)
                          _Section(
                            title: 'NOTES',
                            children: <Widget>[
                              for (final Note n in _notes)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (n.title != null)
                                        Text(
                                          n.title!,
                                          style: AppTypography.titleMedium,
                                        ),
                                      if (n.body != null)
                                        Text(
                                          n.body!,
                                          style: AppTypography.bodyMedium,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.labelMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(children: children),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
