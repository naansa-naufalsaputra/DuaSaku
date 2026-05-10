import { 
  getCurrentMonthYear, 
  getLastMonthYear, 
  fetchBudgets, 
  upsertBudget, 
  calculateSpendingForecast,
  fetchMonthlySpending,
  copyBudgetsFromLastMonth,
  fetchBudgetsWithSpending
} from '../budgetService';
import { supabase } from '../supabase';

// Mock supabase to prevent initialization errors in test environment
const mockQueryBuilder = {
  select: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  gte: jest.fn().mockReturnThis(),
  lt: jest.fn().mockReturnThis(),
  maybeSingle: jest.fn().mockReturnThis(),
  insert: jest.fn().mockReturnThis(),
  update: jest.fn().mockReturnThis(),
  upsert: jest.fn().mockReturnThis(),
  delete: jest.fn().mockReturnThis(),
  then: jest.fn(function(cb) {
    return Promise.resolve(cb({ data: [], error: null }));
  }),
};

jest.mock('../supabase', () => ({
  supabase: {
    from: jest.fn(() => mockQueryBuilder),
  },
}));

describe('BudgetService', () => {
  const userId = 'user-123';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Date Helpers', () => {
    test('getCurrentMonthYear returns a string in YYYY-MM format', () => {
      const res = getCurrentMonthYear();
      expect(res).toMatch(/^\d{4}-\d{2}$/);
    });

    test('getLastMonthYear returns a string in YYYY-MM format', () => {
      const res = getLastMonthYear();
      expect(res).toMatch(/^\d{4}-\d{2}$/);
    });
  });

  describe('CRUD Operations', () => {
    test('fetchBudgets calls supabase with correct params', async () => {
      const mockData = [{ id: '1', category: 'Food', budget_amount: 1000, month: '2026-05' }];
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: mockData, error: null }));
      
      const res = await fetchBudgets(userId, '2026-05');
      expect(supabase.from).toHaveBeenCalledWith('category_budgets');
      expect(res).toEqual(mockData);
    });

    test('upsertBudget inserts new budget when none exists', async () => {
      // Mock maybeSingle to return no existing budget
      (mockQueryBuilder.maybeSingle as jest.Mock).mockReturnValueOnce(Promise.resolve({ data: null, error: null }));
      // Mock insert to return success
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: null, error: null }));

      const res = await upsertBudget(userId, 'Food', 1000000);
      expect(res.success).toBe(true);
      expect(mockQueryBuilder.insert).toHaveBeenCalled();
    });

    test('upsertBudget updates budget when it already exists', async () => {
      // Mock maybeSingle to return an existing budget
      (mockQueryBuilder.maybeSingle as jest.Mock).mockReturnValueOnce(Promise.resolve({ data: { id: 'ext-1' }, error: null }));
      // Mock update to return success
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: null, error: null }));

      const res = await upsertBudget(userId, 'Food', 2000000);
      expect(res.success).toBe(true);
      expect(mockQueryBuilder.update).toHaveBeenCalled();
    });
  });

  describe('Forecasting', () => {
    test('fetchBudgetsWithSpending combines budgets and spending', async () => {
      const mockBudgets = [{ category: 'Food', budget_amount: 1000000 }];
      const mockTransactions = [{ category: 'Food', amount: 400000 }];
      
      // First call (fetchBudgets)
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: mockBudgets, error: null }));
      // Second call (fetchMonthlySpending)
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: mockTransactions, error: null }));

      const res = await fetchBudgetsWithSpending(userId, '2026-05');
      expect(res[0].spent).toBe(400000);
      expect(res[0].remaining).toBe(600000);
      expect(res[0].percentage).toBe(40);
    });

    test('fetchMonthlySpending aggregates transaction data correctly', async () => {
      const mockTransactions = [
        { category: 'Food', amount: 50000 },
        { category: 'Food', amount: 25000 },
        { category: 'Transport', amount: 30000 },
      ];
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: mockTransactions, error: null }));

      const res = await fetchMonthlySpending(userId, '2026-05');
      expect(res['Food']).toBe(75000);
      expect(res['Transport']).toBe(30000);
    });

    test('calculateSpendingForecast returns reasonable values', async () => {
      const mockTransactions = [
        { category: 'Food', amount: 1000000 }, // Total 1jt
      ];
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: mockTransactions, error: null }));

      const res = await calculateSpendingForecast(userId);
      expect(res.currentExpense).toBe(1000000);
      expect(res.forecastedExpense).toBeGreaterThan(res.currentExpense);
      expect(res.velocity).toBeGreaterThan(0);
    });
  });

  describe('Sync & Copy', () => {
    test('copyBudgetsFromLastMonth copies data correctly', async () => {
      const lastMonthData = [
        { category: 'Food', budget_amount: 1000000 },
        { category: 'Transport', budget_amount: 500000 },
      ];
      
      // First call to fetchBudgets (for last month)
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: lastMonthData, error: null }));
      
      // Subsequent calls for upsertBudget (check existing and then insert/update)
      // For Food: maybeSingle then insert/update
      (mockQueryBuilder.maybeSingle as jest.Mock).mockReturnValueOnce(Promise.resolve({ data: null, error: null }));
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: null, error: null }));
      
      // For Transport: maybeSingle then insert/update
      (mockQueryBuilder.maybeSingle as jest.Mock).mockReturnValueOnce(Promise.resolve({ data: null, error: null }));
      (mockQueryBuilder.then as jest.Mock).mockImplementationOnce((cb) => cb({ data: null, error: null }));

      const res = await copyBudgetsFromLastMonth(userId);
      expect(res.copied).toBe(2);
    });
  });
});
