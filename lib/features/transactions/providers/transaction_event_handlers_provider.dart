import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/event_bus_provider.dart';
import '../../wallets/providers/wallet_provider.dart';
import '../services/transaction_event_handlers.dart';
import '../providers/transaction_provider.dart';
import '../../smart_budget_alerts/providers/alert_center_provider.dart';

/// Provider for the transaction event handlers service.
///
/// Automatically registers handlers to listen to the event stream
/// when the provider is first accessed.
final transactionEventHandlersProvider = Provider<TransactionEventHandlers>((
  ref,
) {
  final walletRepo = ref.watch(walletRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final budgetEvaluator = ref.watch(budgetAlertEvaluatorProvider);
  final eventController = ref.watch(transactionEventBusProvider);

  final handlers = TransactionEventHandlers(walletRepo, transactionRepo, budgetEvaluator);

  // Register handlers to listen to event stream
  handlers.registerHandlers(eventController.stream);

  return handlers;
});
