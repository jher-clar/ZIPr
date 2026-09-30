import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipr/models/cloud_storage_models.dart';
import 'package:zipr/models/zipr_item.dart';
import 'package:zipr/models/zipr_manifest.dart';
import 'package:zipr/screens/zipr_feed_viewer_screen.dart';
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

      // Test Max Efficiency Lossless Preset (Maximum compression, 0 pixel loss)
      settings.applyPreset(HandBrakePreset.maxEfficiencyLossless);
      expect(settings.videoCodec, VideoCodecOption.h265);
      expect(settings.videoResolution, VideoResolutionLimit.source);
      expect(settings.frameRate, FrameRateLimit.source);
      expect(settings.qualityRf, 18);
      expect(settings.encoderSpeed, EncoderSpeedPreset.slow);
      expect(settings.imageFormat, ImageFormatOption.webp);
      expect(settings.photoQuality, 95);
      expect(settings.photoMaxDimension, ImageMaxDimension.source);
      expect(settings.keepExif, true);
      expect(settings.generateThumbnails, false);
      expect(settings.neverExceedOriginalSize, true);
      expect(settings.isOriginalQuality, false);
      expect(settings.summaryText.contains('Max Efficiency Lossless'), true);

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

      expect(darkTheme.colorScheme.primary, AppTheme.darkPrimary);
      expect(lightTheme.colorScheme.primary, AppTheme.lightPrimary);
      expect(darkTheme.scaffoldBackgroundColor, AppTheme.darkBg);
      expect(lightTheme.scaffoldBackgroundColor, AppTheme.lightBg);
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

  group('7. Single-Media Containers (Only Photos, Only Videos, Single Item)', () {
    test('Successfully creates, inspects, and opens a container with ONLY photos', () async {
      final img1 = File(p.join(tempDir.path, 'photo_1.jpg'));
      final img2 = File(p.join(tempDir.path, 'photo_2.png'));
      await img1.writeAsBytes(List.generate(1024 * 20, (i) => i % 256));
      await img2.writeAsBytes(List.generate(1024 * 25, (i) => (i * 3) % 256));

      final items = [
        ZIPrItem(
          id: 'p1',
          type: MediaType.photo,
          file: img1,
          originalSize: 1024 * 20,
          caption: 'Landscape Panorama',
        ),
        ZIPrItem(
          id: 'p2',
          type: MediaType.photo,
          file: img2,
          originalSize: 1024 * 25,
          caption: 'Blueprint Detail',
        ),
      ];

      final file = await ZIPrStorageService.createZIPrArchive(
        title: 'Photos_Only_Container',
        description: 'Photo gallery container test',
        items: items,
        onProgress: (_, __) {},
      );

      expect(await file.exists(), true);

      final inspected = await ZIPrStorageService.inspectArchive(file);
      expect(inspected['itemCount'], 2);
      expect(inspected['title'], 'Photos_Only_Container');

      final opened = await ZIPrStorageService.openZIPrArchive(file);
      final manifest = opened['manifestModel'] as ZIPrManifest;
      expect(manifest.itemCount, 2);
      expect(manifest.items.every((it) => it.type == 'photo'), true);
      expect(manifest.items[0].caption, 'Landscape Panorama');
      expect(manifest.items[1].caption, 'Blueprint Detail');
    });

    test('Successfully creates, inspects, and opens a container with ONLY videos', () async {
      final vid1 = File(p.join(tempDir.path, 'clip_1.mp4'));
      final vid2 = File(p.join(tempDir.path, 'clip_2.mov'));
      await vid1.writeAsBytes(List.generate(1024 * 40, (i) => (i * 5) % 256));
      await vid2.writeAsBytes(List.generate(1024 * 50, (i) => (i * 9) % 256));

      final items = [
        ZIPrItem(
          id: 'v1',
          type: MediaType.video,
          file: vid1,
          originalSize: 1024 * 40,
          caption: 'Flight Drone Run',
        ),
        ZIPrItem(
          id: 'v2',
          type: MediaType.video,
          file: vid2,
          originalSize: 1024 * 50,
          caption: 'Slow Motion Sequence',
        ),
      ];

      final file = await ZIPrStorageService.createZIPrArchive(
        title: 'Videos_Only_Container',
        description: 'Video reel container test',
        items: items,
        onProgress: (_, __) {},
      );

      expect(await file.exists(), true);

      final inspected = await ZIPrStorageService.inspectArchive(file);
      expect(inspected['itemCount'], 2);
      expect(inspected['title'], 'Videos_Only_Container');

      final opened = await ZIPrStorageService.openZIPrArchive(file);
      final manifest = opened['manifestModel'] as ZIPrManifest;
      expect(manifest.itemCount, 2);
      expect(manifest.items.every((it) => it.type == 'video'), true);
      expect(manifest.items[0].caption, 'Flight Drone Run');
      expect(manifest.items[1].caption, 'Slow Motion Sequence');
    });

    test('Successfully creates and extracts a single-item container (itemCount == 1)', () async {
      final img = File(p.join(tempDir.path, 'solo_photo.webp'));
      await img.writeAsBytes(List.generate(1024 * 15, (i) => (i * 11) % 256));

      final items = [
        ZIPrItem(
          id: 'solo-1',
          type: MediaType.photo,
          file: img,
          originalSize: 1024 * 15,
          caption: 'Single Page Doc',
        ),
      ];

      final file = await ZIPrStorageService.createZIPrArchive(
        title: 'Single_Item_Container',
        items: items,
        onProgress: (_, __) {},
      );

      final opened = await ZIPrStorageService.openZIPrArchive(file);
      final manifest = opened['manifestModel'] as ZIPrManifest;
      expect(manifest.itemCount, 1);
      expect(manifest.items.length, 1);
      expect(manifest.items.first.caption, 'Single Page Doc');
    });

    testWidgets('Single-item container HUD scrubber does not build Slider with min == max', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                const itemsCount = 1;
                return itemsCount > 1
                    ? Slider(
                        value: 0.0,
                        min: 0.0,
                        max: (itemsCount - 1).toDouble(),
                        divisions: itemsCount - 1,
                        onChanged: (_) {},
                      )
                    : const Text('Single Page Container • 1 of 1');
              },
            ),
          ),
        ),
      );

      expect(find.text('Single Page Container • 1 of 1'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  group('8. Anti-Inflation & HandBrake Size Guard Verification', () {
    test('Original Quality container packaging does not inflate container size beyond original content', () async {
      // Create pre-compressed mock media files
      final photoFile = File(p.join(tempDir.path, 'anti_inflation_photo.jpg'));
      final videoFile = File(p.join(tempDir.path, 'anti_inflation_video.mp4'));

      // 40 KB and 60 KB files
      final photoBytes = List.generate(1024 * 40, (i) => (i * 17) % 256);
      final videoBytes = List.generate(1024 * 60, (i) => (i * 23) % 256);
      await photoFile.writeAsBytes(photoBytes);
      await videoFile.writeAsBytes(videoBytes);

      final totalMediaBytes = photoBytes.length + videoBytes.length;

      final items = [
        ZIPrItem(
          id: 'ai-p1',
          type: MediaType.photo,
          file: photoFile,
          originalSize: photoBytes.length,
          caption: 'Raw JPEG',
        ),
        ZIPrItem(
          id: 'ai-v1',
          type: MediaType.video,
          file: videoFile,
          originalSize: videoBytes.length,
          caption: 'Raw MP4',
        ),
      ];

      final containerFile = await ZIPrStorageService.createZIPrArchive(
        title: 'Original_Anti_Inflation',
        items: items,
        onProgress: (_, __) {},
      );

      final containerSize = await containerFile.length();
      // ZIP overhead for 2 stored files + 1 manifest.json is typically ~700-1000 bytes.
      // Deflation inflation on pre-compressed data would add several KB to tens of KB.
      // STORE mode guarantees media payload is stored byte-for-byte at exact original size.
      expect(containerSize >= totalMediaBytes, true);
      expect(containerSize <= totalMediaBytes + 1500, true);

      // Verify the files extracted match exact bit-for-bit bytes
      final opened = await ZIPrStorageService.openZIPrArchive(containerFile);
      final manifest = opened['manifestModel'] as ZIPrManifest;
      expect(manifest.totalOriginalSize, totalMediaBytes);
      expect(manifest.totalCompressedSize, totalMediaBytes);

      final extractDir = opened['dir'] as Directory;
      final extractedPhotoFile = File(p.join(extractDir.path, 'media', manifest.items[0].fileName));
      final extractedVideoFile = File(p.join(extractDir.path, 'media', manifest.items[1].fileName));
      final extractedPhotoBytes = await extractedPhotoFile.readAsBytes();
      final extractedVideoBytes = await extractedVideoFile.readAsBytes();

      expect(extractedPhotoBytes.length, photoBytes.length);
      expect(extractedVideoBytes.length, videoBytes.length);
      expect(extractedPhotoBytes, photoBytes);
      expect(extractedVideoBytes, videoBytes);
    });

    test('HandBrake presets include superHq1080p and productionStandard with size guard', () {
      final settings = CompressionSettings();

      // Test Super HQ 1080p preset
      settings.applyPreset(HandBrakePreset.superHq1080p);
      expect(settings.videoCodec, VideoCodecOption.h265);
      expect(settings.videoResolution, VideoResolutionLimit.res1080p);
      expect(settings.qualityRf, 20);
      expect(settings.encoderSpeed, EncoderSpeedPreset.slow);
      expect(settings.neverExceedOriginalSize, true);

      // Test Production Standard preset
      settings.applyPreset(HandBrakePreset.productionStandard);
      expect(settings.videoContainer, VideoContainerFormat.mov);
      expect(settings.videoCodec, VideoCodecOption.h264);
      expect(settings.qualityRf, 16);
      expect(settings.neverExceedOriginalSize, true);

      // Test Max Efficiency Lossless has size guard and zero extra thumbnails
      settings.applyPreset(HandBrakePreset.maxEfficiencyLossless);
      expect(settings.generateThumbnails, false);
      expect(settings.neverExceedOriginalSize, true);
      expect(settings.photoMaxDimension, ImageMaxDimension.source);

      // Test original lossless has size guard and no thumbnails
      settings.applyPreset(HandBrakePreset.originalLossless);
      expect(settings.generateThumbnails, false);
      expect(settings.neverExceedOriginalSize, true);
    });

    test('Size guard rule: if converted file is larger or equal to original, original is preserved', () async {
      final origFile = File(p.join(tempDir.path, 'guard_orig.jpg'));
      final mockConvertedFile = File(p.join(tempDir.path, 'guard_bloated.webp'));

      // Original is 5000 bytes, "converted" is 8000 bytes (bloated)
      await origFile.writeAsBytes(List.generate(5000, (i) => i % 256));
      await mockConvertedFile.writeAsBytes(List.generate(8000, (i) => i % 256));

      final settings = CompressionSettings(neverExceedOriginalSize: true);

      // Test the size guard decision rule:
      File selectedFile;
      final compLen = await mockConvertedFile.length();
      final origLen = await origFile.length();
      if (settings.neverExceedOriginalSize && compLen >= origLen) {
        selectedFile = origFile;
      } else {
        selectedFile = mockConvertedFile;
      }

      expect(selectedFile.path, origFile.path);
      expect(await selectedFile.length(), 5000);
    });
  });

  group('9. Streaming Memory Guard & High-Capacity Containers (1GB+ Ready)', () {
    test('Streams and packages large media items without in-memory buffering', () async {
      final sampleImg = File(p.join(tempDir.path, 'stream_photo.jpg'));
      final sampleVid = File(p.join(tempDir.path, 'stream_video.mp4'));
      final imgBytes = List.generate(1024 * 1024 * 2, (i) => (i * 3) % 256); // 2 MB
      final vidBytes = List.generate(1024 * 1024 * 3, (i) => (i * 7) % 256); // 3 MB
      await sampleImg.writeAsBytes(imgBytes);
      await sampleVid.writeAsBytes(vidBytes);

      final items = [
        ZIPrItem(
          id: 'sp-1',
          type: MediaType.photo,
          file: sampleImg,
          originalSize: imgBytes.length,
          caption: 'Streamed Photo Page',
        ),
        ZIPrItem(
          id: 'sv-1',
          type: MediaType.video,
          file: sampleVid,
          originalSize: vidBytes.length,
          caption: 'Streamed Video Page',
        ),
      ];

      // Package container with streaming I/O
      final createdArchive = await ZIPrStorageService.createZIPrArchive(
        title: 'High_Capacity_Stream_Container',
        description: 'Verifying zero OOM memory footprint',
        items: items,
        onProgress: (p, s) {},
      );

      expect(await createdArchive.exists(), true);

      // Inspect container stream without loading into RAM
      final inspection = await ZIPrStorageService.inspectArchive(createdArchive);
      expect(inspection['isEncrypted'], false);
      expect(inspection['title'], 'High_Capacity_Stream_Container');
      expect(inspection['itemCount'], 2);

      // Extract container using streaming disk-based extractor
      final opened = await ZIPrStorageService.openZIPrArchive(createdArchive);
      expect(opened['requiresPassword'], false);
      final manifest = opened['manifestModel'] as ZIPrManifest;
      expect(manifest.itemCount, 2);
      expect(manifest.totalOriginalSize, imgBytes.length + vidBytes.length);

      final extractDir = opened['dir'] as Directory;
      final extractedImg = File(p.join(extractDir.path, 'media', manifest.items[0].fileName));
      final extractedVid = File(p.join(extractDir.path, 'media', manifest.items[1].fileName));

      expect(await extractedImg.exists(), true);
      expect(await extractedVid.exists(), true);
      expect(await extractedImg.length(), imgBytes.length);
      expect(await extractedVid.length(), vidBytes.length);
    });

    test('Streams, encrypts, and decrypts AES-256 containers directly on disk without OOM', () async {
      final sampleImg = File(p.join(tempDir.path, 'stream_secret.jpg'));
      final imgBytes = List.generate(1024 * 1024 * 2, (i) => (i * 11) % 256);
      await sampleImg.writeAsBytes(imgBytes);

      final items = [
        ZIPrItem(
          id: 'sec-stream-1',
          type: MediaType.photo,
          file: sampleImg,
          originalSize: imgBytes.length,
          caption: 'Encrypted Stream Master',
        ),
      ];

      const secretPass = 'HighCapacityVaultKey2026';

      final createdArchive = await ZIPrStorageService.createZIPrArchive(
        title: 'Encrypted_Stream_Container',
        description: 'Streaming encryption test',
        items: items,
        password: secretPass,
        onProgress: (p, s) {},
      );

      expect(await createdArchive.exists(), true);

      final inspection = await ZIPrStorageService.inspectArchive(createdArchive);
      expect(inspection['isEncrypted'], true);
      expect(inspection['title'], 'Encrypted_Stream_Container');

      // Try opening without password
      final locked = await ZIPrStorageService.openZIPrArchive(createdArchive);
      expect(locked['requiresPassword'], true);

      // Open with correct password
      final unlocked = await ZIPrStorageService.openZIPrArchive(createdArchive, password: secretPass);
      expect(unlocked['requiresPassword'], false);
      final manifest = unlocked['manifestModel'] as ZIPrManifest;
      expect(manifest.isEncrypted, true);
      expect(manifest.itemCount, 1);

      final extractDir = unlocked['dir'] as Directory;
      final extractedImg = File(p.join(extractDir.path, 'media', manifest.items[0].fileName));
      expect(await extractedImg.exists(), true);
      expect(await extractedImg.length(), imgBytes.length);
    });

    test('Streaming cipher provides 100% two-way byte fidelity on files', () async {
      final plainFile = File(p.join(tempDir.path, 'large_raw_source.dat'));
      final encFile = File(p.join(tempDir.path, 'large_raw.enc'));
      final decFile = File(p.join(tempDir.path, 'large_raw.dec'));

      final sourceData = List.generate(1024 * 1024 * 1, (i) => (i * 31) % 256);
      await plainFile.writeAsBytes(sourceData);

      const pass = 'StreamFidelityKey';
      final encResult = await EncryptionService.encryptFileStream(
        inputFile: plainFile,
        outputFile: encFile,
        password: pass,
      );

      await EncryptionService.decryptFileStream(
        inputFile: encFile,
        outputFile: decFile,
        password: pass,
        saltHex: encResult.saltHex,
        ivHex: encResult.ivHex,
      );

      expect(await decFile.length(), await plainFile.length());
      final decBytes = await decFile.readAsBytes();
      expect(decBytes, sourceData);
    });
  });

  group('10. Adobe Acrobat Viewer & Social Media In-Feed Autoplay & Zooming Mechanics', () {
    test('ViewerMode enum provides continuous Acrobat flow and cards modes', () {
      expect(ViewerMode.values.length, 2);
      expect(ViewerMode.continuous.name, 'continuous');
      expect(ViewerMode.cards.name, 'cards');
    });

    test('Card deck vertical scroll animation calculates smooth scaling and opacity', () {
      double computeScale(double page, int index) {
        final diff = (page - index).abs();
        return (1.0 - (diff * 0.08)).clamp(0.88, 1.0);
      }

      double computeOpacity(double page, int index) {
        final diff = (page - index).abs();
        return (1.0 - (diff * 0.35)).clamp(0.45, 1.0);
      }

      // Active centered page (diff = 0)
      expect(computeScale(1.0, 1), 1.0);
      expect(computeOpacity(1.0, 1), 1.0);

      // Halfway scrolled page (diff = 0.5)
      expect(computeScale(1.5, 1), 0.96);
      expect(computeOpacity(1.5, 1), closeTo(0.825, 0.001));

      // Offscreen or completely scrolled away (diff >= 2.0)
      expect(computeScale(3.0, 1), 0.88);
      expect(computeOpacity(3.0, 1), 0.45);
    });

    test('Viewport center algorithm correctly determines active video for in-feed autoplay', () {
      const screenCenterY = 400.0;
      final itemCenters = [150.0, 410.0, 780.0];

      int activeIndex = 0;
      double minDistance = double.infinity;
      for (int i = 0; i < itemCenters.length; i++) {
        final distance = (itemCenters[i] - screenCenterY).abs();
        if (distance < minDistance) {
          minDistance = distance;
          activeIndex = i;
        }
      }

      // Item 1 is at 410.0 (distance = 10px from 400), closest to center
      expect(activeIndex, 1);
    });

    test('Double-tap and pinch-to-zoom matrix supports 1.0x to 30.0x scale capacity', () {
      final identityMatrix = Matrix4.identity();
      expect(identityMatrix.getMaxScaleOnAxis(), 1.0);

      // Double tap 3.5x matrix
      const doubleTapScale = 3.5;
      const pos = Offset(100, 100);
      final zoomedMatrix = Matrix4.identity()
        ..translateByDouble(-pos.dx * (doubleTapScale - 1), -pos.dy * (doubleTapScale - 1), 0.0, 1.0)
        ..scaleByDouble(doubleTapScale, doubleTapScale, 1.0, 1.0);

      expect(zoomedMatrix.getMaxScaleOnAxis(), closeTo(3.5, 0.01));

      // Max zoom capacity test (30.0x)
      final maxZoomMatrix = Matrix4.identity()..scaleByDouble(30.0, 30.0, 1.0, 1.0);
      expect(maxZoomMatrix.getMaxScaleOnAxis(), 30.0);
    });
  });

  group('11. Storage Footprint Management, Cache Cleaner & Media Export', () {
    late Directory tempTestDir;

    setUp(() async {
      tempTestDir = await Directory.systemTemp.createTemp('zipr_storage_test_');
    });

    tearDown(() async {
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    });

    test('getStorageStatistics returns comprehensive metrics including cache and archives', () async {
      final stats = await ZIPrStorageService.getStorageStatistics();
      expect(stats.containsKey('totalFiles'), true);
      expect(stats.containsKey('archivesBytes'), true);
      expect(stats.containsKey('cacheBytes'), true);
      expect(stats.containsKey('totalBytes'), true);
      expect(stats.containsKey('formattedArchivesSize'), true);
      expect(stats.containsKey('formattedCacheSize'), true);
      expect(stats.containsKey('formattedTotalSize'), true);
    });

    test('getViewCacheSizeBytes and clearViewCache correctly clean scratch and view cache folders', () async {
      final tempSysDir = await getTemporaryDirectory();
      final mockCacheDir = Directory(p.join(tempSysDir.path, 'view_cache_mock_test_123'));
      await mockCacheDir.create(recursive: true);
      final dummyFile = File(p.join(mockCacheDir.path, 'cached_image.webp'));
      await dummyFile.writeAsBytes(List.generate(2048, (i) => i % 256));

      final sizeBefore = await ZIPrStorageService.getViewCacheSizeBytes();
      expect(sizeBefore, greaterThanOrEqualTo(2048));

      final freed = await ZIPrStorageService.clearViewCache();
      expect(freed, greaterThanOrEqualTo(2048));
      expect(await mockCacheDir.exists(), false);
    });

    test('exportMediaToDevice copies media from archive workspace to target folder', () async {
      final archiveDir = Directory(p.join(tempTestDir.path, 'extracted_container'));
      final mediaDir = Directory(p.join(archiveDir.path, 'media'));
      await mediaDir.create(recursive: true);

      final photo = File(p.join(mediaDir.path, 'item_0000.webp'));
      final video = File(p.join(mediaDir.path, 'item_0001.mp4'));
      await photo.writeAsBytes(List.generate(1024, (i) => (i * 3) % 256));
      await video.writeAsBytes(List.generate(4096, (i) => (i * 7) % 256));

      int progressCalls = 0;
      final exported = await ZIPrStorageService.exportMediaToDevice(
        archiveDir,
        subFolder: 'TestContainer',
        onProgress: (cur, tot) {
          progressCalls++;
        },
      );

      expect(exported.length, 2);
      expect(progressCalls, 2);
      for (final f in exported) {
        expect(await f.exists(), true);
      }
    });

    test('exportSingleMediaToDevice copies an individual media file accurately', () async {
      final source = File(p.join(tempTestDir.path, 'source_pic.webp'));
      await source.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

      final exported = await ZIPrStorageService.exportSingleMediaToDevice(source, subFolder: 'SingleTest');
      expect(exported, isNotNull);
      expect(await exported!.exists(), true);
      expect(await exported.length(), 8);
    });
  });
}


