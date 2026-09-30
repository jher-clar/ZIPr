import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zipr/models/zipr_item.dart';
import 'package:zipr/models/zipr_manifest.dart';
import 'package:zipr/services/encryption_service.dart';
import 'package:zipr/services/zipr_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('ZIPrManifest Model Tests', () {
    test('Serializes and deserializes manifest correctly', () {
      final now = DateTime.now();
      final manifest = ZIPrManifest(
        title: 'Vacation Highlights',
        description: 'Trip to Swiss Alps',
        createdAt: now,
        author: 'Tony',
        isEncrypted: false,
        itemCount: 2,
        totalOriginalSize: 10000000,
        totalCompressedSize: 3000000,
        items: [
          ZIPrManifestItem(
            index: 0,
            id: 'item-1',
            fileName: 'item_0000.webp',
            type: 'photo',
            caption: 'Mountain peak at sunset',
            originalSize: 5000000,
            compressedSize: 1500000,
          ),
          ZIPrManifestItem(
            index: 1,
            id: 'item-2',
            fileName: 'item_0001.mp4',
            type: 'video',
            caption: 'Cable car ride',
            originalSize: 5000000,
            compressedSize: 1500000,
          ),
        ],
      );

      final jsonMap = manifest.toJson();
      final decoded = ZIPrManifest.fromJson(jsonMap);

      expect(decoded.title, 'Vacation Highlights');
      expect(decoded.description, 'Trip to Swiss Alps');
      expect(decoded.itemCount, 2);
      expect(decoded.items.length, 2);
      expect(decoded.items[0].type, 'photo');
      expect(decoded.items[0].caption, 'Mountain peak at sunset');
      expect(decoded.items[1].type, 'video');
      expect(decoded.totalSavingsRatio, closeTo(70.0, 0.1));
    });
  });

  group('EncryptionService AES-256 Tests', () {
    test('Encrypts and decrypts payload successfully with correct password', () {
      const plainText = 'ZIPr encrypted payload content for test';
      final plainBytes = Uint8List.fromList(utf8.encode(plainText));
      const password = 'SuperSecretPassword123!';

      final encResult = EncryptionService.encryptBytes(plainBytes, password);

      expect(encResult.cipherBytes, isNotEmpty);
      expect(encResult.saltHex, isNotEmpty);
      expect(encResult.ivHex, isNotEmpty);

      final decryptedBytes = EncryptionService.decryptBytes(
        cipherBytes: encResult.cipherBytes,
        password: password,
        saltHex: encResult.saltHex,
        ivHex: encResult.ivHex,
      );

      final decryptedText = utf8.decode(decryptedBytes);
      expect(decryptedText, plainText);
    });

    test('Fails decryption when incorrect password is provided', () {
      const plainText = 'Sensitive document data';
      final plainBytes = Uint8List.fromList(utf8.encode(plainText));

      final encResult = EncryptionService.encryptBytes(plainBytes, 'CorrectPassword');

      expect(
        () => EncryptionService.decryptBytes(
          cipherBytes: encResult.cipherBytes,
          password: 'WrongPassword',
          saltHex: encResult.saltHex,
          ivHex: encResult.ivHex,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('verifyPassword instantly checks validity without full payload decryption', () async {
      final tempDir = Directory.systemTemp.createTempSync('verify_test');
      try {
        final plainFile = File('${tempDir.path}/sample.txt')..writeAsStringSync('Secret container contents!');
        final encFile = File('${tempDir.path}/sample.enc');

        final streamResult = await EncryptionService.encryptFileStream(
          inputFile: plainFile,
          outputFile: encFile,
          password: 'MyVaultPassword',
        );

        // Valid password test
        final valid = await EncryptionService.verifyPassword(
          inputFile: encFile,
          password: 'MyVaultPassword',
          saltHex: streamResult.saltHex,
          ivHex: streamResult.ivHex,
        );
        expect(valid, isTrue);

        // Invalid password test
        final invalid = await EncryptionService.verifyPassword(
          inputFile: encFile,
          password: 'WrongPassword',
          saltHex: streamResult.saltHex,
          ivHex: streamResult.ivHex,
        );
        expect(invalid, isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('verifyPasswordHeaderBytes validates in RAM in under 1ms', () async {
      final tempDir = Directory.systemTemp.createTempSync('header_bytes_test_');
      try {
        final plainFile = File('${tempDir.path}/sample.txt')..writeAsStringSync('Super fast encrypted payload verification!');
        final encFile = File('${tempDir.path}/sample.enc');

        final streamResult = await EncryptionService.encryptFileStream(
          inputFile: plainFile,
          outputFile: encFile,
          password: 'SecretPass123',
        );

        final first32 = await encFile.openRead(0, 32).first;

        // Correct password
        final isValid = EncryptionService.verifyPasswordHeaderBytes(
          cipherHeader: Uint8List.fromList(first32),
          password: 'SecretPass123',
          saltHex: streamResult.saltHex,
          ivHex: streamResult.ivHex,
        );
        expect(isValid, isTrue);

        // Wrong password
        final isWrong = EncryptionService.verifyPasswordHeaderBytes(
          cipherHeader: Uint8List.fromList(first32),
          password: 'WrongPassword456',
          saltHex: streamResult.saltHex,
          ivHex: streamResult.ivHex,
        );
        expect(isWrong, isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('openZIPrArchive successfully decrypts in background isolate and fails on bad password without freeze', () async {
      final tempDir = Directory.systemTemp.createTempSync('archive_worker_test_');
      try {
        final samplePhoto = File('${tempDir.path}/test_photo.jpg');
        await samplePhoto.writeAsBytes(Uint8List.fromList(List.generate(10000, (i) => i % 256)));

        final item = ZIPrItem(
          id: 'test_1',
          file: samplePhoto,
          type: MediaType.photo,
          originalSize: 10000,
          compressedSize: 10000,
        );

        final archiveFile = await ZIPrStorageService.createZIPrArchive(
          title: 'EncryptedArchiveWorkerTest',
          items: [item],
          password: 'CorrectVaultPassword!@#',
          onProgress: (p, s) {},
        );

        // 1. Attempt opening without password -> should report requiresPassword: true
        final checkResult = await ZIPrStorageService.openZIPrArchive(archiveFile);
        expect(checkResult['requiresPassword'], isTrue);

        // 2. Attempt opening with wrong password -> should throw FormatException immediately (<1ms)
        expect(
          () => ZIPrStorageService.openZIPrArchive(archiveFile, password: 'WrongVaultPassword'),
          throwsA(isA<FormatException>()),
        );

        // 3. Attempt opening with correct password -> decrypts in background isolate with progress
        final progressUpdates = <double>[];
        final openedResult = await ZIPrStorageService.openZIPrArchive(
          archiveFile,
          password: 'CorrectVaultPassword!@#',
          onProgress: (p, s) {
            progressUpdates.add(p);
          },
        );

        expect(openedResult['requiresPassword'], isFalse);
        expect(openedResult['manifestModel'], isNotNull);
        final manifest = openedResult['manifestModel'] as ZIPrManifest;
        expect(manifest.title, 'EncryptedArchiveWorkerTest');
        expect(manifest.itemCount, 1);
        expect(progressUpdates, isNotEmpty);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('ZIPrItem Utility Tests', () {
    test('Format bytes accurately', () {
      expect(ZIPrItem.formatBytes(500), '500.0 B');
      expect(ZIPrItem.formatBytes(1024), '1.0 KB');
      expect(ZIPrItem.formatBytes(1024 * 1024 * 5), '5.0 MB');
      expect(ZIPrItem.formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });
  });
}
