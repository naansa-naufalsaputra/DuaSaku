import { getCurrentMonthYear, getLastMonthYear } from '../budgetService';

// Mock supabase to prevent initialization errors in test environment
jest.mock('../supabase', () => ({
  supabase: {
    from: jest.fn(() => ({
      select: jest.fn(() => ({
        eq: jest.fn(() => ({
          eq: jest.fn(() => Promise.resolve({ data: [], error: null })),
        })),
      })),
      upsert: jest.fn(() => Promise.resolve({ data: null, error: null })),
    })),
  },
}));

describe('BudgetService Date Helpers', () => {
  test('getCurrentMonthYear returns a string', () => {
    expect(typeof getCurrentMonthYear()).toBe('string');
  });

  test('getLastMonthYear returns a string', () => {
    expect(typeof getLastMonthYear()).toBe('string');
  });
});
