import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duasaku_app/core/services/cloud_sync_service.dart';
import 'package:duasaku_app/core/services/backup_service.dart';

// --- FAKES FOR TESTING ---

class FakeGoogleSignInAccount extends Fake implements GoogleSignInAccount {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authHeaders) {
      return Future.value({'Authorization': 'Bearer test_token'});
    }
    if (invocation.memberName == #email) {
      return 'test@gmail.com';
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeGoogleSignIn extends Fake implements GoogleSignIn {
  GoogleSignInAccount? mockUser;
  bool signedIn = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #currentUser) {
      return mockUser;
    }
    if (invocation.memberName == #signIn) {
      signedIn = true;
      return Future.value(mockUser);
    }
    if (invocation.memberName == #signInSilently) {
      signedIn = true;
      return Future.value(mockUser);
    }
    if (invocation.memberName == #signOut) {
      signedIn = false;
      return Future.value(null);
    }
    if (invocation.memberName == #isSignedIn) {
      return Future.value(signedIn);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeFilesResource extends Fake implements drive.FilesResource {
  final List<drive.File> filesList = [];
  drive.Media? downloadedMedia;
  drive.File? createdFile;
  drive.File? updatedFile;
  String? updatedFileId;
  
  bool listCalled = false;
  bool createCalled = false;
  bool updateCalled = false;
  bool getCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #list) {
      listCalled = true;
      return Future.value(drive.FileList()..files = filesList);
    }
    if (invocation.memberName == #create) {
      createCalled = true;
      createdFile = invocation.positionalArguments[0] as drive.File;
      return Future.value(createdFile!..id = 'new_file_id');
    }
    if (invocation.memberName == #update) {
      updateCalled = true;
      updatedFile = invocation.positionalArguments[0] as drive.File;
      updatedFileId = invocation.positionalArguments[1] as String;
      return Future.value(updatedFile!..id = updatedFileId);
    }
    if (invocation.memberName == #get) {
      getCalled = true;
      final downloadOptions = invocation.namedArguments[#downloadOptions] as drive.DownloadOptions?;
      if (downloadOptions == drive.DownloadOptions.fullMedia) {
        if (downloadedMedia != null) return Future.value(downloadedMedia!);
        throw Exception('No media set to download');
      }
      final fileId = invocation.positionalArguments[0] as String;
      return Future.value(drive.File()..id = fileId);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeDriveApi extends Fake implements drive.DriveApi {
  final FakeFilesResource mockFiles;
  FakeDriveApi(this.mockFiles);

  @override
  drive.FilesResource get files => mockFiles;
}

class FakeBackupService extends Fake implements BackupService {
  String plaintextToGenerate = '{"transactions":[]}';
  String encryptedPayloadToReturn = 'encrypted_data';
  String decryptedPayloadToReturn = 'decrypted_data';
  
  bool generateCalled = false;
  bool encryptCalled = false;
  bool decryptCalled = false;
  bool restoreCalled = false;
  
  String? encryptedWithPin;
  String? decryptedWithPin;
  String? restoredPlaintext;

  @override
  Future<String> generateBackupPlaintext() async {
    generateCalled = true;
    return plaintextToGenerate;
  }

  @override
  String encryptBackup(String plaintext, String password) {
    encryptCalled = true;
    encryptedWithPin = password;
    return encryptedPayloadToReturn;
  }

  @override
  String decryptBackup(String ciphertextJson, String password) {
    decryptCalled = true;
    decryptedWithPin = password;
    return decryptedPayloadToReturn;
  }

  @override
  Future<void> restoreFromPlaintext(String plaintext) async {
    restoreCalled = true;
    restoredPlaintext = plaintext;
  }
}

// Subclass to override getDriveApi with our fake
class TestCloudSyncService extends CloudSyncService {
  final drive.DriveApi mockDriveApi;
  
  TestCloudSyncService(super.ref, {required this.mockDriveApi, super.googleSignIn});

  @override
  drive.DriveApi getDriveApi(dynamic client) => mockDriveApi;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late FakeGoogleSignIn fakeGoogleSignIn;
  late FakeGoogleSignInAccount fakeUser;
  late FakeFilesResource fakeFiles;
  late FakeDriveApi fakeDriveApi;
  late FakeBackupService fakeBackupService;
  late ProviderContainer container;
  late TestCloudSyncService cloudSyncService;

  final testCloudSyncServiceProvider = Provider<TestCloudSyncService>((ref) {
    return TestCloudSyncService(
      ref,
      mockDriveApi: fakeDriveApi,
      googleSignIn: fakeGoogleSignIn,
    );
  });

  setUp(() {
    fakeUser = FakeGoogleSignInAccount();
    fakeGoogleSignIn = FakeGoogleSignIn();
    fakeFiles = FakeFilesResource();
    fakeDriveApi = FakeDriveApi(fakeFiles);
    fakeBackupService = FakeBackupService();

    container = ProviderContainer(
      overrides: [
        backupServiceProvider.overrideWithValue(fakeBackupService),
      ],
    );

    cloudSyncService = container.read(testCloudSyncServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('CloudSyncService Connection Tests', () {
    test('isConnected returns false initially', () async {
      expect(await cloudSyncService.isConnected, isFalse);
    });

    test('signIn triggers GoogleSignIn signIn and returns user', () async {
      fakeGoogleSignIn.mockUser = fakeUser;
      final result = await cloudSyncService.signIn();
      expect(result, isNotNull);
      expect(result!.email, 'test@gmail.com');
      expect(await cloudSyncService.isConnected, isTrue);
    });

    test('signOut triggers GoogleSignIn signOut', () async {
      fakeGoogleSignIn.mockUser = fakeUser;
      fakeGoogleSignIn.signedIn = true;
      await cloudSyncService.signOut();
      expect(await cloudSyncService.isConnected, isFalse);
    });
  });

  group('CloudSyncService Backup Tests', () {
    test('backupToCloud returns false if no user is signed in', () async {
      final success = await cloudSyncService.backupToCloud('1234');
      expect(success, isFalse);
    });

    test('backupToCloud creates new file in Google Drive AppData if not exists', () async {
      fakeGoogleSignIn.mockUser = fakeUser;
      fakeGoogleSignIn.signedIn = true;
      fakeFiles.filesList.clear(); // Empty files list

      final success = await cloudSyncService.backupToCloud('1234');

      expect(success, isTrue);
      expect(fakeBackupService.generateCalled, isTrue);
      expect(fakeBackupService.encryptCalled, isTrue);
      expect(fakeBackupService.encryptedWithPin, '1234');
      expect(fakeFiles.listCalled, isTrue);
      expect(fakeFiles.createCalled, isTrue);
      expect(fakeFiles.updateCalled, isFalse);
    });

    test('backupToCloud updates existing file in Google Drive AppData if exists', () async {
      fakeGoogleSignIn.mockUser = fakeUser;
      fakeGoogleSignIn.signedIn = true;
      fakeFiles.filesList.add(drive.File()..id = 'existing_file_id');

      final success = await cloudSyncService.backupToCloud('1234');

      expect(success, isTrue);
      expect(fakeBackupService.generateCalled, isTrue);
      expect(fakeBackupService.encryptCalled, isTrue);
      expect(fakeFiles.listCalled, isTrue);
      expect(fakeFiles.createCalled, isFalse);
      expect(fakeFiles.updateCalled, isTrue);
      expect(fakeFiles.updatedFileId, 'existing_file_id');
    });
  });

  group('CloudSyncService Restore Tests', () {
    test('restoreFromCloud returns false if no user is signed in', () async {
      final success = await cloudSyncService.restoreFromCloud('1234');
      expect(success, isFalse);
    });

    test('restoreFromCloud returns false if backup file is not found', () async {
      fakeGoogleSignIn.mockUser = fakeUser;
      fakeGoogleSignIn.signedIn = true;
      fakeFiles.filesList.clear(); // File doesn't exist

      final success = await cloudSyncService.restoreFromCloud('1234');
      expect(success, isFalse);
    });

    test('restoreFromCloud decrypts and restores backup successfully', () async {
      fakeGoogleSignIn.mockUser = fakeUser;
      fakeGoogleSignIn.signedIn = true;
      fakeFiles.filesList.add(drive.File()..id = 'backup_file_id');
      
      const payloadString = 'encrypted_payload_data';
      fakeFiles.downloadedMedia = drive.Media(
        Stream.value(utf8.encode(payloadString)),
        payloadString.length,
      );

      final success = await cloudSyncService.restoreFromCloud('1234');

      expect(success, isTrue);
      expect(fakeFiles.listCalled, isTrue);
      expect(fakeFiles.getCalled, isTrue);
      expect(fakeBackupService.decryptCalled, isTrue);
      expect(fakeBackupService.decryptedWithPin, '1234');
      expect(fakeBackupService.restoreCalled, isTrue);
    });
  });
}
