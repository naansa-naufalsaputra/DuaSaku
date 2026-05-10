import { createTransfer } from '../transferService';
import { supabase } from '../supabase';
import { getIsConnected } from '../networkMonitor';
import { enqueueTransaction } from '../offlineSync';

const mockQueryBuilder = {
  insert: jest.fn(() => Promise.resolve({ data: null, error: null })),
};

jest.mock('../supabase', () => ({
  supabase: {
    from: jest.fn(() => mockQueryBuilder),
  },
}));

jest.mock('../networkMonitor', () => ({
  getIsConnected: jest.fn(() => true),
}));

jest.mock('../offlineSync', () => ({
  enqueueTransaction: jest.fn(),
}));

describe('TransferService', () => {
  const params = {
    fromWalletId: 'w1',
    toWalletId: 'w2',
    amount: 100000,
    title: 'Monthly Savings',
    category: 'Investment',
    userId: 'user-123',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('createTransfer inserts two transactions when online', async () => {
    (getIsConnected as jest.Mock).mockReturnValue(true);
    const res = await createTransfer(params);
    
    expect(res.success).toBe(true);
    expect(supabase.from).toHaveBeenCalledWith('transactions');
    expect(mockQueryBuilder.insert).toHaveBeenCalled();
    const insertedRows = (mockQueryBuilder.insert as jest.Mock).mock.calls[0][0];
    expect(insertedRows).toHaveLength(2);
    expect(insertedRows[0].type).toBe('expense');
    expect(insertedRows[1].type).toBe('income');
    expect(insertedRows[0].transfer_group_id).toBe(insertedRows[1].transfer_group_id);
  });

  test('createTransfer enqueues two transactions when offline', async () => {
    (getIsConnected as jest.Mock).mockReturnValue(false);
    const res = await createTransfer(params);
    
    expect(res.success).toBe(true);
    expect(res.offline).toBe(true);
    expect(enqueueTransaction).toHaveBeenCalledTimes(2);
    
    const firstCall = (enqueueTransaction as jest.Mock).mock.calls[0][0];
    const secondCall = (enqueueTransaction as jest.Mock).mock.calls[1][0];
    
    expect(firstCall.type).toBe('expense');
    expect(secondCall.type).toBe('income');
    expect(firstCall.transfer_group_id).toBe(secondCall.transfer_group_id);
  });

  describe('Validation', () => {
    test('rejects transfer with zero or negative amount', async () => {
      const res = await createTransfer({ ...params, amount: 0 });
      expect(res.success).toBe(false);
      expect(res.error).toBe('Amount must be greater than zero');
    });

    test('rejects transfer to the same wallet', async () => {
      const res = await createTransfer({ ...params, toWalletId: 'w1' });
      expect(res.success).toBe(false);
      expect(res.error).toBe('Source and destination wallets must be different');
    });
  });
});
