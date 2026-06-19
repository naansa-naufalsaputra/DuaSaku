import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local_db/app_database_provider.dart';
import './balance_integrity/balance_integrity_service.dart';

/// Provider for [BalanceIntegrityService] singleton.
final balanceIntegrityServiceProvider = Provider<BalanceIntegrityService>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return BalanceIntegrityService(db);
});
