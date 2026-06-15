import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'main_scaffold.dart';
import '../../features/auth/presentation/screens/pin_auth_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/transactions/presentation/screens/home_screen.dart';
import '../../features/transactions/presentation/screens/history_screen.dart';
import '../../features/transactions/presentation/screens/budget_screen.dart';
import '../../features/transactions/presentation/screens/manage_categories_screen.dart';

import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../security/security_service.dart';
import '../../features/wallets/presentation/screens/manage_wallets_screen.dart';
import '../../features/wallets/presentation/screens/wallet_detail_screen.dart';
import '../../features/recurring_transactions/presentation/screens/recurring_transactions_screen.dart';
import '../../features/recurring_transactions/presentation/screens/recurring_transaction_detail_screen.dart';
import '../../features/goals/domain/models/goal_model.dart';
import '../../features/goals/presentation/screens/goal_list_screen.dart';
import '../../features/goals/presentation/screens/goal_detail_screen.dart';
import '../../features/goals/presentation/screens/goal_form_screen.dart';
import '../../features/goals/presentation/screens/goal_deposit_screen.dart';
import '../../features/smart_budget_alerts/presentation/screens/alert_center_screen.dart';
import '../../features/smart_budget_alerts/presentation/screens/budget_detail_screen.dart';
import '../../features/export_import/presentation/screens/export_screen.dart';
import '../../features/export_import/presentation/screens/import_confirmation_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Use AuthRepository directly as refreshListenable (it's a ChangeNotifier now)
  final authRepo = ref.read(authRepositoryProvider);

  // Listen to securityProvider changes and notify the router via authRepo
  ref.listen(securityProvider, (previous, next) {
    authRepo.notifyListeners();
  });

  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: authRepo,
    redirect: (context, state) {
      final authRepo = ref.read(authRepositoryProvider);
      final isOnboardingCompleted = authRepo.isOnboardingCompleted;
      final securityState = ref.read(securityProvider);
      final authState = authRepo.currentAuthState;
      final isAuthenticated = authState.isAuthenticated;

      // 0. If either AuthRepository or SecurityNotifier is not initialized, wait.
      if (!securityState.isInitialized || !authRepo.isInitialized) {
        return null;
      }

      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToPinAuth = state.matchedLocation == '/pin-auth';
      final isChangingPin = state.uri.queryParameters['mode'] == 'change';

      // 1. If onboarding is not completed, redirect to /onboarding
      if (!isOnboardingCompleted) {
        if (!isGoingToOnboarding) {
          return '/onboarding';
        }
        return null;
      }

      // 2. If onboarding is completed and we're on /onboarding, go to home or pin-auth
      if (isGoingToOnboarding) {
        return (isAuthenticated || !securityState.isSecurityEnabled)
            ? '/home'
            : '/pin-auth';
      }

      // 3. Standard auth check
      if (!isAuthenticated &&
          !isGoingToPinAuth &&
          securityState.isSecurityEnabled) {
        return '/pin-auth';
      }

      if ((isAuthenticated || !securityState.isSecurityEnabled) &&
          isGoingToPinAuth &&
          !isChangingPin) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pin-auth',
        builder: (context, state) {
          final isChangeMode = state.uri.queryParameters['mode'] == 'change';
          return PinAuthScreen(isChangePinMode: isChangeMode);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                builder: (context, state) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/budgets',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ManageCategoriesScreen(),
      ),
      GoRoute(
        path: '/manage-wallets',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ManageWalletsScreen(),
      ),
      GoRoute(
        path: '/wallets/:walletId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final walletId = state.pathParameters['walletId']!;
          return WalletDetailScreen(walletId: walletId);
        },
      ),
      GoRoute(
        path: '/recurring-transactions',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RecurringTransactionsScreen(),
      ),
      GoRoute(
        path: '/recurring-transactions/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecurringTransactionDetailScreen(recurringTransactionId: id);
        },
      ),
      GoRoute(
        path: '/goals',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const GoalListScreen(),
      ),
      GoRoute(
        path: '/goals/create',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const GoalFormScreen(),
      ),
      GoRoute(
        path: '/goals/:goalId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final goalId = state.pathParameters['goalId']!;
          return GoalDetailScreen(goalId: goalId);
        },
      ),
      GoRoute(
        path: '/goals/:goalId/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final goal = state.extra as GoalModel?;
          return GoalFormScreen(goal: goal);
        },
      ),
      GoRoute(
        path: '/goals/:goalId/deposit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final goal = state.extra as GoalModel;
          return GoalDepositScreen(goal: goal);
        },
      ),
      GoRoute(
        path: '/alert-center',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final highlightAlertId = state.uri.queryParameters['alertId'];
          return AlertCenterScreen(highlightAlertId: highlightAlertId);
        },
      ),
      GoRoute(
        path: '/budgets/detail/:categoryId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final categoryId = state.pathParameters['categoryId']!;
          final extra = state.extra as BudgetDetailExtra?;
          return BudgetDetailScreen(categoryId: categoryId, extra: extra);
        },
      ),
      GoRoute(
        path: '/export',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/import',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ImportConfirmationScreen(),
      ),
    ],
  );
});
