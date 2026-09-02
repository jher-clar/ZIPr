import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipr/models/cloud_storage_models.dart';
import 'package:zipr/models/zipr_item.dart';
import 'package:zipr/models/zipr_manifest.dart';
import 'package:zipr/services/encryption_service.dart';
import 'package:zipr/services/zipr_storage_service.dart';
import 'package:zipr/theme/app_theme.dart';
import 'package:zipr/theme/theme_manager.dart';
import 'package:zipr/widgets/compression_settings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zipr_unit_test_');

    // Mock path_provider platform channel for headless unit tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1. ZIPr Manifest Serialization & Logic', () {
    test('Correctly serializes and deserializes manifest with compression metrics', () {
      final now = DateTime.now();
      final manifest = ZIPrManifest(
        title: 'Q3 Architectural Plan',
        description: 'Blueprints and video render walkthrough',
        createdAt: now,
        author: 'Lead Architect',
        isEncrypted: true,
        itemCount: 2,
        totalOriginalSize: 20000000,
        totalCompressedSize: 6000000,
        items: [
          ZIPrManifestItem(
            index: 0,
            id: 'item-001',
            fileName: 'item_0000.webp',
            type: 'photo',
            caption: 'Main Building Elevation',
            originalSize: 10000000,
            compressedSize: 3000000,
          ),
          ZIPrManifestItem(
            index: 1,
            id: 'item-002',
            fileName: 'item_0001.mp4',
            type: 'video',
            caption: 'Drone 3D Flythrough',
            originalSize: 10000000,
            compressedSize: 3000000,
          ),
        ],
      );

      final jsonMap = manifest.toJson();
      final decoded = ZIPrManifest.fromJson(jsonMap);

      expect(decoded.title, 'Q3 Architectural Plan');
      expect(decoded.description, 'Blueprints and video render walkthrough');
      expect(decoded.isEncrypted, true);
      expect(decoded.itemCount, 2);
      expect(decoded.items.length, 2);
      expect(decoded.items[0].caption, 'Main Building Elevation');
      expect(decoded.items[1].caption, 'Drone 3D Flythrough');
      expect(decoded.totalSavingsRatio, closeTo(70.0, 0.1));
    });
  });

  group('2. AES-256-GCM Encryption Engine', () {
    test('Encrypts and decrypts payload data with PBKDF2 key derivation', () {
      const sensitiveText = 'ZIPr Top Secret Project Data 2026 - Confidential';
      final plainBytes = Uint8List.fromList(utf8.encode(sensitiveText));
      const testPassword = 'P@ssw0rd_Enterprise_2026!';

      final encResult = EncryptionService.encryptBytes(plainBytes, testPassword);

      expect(encResult.cipherBytes, isNotEmpty);
      expect(encResult.saltHex, isNotEmpty);
      expect(encResult.ivHex, isNotEmpty);

      // Verify decrypted data matches exactly
      final decryptedBytes = EncryptionService.decryptBytes(
        cipherBytes: encResult.cipherBytes,
        password: testPassword,
        saltHex: encResult.saltHex,
        ivHex: encResult.ivHex,
      );

      final decryptedText = utf8.decode(decryptedBytes);
      expect(decryptedText, sensitiveText);
    });

    test('Throws FormatException on invalid password decryption attempt', () {
      final plainBytes = Uint8List.fromList(utf8.encode('Protected document stream'));
      final encResult = EncryptionService.encryptBytes(plainBytes, 'CorrectKey123');

      expect(
        () => EncryptionService.decryptBytes(
          cipherBytes: encResult.cipherBytes,
          password: 'IncorrectKey999',
          saltHex: encResult.saltHex,
          ivHex: encResult.ivHex,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('3. ZIPr Utility & Storage Formatters', () {
    test('Format bytes accurately across all magnitude scales', () {
      expect(ZIPrItem.formatBytes(0), '0 B');
      expect(ZIPrItem.formatBytes(750), '750.0 B');
      expect(ZIPrItem.formatBytes(1024), '1.0 KB');
      expect(ZIPrItem.formatBytes(1024 * 1024 * 15), '15.0 MB');
      expect(ZIPrItem.formatBytes(1024 * 1024 * 1024 * 3), '3.0 GB');
    });

    test('CompressionSettings defaults to lossless Original Quality mode', () {
      final defaultSettings = CompressionSettings();
      expect(defaultSettings.isOriginalQuality, true);
    });

    test('HandBrake presets configure video codecs, resolutions, and quality accurately', () {
      final settings = CompressionSettings();

      // Test Fast 1080p30 Preset
      settings.applyPreset(HandBrakePreset.fast1080p30);
      expect(settings.videoCodec, VideoCodecOption.h264);
      expect(settings.videoResolution, VideoResolutionLimit.res1080p);
      expect(settings.qualityRf, 22);
      expect(settings.imageFormat, ImageFormatOption.webp);
      expect(settings.photoQuality, 85);
      expect(settings.isOriginalQuality, false);

      // Test HQ 4K HEVC Preset
      settings.applyPreset(HandBrakePreset.hq4kHevc);
      expect(settings.videoCodec, VideoCodecOption.h265);
      expect(settings.videoResolution, VideoResolutionLimit.res4k);
      expect(settings.qualityRf, 18);
      expect(settings.videoContainer, VideoContainerFormat.mkv);

      // Test Master Lossless Preset
      settings.applyPreset(HandBrakePreset.originalLossless);
      expect(settings.isOriginalQuality, true);
      expect(settings.videoCodec, VideoCodecOption.passthrough);
      expect(settings.imageFormat, ImageFormatOption.passthrough);
    });

    test('Two-finger swipe zoom calculation properly amplifies up to max capacity', () {
      const initialScale = 1.0;
      const swipeUpDeltaY = -25.0; // Two fingers swiping UP
      final swipeFactor = 1.0 - (swipeUpDeltaY * 0.008);
      const pinchScale = 1.2;
      final stepScale = pinchScale * swipeFactor;
      final newScale = (initialScale * stepScale).clamp(1.0, 30.0);

      expect(newScale, greaterThan(1.2));
      expect(newScale, lessThanOrEqualTo(30.0));

      // Test extreme swipe up hits maximum capacity clamp
      final maxScale = (10.0 * 5.0).clamp(1.0, 30.0);
      expect(maxScale, 30.0);
    });
  });

  group('4. End-to-End Container Packaging & Inspection Mechanism', () {
    test('Creates, inspects, and extracts unencrypted .zipr archive on disk without manifest errors', () async {
      final sampleImg = File(p.join(tempDir.path, 'sample_photo.jpg'));
      await sampleImg.writeAsBytes(List.generate(1024 * 50, (i) => i % 256));

      final items = [
        ZIPrItem(
          id: 'mock-1',
          type: MediaType.photo,
          file: sampleImg,
          originalSize: 1024 * 50,
          caption: 'Test Photo Page 1',
        ),
      ];

      // Package container
      final createdFile = await ZIPrStorageService.createZIPrArchive(
        title: 'Test_Unencrypted_Container',
        description: 'E2E Testing',
        items: items,
        onProgress: (progress, status) {},
      );

      expect(await createdFile.exists(), true);
      expect(createdFile.path.endsWith('.zipr'), true);

      // Inspect container
      final info = await ZIPrStorageService.inspectArchive(createdFile);
      expect(info['isEncrypted'], false);
      expect(info['title'], 'Test_Unencrypted_Container');
      expect(info['itemCount'], 1);

      // Open and extract container
      final opened = await ZIPrStorageService.openZIPrArchive(createdFile);
      expect(opened['requiresPassword'], false);
      final manifest = opened['manifestModel'] as ZIPrManifest;
      expect(manifest.title, 'Test_Unencrypted_Container');
      expect(manifest.items.length, 1);
      expect(manifest.items[0].caption, 'Test Photo Page 1');

      // Verify extracted manifest.json on disk
      final extractedDir = opened['dir'] as Directory;
      final extractedManifest = File(p.join(extractedDir.path, 'manifest.json'));
      expect(await extractedManifest.exists(), true);
    });

    test('Creates, inspects, and decrypts AES-256 encrypted .zipr container on disk', () async {
      final sampleImg = File(p.join(tempDir.path, 'classified_photo.png'));
      await sampleImg.writeAsBytes(List.generate(1024 * 30, (i) => (i * 7) % 256));

      final items = [
        ZIPrItem(
          id: 'sec-1',
          type: MediaType.photo,
          file: sampleImg,
          originalSize: 1024 * 30,
          caption: 'Classified Page 1',
        ),
      ];

      const pass = 'VaultKey_2026!';

      // Package encrypted container
      final encFile = await ZIPrStorageService.createZIPrArchive(
        title: 'Classified_Vault_Doc',
        description: 'Secure AES Archive',
        items: items,
        password: pass,
        onProgress: (progress, status) {},
      );

      expect(await encFile.exists(), true);

      // Inspect container
      final info = await ZIPrStorageService.inspectArchive(encFile);
      expect(info['isEncrypted'], true);
      expect(info['title'], 'Classified_Vault_Doc');
      expect(info['itemCount'], 1);

      // Open without password -> prompts requiresPassword
      final locked = await ZIPrStorageService.openZIPrArchive(encFile);
      expect(locked['requiresPassword'], true);

      // Open with correct password -> decrypts successfully
      final unlocked = await ZIPrStorageService.openZIPrArchive(encFile, password: pass);
      expect(unlocked['requiresPassword'], false);
      final manifest = unlocked['manifestModel'] as ZIPrManifest;
      expect(manifest.title, 'Classified_Vault_Doc');
      expect(manifest.items[0].caption, 'Classified Page 1');

      // Verify extracted files exist
      final extractedDir = unlocked['dir'] as Directory;
      final extractedManifest = File(p.join(extractedDir.path, 'manifest.json'));
      expect(await extractedManifest.exists(), true);
    });
  });

  group('5. Cloud Storage Vault & Multi-Provider Sync Engine', () {
    test('CloudAccount properly calculates storage percentages and serializes JSON', () {
      final account = CloudAccount(
        id: 'acc_gdrive_test',
        provider: CloudProvider.gdrive,
        emailOrUser: 'test.user@vault.cloud',
        accountName: 'Google Drive Pro',
        usedBytes: 25 * 1024 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024 * 1024,
      );

      expect(account.usedPercentage, closeTo(0.25, 0.01));
      final jsonMap = account.toJson();
      final decoded = CloudAccount.fromJson(jsonMap);
      expect(decoded.emailOrUser, 'test.user@vault.cloud');
      expect(decoded.provider, CloudProvider.gdrive);
    });

    test('CloudFileItem formats byte sizes and parses provider attributes', () {
      final item = CloudFileItem(
        id: 'cf_001',
        name: 'Mega_Vault_Q3.zipr',
        provider: CloudProvider.mega,
        sizeBytes: 1024 * 1024 * 35, // 35 MB
        modifiedDate: DateTime.now(),
        isEncrypted: true,
        itemCount: 12,
        downloadUrl: 'https://mega.nz/file/mock123',
      );

      expect(item.formattedSize, '35.0 MB');
      expect(item.provider, CloudProvider.mega);
      expect(item.isEncrypted, true);

      final json = item.toJson();
      final decoded = CloudFileItem.fromJson(json);
      expect(decoded.name, 'Mega_Vault_Q3.zipr');
      expect(decoded.itemCount, 12);
    });
  });

  group('6. Theme Engine & Multi-Appearance Mechanism', () {
    test('AppTheme defines consistent Dark and Light color schemes', () {
      final darkTheme = AppTheme.darkTheme;
      final lightTheme = AppTheme.lightTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(lightTheme.brightness, Brightness.light);

      expect(darkTheme.colorScheme.primary, const Color(0xFF38BDF8));
      expect(lightTheme.colorScheme.primary, const Color(0xFF0284C7));
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF080B11));
      expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
    });

    test('ThemeManager persists and broadcasts ThemeMode changes', () async {
      SharedPreferences.setMockInitialValues({});
      final tm = ThemeManager.instance;
      await tm.init();

      expect(tm.themeModeNotifier.value, ThemeMode.system);

      await tm.setThemeMode(ThemeMode.dark);
      expect(tm.themeModeNotifier.value, ThemeMode.dark);

      await tm.setThemeMode(ThemeMode.light);
      expect(tm.themeModeNotifier.value, ThemeMode.light);

      await tm.setThemeMode(ThemeMode.system);
      expect(tm.themeModeNotifier.value, ThemeMode.system);
    });
  });
}
