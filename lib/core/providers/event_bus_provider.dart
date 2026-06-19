import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/transactions/domain/transaction_events.dart';

/// Global event bus for transaction domain events.
/// 
/// Uses a broadcast StreamController to allow multiple listeners.
/// The controller is automatically closed when the provider is disposed.
final transactionEventBusProvider = Provider<StreamController<TransactionEvent>>((ref) {
  final controller = StreamController<TransactionEvent>.broadcast();
  
  ref.onDispose(() {
    controller.close();
  });
  
  return controller;
});

/// Stream of transaction events for listeners to subscribe to.
/// 
/// Event handlers should watch this stream to react to transaction changes.
final transactionEventStreamProvider = StreamProvider<TransactionEvent>((ref) {
  final controller = ref.watch(transactionEventBusProvider);
  return controller.stream;
});

/// Sink for emitting transaction events.
/// 
/// The repository uses this sink to publish events after successful operations.
final transactionEventSinkProvider = Provider<StreamSink<TransactionEvent>>((ref) {
  final controller = ref.watch(transactionEventBusProvider);
  return controller.sink;
});
