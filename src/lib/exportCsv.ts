import { File, Paths } from 'expo-file-system/next';
import { isAvailableAsync, shareAsync } from 'expo-sharing';

export async function exportTransactionsToCSV(transactions: any[]) {
  try {
    // Bikin header CSV
    let csvString = 'Tanggal,Judul,Kategori,Tipe,Nominal\n';

    // Loop data transaksi jadi baris CSV
    transactions.forEach((tx) => {
      // Format: Date, Title, Category, Type, Amount
      const date = tx.date || (tx.created_at ? tx.created_at.split('T')[0] : '');
      csvString += `${date},${tx.title},${tx.category},${tx.type},${tx.amount}\n`;
    });

    // Simpan ke memori sementara (Cache)
    const file = new File(Paths.cache, `Laporan_DuaSaku_${new Date().getTime()}.csv`);
    file.write(csvString);
    const fileUri = file.uri;

    // Buka menu Share native HP
    const canShare = await isAvailableAsync();
    if (canShare) {
      await shareAsync(fileUri, {
        mimeType: 'text/csv',
        dialogTitle: 'Bagikan Laporan DuaSaku',
      });
    }
  } catch (error) {
    console.error('Gagal mengekspor CSV:', error);
  }
}
