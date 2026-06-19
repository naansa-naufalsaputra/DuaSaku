import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(ref);
});

class CloudSyncService {
  final Ref _ref;
  final GoogleSignIn _googleSignIn;

  CloudSyncService(this._ref, {GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: ['https://www.googleapis.com/auth/drive.appdata'],
          );

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('[CloudSyncService] Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[CloudSyncService] Error signing out: $e');
    }
  }

  Future<bool> get isConnected async {
    return await _googleSignIn.isSignedIn();
  }

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('[CloudSyncService] Error signing in silently: $e');
      return null;
    }
  }

  @visibleForTesting
  drive.DriveApi getDriveApi(http.Client client) => drive.DriveApi(client);

  Future<bool> backupToCloud(String pin) async {
    try {
      final account = _googleSignIn.currentUser ?? await signInSilently();
      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = getDriveApi(authenticateClient);

      // 1. Generate local plaintext backup
      final backupService = _ref.read(backupServiceProvider);
      final backupPlaintext = await backupService.generateBackupPlaintext();

      // 2. Encrypt using client-side AES-256 (via user security PIN)
      final encryptedPayload = backupService.encryptBackup(
        backupPlaintext,
        pin,
      );

      // 3. Upload payload to appData folder in Google Drive
      final media = drive.Media(
        Stream.value(utf8.encode(encryptedPayload)),
        encryptedPayload.length,
      );

      final driveFile = drive.File()
        ..name = 'duasaku_backup.enc'
        ..parents = ['appDataFolder'];

      // Check if file already exists in AppData
      final list = await driveApi.files.list(
        spaces: 'appData',
        q: "name = 'duasaku_backup.enc'",
      );

      if (list.files != null && list.files!.isNotEmpty) {
        final oldFileId = list.files!.first.id!;
        await driveApi.files.update(driveFile, oldFileId, uploadMedia: media);
      } else {
        await driveApi.files.create(driveFile, uploadMedia: media);
      }

      // 4. Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_cloud_sync_time',
        DateTime.now().toIso8601String(),
      );

      return true;
    } catch (e) {
      debugPrint('[CloudSyncService] Error during backup: $e');
      return false;
    }
  }

  Future<bool> restoreFromCloud(String pin) async {
    try {
      final account = _googleSignIn.currentUser ?? await signInSilently();
      if (account == null) return false;

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = getDriveApi(authenticateClient);

      // 1. Find file in appData space
      final list = await driveApi.files.list(
        spaces: 'appData',
        q: "name = 'duasaku_backup.enc'",
      );

      if (list.files == null || list.files!.isEmpty) {
        return false;
      }
      final fileId = list.files!.first.id!;

      // 2. Download file contents
      final media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = await media.stream.fold<List<int>>(
        [],
        (prev, element) => prev..addAll(element),
      );
      final encryptedPayload = utf8.decode(bytes);

      // 3. Decrypt payload locally using user PIN
      final backupService = _ref.read(backupServiceProvider);
      final decryptedPlaintext = backupService.decryptBackup(
        encryptedPayload,
        pin,
      );

      // 4. Restore database records atomically
      await backupService.restoreFromPlaintext(decryptedPlaintext);

      return true;
    } catch (e) {
      debugPrint('[CloudSyncService] Error during restore: $e');
      return false;
    }
  }
}
