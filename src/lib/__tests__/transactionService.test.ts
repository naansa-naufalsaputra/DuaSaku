import { createTransaction, updateTransaction, deleteTransaction } from '../transactionService';
import { supabase } from '../supabase';
import { getIsConnected } from '../networkMonitor';
import { enqueueTransaction } from '../offlineSync';

const mockQueryBuilder = {
  insert: jest.fn().mockReturnThis(),
  update: jest.fn().mockReturnThis(),
  delete: jest.fn().mockReturnThis(),
  eq: jest.fn().mockReturnThis(),
  then: jest.fn(function (cb) {
    return Promise.resolve(cb({ data: null, error: null }));
  }),
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
  processSyncQueue: jest.fn(),
}));

describe('TransactionService', () => {
  const userId = 'test-user-id';
  
  test('createTransaction returns success on valid data', async () => {
    const res = await createTransaction({
      title: 'Coffee',
      amount: 50000,
      type: 'expense',
      category: 'Food',
      user_id: userId,
    });
    expect(res.success).toBe(true);
  });

  test('updateTransaction returns success', async () => {
    const res = await updateTransaction('tx-id', {
      title: 'Updated Coffee',
    }, userId);
    expect(res.success).toBe(true);
    expect(supabase.from).toHaveBeenCalledWith('transactions');
    expect(mockQueryBuilder.update).toHaveBeenCalledWith({ title: 'Updated Coffee' });
    expect(mockQueryBuilder.eq).toHaveBeenCalledWith('id', 'tx-id');
    expect(mockQueryBuilder.eq).toHaveBeenCalledWith('user_id', userId);
  });

  test('deleteTransaction returns success', async () => {
    const res = await deleteTransaction('tx-id', userId);
    expect(res.success).toBe(true);
    expect(supabase.from).toHaveBeenCalledWith('transactions');
    expect(mockQueryBuilder.delete).toHaveBeenCalled();
    expect(mockQueryBuilder.eq).toHaveBeenCalledWith('id', 'tx-id');
    expect(mockQueryBuilder.eq).toHaveBeenCalledWith('user_id', userId);
  });

  describe('Offline Scenarios', () => {
    beforeEach(() => {
      (getIsConnected as jest.Mock).mockReturnValue(false);
      jest.clearAllMocks();
    });

    test('createTransaction enqueues when offline', async () => {
      const res = await createTransaction({
        title: 'Offline Coffee',
        amount: 50000,
        type: 'expense',
        category: 'Food',
        user_id: userId,
      });
      expect(res.success).toBe(true);
      expect(res.offline).toBe(true);
      expect(enqueueTransaction).toHaveBeenCalled();
    });

    test('updateTransaction enqueues when offline', async () => {
      const res = await updateTransaction('tx-id', { title: 'Updated' }, userId);
      expect(res.success).toBe(true);
      expect(res.offline).toBe(true);
      expect(enqueueTransaction).toHaveBeenCalledWith(
        expect.objectContaining({ remoteId: 'tx-id' }),
        'UPDATE'
      );
    });

    test('deleteTransaction enqueues when offline', async () => {
      const res = await deleteTransaction('tx-id', userId);
      expect(res.success).toBe(true);
      expect(res.offline).toBe(true);
      expect(enqueueTransaction).toHaveBeenCalledWith(
        expect.objectContaining({ remoteId: 'tx-id' }),
        'DELETE'
      );
    });
  });
});
