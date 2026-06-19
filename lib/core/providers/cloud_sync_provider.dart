import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloud_sync_service.dart';

class CloudSyncState {
  final GoogleSignInAccount? currentUser;
  final bool isConnected;
  final bool isLoading;
  final String? lastSyncTime;
  final String? errorMessage;

  const CloudSyncState({
    this.currentUser,
    required this.isConnected,
    required this.isLoading,
    this.lastSyncTime,
    this.errorMessage,
  });

  CloudSyncState copyWith({
    GoogleSignInAccount? currentUser,
    bool? isConnected,
    bool? isLoading,
    String? lastSyncTime,
    String? errorMessage,
  }) {
    return CloudSyncState(
      currentUser: currentUser ?? this.currentUser,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CloudSyncNotifier extends Notifier<CloudSyncState> {
  @override
  CloudSyncState build() {
    _init();
    return const CloudSyncState(
      isConnected: false,
      isLoading: false,
    );
  }

  Future<void> _init() async {
    final service = ref.read(cloudSyncServiceProvider);
    final connected = await service.isConnected;
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_cloud_sync_time');
    
    GoogleSignInAccount? account = service.currentUser;
    if (connected && account == null) {
      account = await service.signInSilently();
    }

    state = CloudSyncState(
      currentUser: account,
      isConnected: connected && account != null,
      isLoading: false,
      lastSyncTime: lastSync,
    );
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final service = ref.read(cloudSyncServiceProvider);
    final account = await service.signIn();
    
    if (account != null) {
      state = state.copyWith(
        currentUser: account,
        isConnected: true,
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to connect to Google Drive',
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final service = ref.read(cloudSyncServiceProvider);
    await service.signOut();
    state = const CloudSyncState(
      isConnected: false,
      isLoading: false,
    );
  }

  Future<bool> performBackup(String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final service = ref.read(cloudSyncServiceProvider);
    final success = await service.backupToCloud(pin);
    
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('last_cloud_sync_time');
      state = state.copyWith(
        isLoading: false,
        lastSyncTime: lastSync,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Backup failed. Please check your connection.',
      );
      return false;
    }
  }

  Future<bool> performRestore(String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final service = ref.read(cloudSyncServiceProvider);
    final success = await service.restoreFromCloud(pin);
    
    if (success) {
      state = state.copyWith(isLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Restore failed. Please check PIN and connection.',
      );
      return false;
    }
  }
}

final cloudSyncProvider = NotifierProvider<CloudSyncNotifier, CloudSyncState>(() {
  return CloudSyncNotifier();
});
