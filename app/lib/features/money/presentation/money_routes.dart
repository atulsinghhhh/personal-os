import 'package:go_router/go_router.dart';

import '../transactions/domain/entities/transaction_entities.dart';
import 'screens/account_detail_screen.dart';
import 'screens/accounts_list_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/budget_detail_screen.dart';
import 'screens/budgets_list_screen.dart';
import 'screens/conflicts_screen.dart';
import 'screens/debts_screen.dart';
import 'screens/financial_goals_screen.dart';
import 'screens/money_analytics_screen.dart';
import 'screens/net_worth_screen.dart';
import 'screens/savings_goals_screen.dart';
import 'screens/subscriptions_screen.dart';
import 'screens/transaction_detail_screen.dart';
import 'screens/transactions_list_screen.dart';

/// Sub-routes of the Money tab, spliced in as children of the '/money'
/// route. Paths are relative; screens navigate with absolute paths
/// (e.g. `context.go('/money/transactions/1')`).
final List<RouteBase> moneySubRoutes = <RouteBase>[
  GoRoute(
    path: 'accounts',
    builder: (_, _) => const AccountsListScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: ':id',
        builder: (_, GoRouterState state) =>
            AccountDetailScreen(accountId: state.pathParameters['id']!),
      ),
    ],
  ),
  GoRoute(
    path: 'transactions',
    builder: (_, _) => const TransactionsListScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: ':id',
        builder: (_, GoRouterState state) => TransactionDetailScreen(
          transactionId: state.pathParameters['id']!,
        ),
      ),
    ],
  ),
  GoRoute(
    path: 'add-expense',
    builder: (_, _) =>
        const AddTransactionScreen(kind: TransactionKind.expense),
  ),
  GoRoute(
    path: 'add-income',
    builder: (_, _) =>
        const AddTransactionScreen(kind: TransactionKind.income),
  ),
  GoRoute(
    path: 'conflicts',
    builder: (_, _) => const ConflictsScreen(),
  ),
  GoRoute(
    path: 'budgets',
    builder: (_, _) => const BudgetsListScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: ':id',
        builder: (_, GoRouterState state) =>
            BudgetDetailScreen(budgetId: state.pathParameters['id']!),
      ),
    ],
  ),
  GoRoute(
    path: 'savings-goals',
    builder: (_, _) => const SavingsGoalsScreen(),
  ),
  GoRoute(
    path: 'financial-goals',
    builder: (_, _) => const FinancialGoalsScreen(),
  ),
  GoRoute(
    path: 'bills',
    builder: (_, _) => const BillsScreen(),
  ),
  GoRoute(
    path: 'subscriptions',
    builder: (_, _) => const SubscriptionsScreen(),
  ),
  GoRoute(
    path: 'debts',
    builder: (_, _) => const DebtsScreen(),
  ),
  GoRoute(
    path: 'net-worth',
    builder: (_, _) => const NetWorthScreen(),
  ),
  GoRoute(
    path: 'analytics',
    builder: (_, _) => const MoneyAnalyticsScreen(),
  ),
];
