import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../budgets/domain/entities/budget_entities.dart';
import '../../financial_goals/domain/entities/financial_goal.dart';
import '../../savings_goals/domain/entities/savings_goal.dart';
import '../../transactions/domain/entities/transaction_entities.dart';

/// Riverpod providers for the Money tab. Everything reads from local Drift
/// streams (offline-first); Future-based rollups re-run when the underlying
/// transaction streams emit.

// ------------------------------------------------------------- accounts --

final StreamProvider<List<FinancialAccount>> moneyAccountsProvider =
    StreamProvider<List<FinancialAccount>>((Ref ref) {
  return ref.watch(financialAccountRepositoryProvider).watchAll();
});

/// Includes archived accounts, for name lookups on old transactions.
final StreamProvider<List<FinancialAccount>> moneyAllAccountsProvider =
    StreamProvider<List<FinancialAccount>>((Ref ref) {
  return ref
      .watch(financialAccountRepositoryProvider)
      .watchAll(includeArchived: true);
});

/// Live balance for one account: recomputed whenever that account's
/// transactions change (the stream emission triggers the async rollup).
final StreamProviderFamily<Money, String> moneyAccountBalanceProvider =
    StreamProvider.family<Money, String>((Ref ref, String accountId) {
  // Re-create the stream when account rows change (e.g. opening balance).
  ref.watch(moneyAllAccountsProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchByAccount(accountId)
      .asyncMap(
        (List<MoneyTransaction> _) => ref
            .read(financialAccountRepositoryProvider)
            .currentBalance(accountId),
      );
});

final FutureProviderFamily<FinancialAccount?, String>
    moneyAccountByIdProvider =
    FutureProvider.family<FinancialAccount?, String>((
  Ref ref,
  String accountId,
) {
  // Refresh when the accounts table changes.
  ref.watch(moneyAllAccountsProvider);
  return ref.read(financialAccountRepositoryProvider).getById(accountId);
});

// --------------------------------------------------------- transactions --

final StreamProvider<List<MoneyTransaction>>
    moneyRecentTransactionsProvider =
    StreamProvider<List<MoneyTransaction>>((Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchRecent(10);
});

/// The full transaction history for the list screen. There is no unbounded
/// watch on the repository, so a generous limit stands in for "all".
final StreamProvider<List<MoneyTransaction>> moneyAllTransactionsProvider =
    StreamProvider<List<MoneyTransaction>>((Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchRecent(500);
});

final StreamProviderFamily<List<MoneyTransaction>, String>
    moneyAccountTransactionsProvider =
    StreamProvider.family<List<MoneyTransaction>, String>((
  Ref ref,
  String accountId,
) {
  return ref.watch(transactionRepositoryProvider).watchByAccount(accountId);
});

final FutureProviderFamily<MoneyTransaction?, String>
    moneyTransactionByIdProvider =
    FutureProvider.family<MoneyTransaction?, String>((
  Ref ref,
  String transactionId,
) {
  // Refresh whenever the transactions table changes.
  ref.watch(moneyAllTransactionsProvider);
  return ref.read(transactionRepositoryProvider).getById(transactionId);
});

/// This calendar month's transactions (for the dashboard summary).
final StreamProvider<List<MoneyTransaction>> moneyMonthTransactionsProvider =
    StreamProvider<List<MoneyTransaction>>((Ref ref) {
  final DateTime now = DateTime.now();
  final DateTime start = DateTime.utc(now.year, now.month, 1);
  final DateTime end = DateTime.utc(now.year, now.month + 1, 1);
  return ref.watch(transactionRepositoryProvider).watchForRange(start, end);
});

// ------------------------------------------------------------ categories --

final StreamProvider<List<TransactionCategory>> moneyCategoriesProvider =
    StreamProvider<List<TransactionCategory>>((Ref ref) {
  return ref.watch(transactionCategoryRepositoryProvider).watchAll();
});

// ------------------------------------------------------------- conflicts --

final StreamProvider<List<TransactionConflict>> moneyConflictsProvider =
    StreamProvider<List<TransactionConflict>>((Ref ref) {
  return ref.watch(transactionRepositoryProvider).watchUnresolvedConflicts();
});

// --------------------------------------------------------------- budgets --

final StreamProvider<List<Budget>> moneyBudgetsProvider =
    StreamProvider<List<Budget>>((Ref ref) {
  return ref.watch(budgetRepositoryProvider).watchAll();
});

final StreamProviderFamily<Budget?, String> moneyBudgetProvider =
    StreamProvider.family<Budget?, String>((Ref ref, String budgetId) {
  return ref.watch(budgetRepositoryProvider).watchAll().map(
    (List<Budget> budgets) {
      for (final Budget budget in budgets) {
        if (budget.id == budgetId) return budget;
      }
      return null;
    },
  );
});

final StreamProviderFamily<List<BudgetItem>, String>
    moneyBudgetItemsProvider =
    StreamProvider.family<List<BudgetItem>, String>((
  Ref ref,
  String budgetId,
) {
  return ref.watch(budgetRepositoryProvider).watchItems(budgetId);
});

/// Actual spend for one budget item; re-runs when transactions change.
final FutureProviderFamily<Money, (BudgetItem, Budget)>
    moneyBudgetItemSpentProvider =
    FutureProvider.family<Money, (BudgetItem, Budget)>((
  Ref ref,
  (BudgetItem, Budget) args,
) {
  ref.watch(moneyAllTransactionsProvider);
  return ref.read(budgetRepositoryProvider).spentForItem(args.$1, args.$2);
});

// --------------------------------------------------------- savings goals --

final StreamProvider<List<SavingsGoal>> moneySavingsGoalsProvider =
    StreamProvider<List<SavingsGoal>>((Ref ref) {
  return ref.watch(savingsGoalRepositoryProvider).watchAll();
});

// ------------------------------------------------------- financial goals --

final StreamProvider<List<FinancialGoal>> moneyFinancialGoalsProvider =
    StreamProvider<List<FinancialGoal>>((Ref ref) {
  return ref.watch(financialGoalRepositoryProvider).watchAll();
});

// ------------------------------------------- cross-feature link pickers --

final StreamProvider<List<Project>> moneyProjectsProvider =
    StreamProvider<List<Project>>((Ref ref) {
  return ref.watch(projectRepositoryProvider).watchAll();
});

final StreamProvider<List<Goal>> moneyLifeGoalsProvider =
    StreamProvider<List<Goal>>((Ref ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});
