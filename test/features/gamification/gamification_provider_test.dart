import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duasaku_app/features/gamification/providers/gamification_provider.dart';
import 'package:duasaku_app/features/transactions/providers/budget_provider.dart';
import 'package:duasaku_app/features/transactions/domain/models/budget_model.dart';
import 'package:duasaku_app/features/transactions/providers/transaction_provider.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';
import 'package:duasaku_app/features/wallets/providers/wallet_provider.dart';
import 'package:duasaku_app/features/wallets/domain/models/wallet_model.dart';

// Mock Notifiers
class MockBudgetNotifier extends BudgetNotifier {
  final List<BudgetProgress> _data;
  MockBudgetNotifier(this._data);

  @override
  Future<List<BudgetProgress>> build() async => _data;
}

class MockTransactionNotifier extends TransactionNotifier {
  final List<TransactionModel> _data;
  MockTransactionNotifier(this._data);

  @override
  Future<List<TransactionModel>> build() async => _data;
}

class MockWalletNotifier extends WalletNotifier {
  final List<WalletModel> _data;
  MockWalletNotifier(this._data);

  @override
  Future<List<WalletModel>> build() async => _data;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GamificationNotifier Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    ProviderContainer createContainer({
      List<BudgetProgress> budgets = const [],
      List<TransactionModel> transactions = const [],
      List<WalletModel> wallets = const [],
    }) {
      return ProviderContainer(
        overrides: [
          budgetNotifierProvider.overrideWith(
            () => MockBudgetNotifier(budgets),
          ),
          transactionNotifierProvider.overrideWith(
            () => MockTransactionNotifier(transactions),
          ),
          walletProvider.overrideWith(() => MockWalletNotifier(wallets)),
        ],
      );
    }

    test(
      'initializes state with defaults when SharedPreferences is empty',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);

        // Wait for async init inside notifier build()
        container.read(gamificationProvider.notifier).build();
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(gamificationProvider);
        expect(state.currentStreak, equals(0));
        expect(state.unlockedBadges, isEmpty);
        expect(
          state.healthScore,
          equals(55),
        ); // 40 points default S_budget + 15 points default S_saving when empty
      },
    );

    test(
      'restores streak and badges from SharedPreferences correctly',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_streak_days': 5,
          'user_unlocked_badges': ['streak_7', 'healthy_80'],
        });

        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(gamificationProvider.notifier);
        notifier.build();
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(gamificationProvider);

        expect(state.currentStreak, equals(5));
        expect(state.unlockedBadges, containsAll(['streak_7', 'healthy_80']));
      },
    );

    test(
      'logDailyActivity increments streak when logged in on consecutive days',
      () async {
        final yesterdayStr = DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String();
        SharedPreferences.setMockInitialValues({
          'user_streak_days': 3,
          'user_last_active_date': yesterdayStr,
        });

        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(gamificationProvider.notifier);
        notifier.build();
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.logDailyActivity();
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(gamificationProvider);
        expect(state.currentStreak, equals(4));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('user_streak_days'), equals(4));
      },
    );

    test(
      'logDailyActivity resets streak when last active was over 1 day ago',
      () async {
        final daysAgoStr = DateTime.now()
            .subtract(const Duration(days: 3))
            .toIso8601String();
        SharedPreferences.setMockInitialValues({
          'user_streak_days': 5,
          'user_last_active_date': daysAgoStr,
        });

        final container = createContainer();
        addTearDown(container.dispose);

        final notifier = container.read(gamificationProvider.notifier);
        notifier.build();
        await Future.delayed(const Duration(milliseconds: 50));

        await notifier.logDailyActivity();
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(gamificationProvider);
        expect(state.currentStreak, equals(1));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('user_streak_days'), equals(1));
      },
    );

    test(
      'calculates healthScore correctly based on budget overspend and saving ratio',
      () async {
        // 1. BudgetProgress: spent 500, limit 1000 (ratio 0.5, S_budget = 40 * (1 - 0.5) = 20)
        final mockBudget = BudgetModel(
          id: 'b1',
          userId: 'u1',
          category: 'Food',
          amountLimit: 1000.0,
          month: '2026-06',
          createdAt: DateTime.now(),
        );
        final budgets = [BudgetProgress(budget: mockBudget, spent: 500.0)];

        // 2. Transactions: Income 2000, Expense 1000 (saving ratio 0.5, S_saving = 30 * 0.5 = 15)
        final transactions = [
          TransactionModel(
            id: 1,
            userId: 'u1',
            amount: 2000.0,
            categoryId: 'salary',
            type: 'income',
            notes: 'Salary',
            createdAt: DateTime.now(),
          ),
          TransactionModel(
            id: 2,
            userId: 'u1',
            amount: 1000.0,
            categoryId: 'Food',
            type: 'expense',
            notes: 'Dinner',
            createdAt: DateTime.now(),
          ),
        ];

        // 3. Wallets: 2 wallets -> S_wallet = 5
        final wallets = [
          WalletModel(
            id: 'w1',
            userId: 'u1',
            name: 'BCA',
            type: 'Bank',
            balance: 10000.0,
            createdAt: DateTime.now(),
          ),
          WalletModel(
            id: 'w2',
            userId: 'u1',
            name: 'Cash',
            type: 'Cash',
            balance: 500.0,
            createdAt: DateTime.now(),
          ),
        ];

        final container = createContainer(
          budgets: budgets,
          transactions: transactions,
          wallets: wallets,
        );
        addTearDown(container.dispose);

        // Manually trigger initialization and calculation
        final notifier = container.read(gamificationProvider.notifier);
        notifier.build();
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(gamificationProvider);

        // Score components: S_budget (20) + S_saving (15) + S_streak (0) + S_wallet (5) + S_goal (0) = 40
        expect(state.scoreBudget, equals(20));
        expect(state.scoreSaving, equals(15));
        expect(state.scoreWallet, equals(5));
        expect(state.healthScore, equals(40));
      },
    );

    test(
      'awards badges correctly based on streak and transaction count thresholds',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_streak_days': 8, // Streak >= 7 triggers streak_7
        });

        // 50 expenses to trigger saver_master
        final transactions = List.generate(
          50,
          (index) => TransactionModel(
            id: index,
            userId: 'u1',
            amount: 10.0,
            categoryId: 'Food',
            type: 'expense',
            notes: 'Expense $index',
            createdAt: DateTime.now(),
          ),
        );

        final container = createContainer(transactions: transactions);
        addTearDown(container.dispose);

        final notifier = container.read(gamificationProvider.notifier);
        notifier.build();
        await Future.delayed(const Duration(milliseconds: 50));

        final state = container.read(gamificationProvider);
        expect(state.unlockedBadges, contains('streak_7'));
        expect(state.unlockedBadges, contains('saver_master'));
      },
    );
  });
}
