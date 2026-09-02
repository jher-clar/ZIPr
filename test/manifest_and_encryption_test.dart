import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zipr/models/zipr_item.dart';
import 'package:zipr/models/zipr_manifest.dart';
import 'package:zipr/services/encryption_service.dart';

void main() {
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
