import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/zipr_item.dart';
import '../models/zipr_manifest.dart';
import 'encryption_service.dart';

class ZIPrStorageService {
  static const String appFolderName = 'ZIPr';

  /// Ensures necessary storage permissions are requested safely
  static Future<bool> requestStoragePermissions() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid) {
        if (await Permission.photos.isGranted || await Permission.videos.isGranted) return true;
        if (await Permission.storage.isGranted) return true;
      }
    } catch (e) {
      debugPrint('Safe permission check: $e');
    }
    return true;
  }

  /// Gets or creates the dedicated ZIPr directory on device storage
  static Future<Directory> getDedicatedAppFolder() async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      // 1. If MANAGE_EXTERNAL_STORAGE is granted, use public Documents/ZIPr
      try {
        if (await Permission.manageExternalStorage.isGranted) {
          final publicDocs = Directory('/storage/emulated/0/Documents');
          if (await publicDocs.exists()) {
            final testDir = Directory(p.join(publicDocs.path, appFolderName));
            if (!await testDir.exists()) {
              await testDir.create(recursive: true);
            }
            return testDir;
          }
        }
      } catch (_) {}

      // 2. Safe app-specific external storage (Guaranteed read/write access without special permissions on Android 11-16)
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final ziprDir = Directory(p.join(extDir.path, appFolderName));
          if (!await ziprDir.exists()) {
            await ziprDir.create(recursive: true);
          }
          return ziprDir;
        }
      } catch (_) {}

      // 3. App Documents fallback
      try {
        baseDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        baseDir = Directory.systemTemp;
      }
    } else {
      // iOS / Desktop Documents folder
      baseDir = await getApplicationDocumentsDirectory();
    }

    final ziprDir = Directory(p.join(baseDir.path, appFolderName));
    if (!await ziprDir.exists()) {
      await ziprDir.create(recursive: true);
    }
    return ziprDir;
  }

  /// Lists all saved .zipr documents in the dedicated folder
  static Future<List<File>> listZIPrFiles() async {
    try {
      final dir = await getDedicatedAppFolder();
      if (!await dir.exists()) return [];

      final entities = dir.listSync();
      final files = entities.whereType<File>().where((e) => e.path.toLowerCase().endsWith('.zipr')).toList();

      files.sort((a, b) {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          return 0;
        }
      });
      return files;
    } catch (e) {
      debugPrint('Error listing ZIPr files: $e');
      return [];
    }
  }

  /// Quick inspection of a .zipr file without fully extracting it
  static Future<Map<String, dynamic>> inspectArchive(File ziprFile) async {
    try {
      final bytes = await ziprFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Check for header.json (encrypted container)
      ArchiveFile? headerFile;
      for (final f in archive.files) {
        final name = f.name.replaceAll('\\', '/').toLowerCase();
        if (name == 'header.json' || name.endsWith('/header.json')) {
          headerFile = f;
          break;
        }
      }

      if (headerFile != null) {
        final headerData = jsonDecode(utf8.decode(headerFile.content as List<int>));
        if (headerData['isEncrypted'] == true) {
          return {
            'isEncrypted': true,
            'title': headerData['title'] ?? p.basenameWithoutExtension(ziprFile.path),
            'itemCount': headerData['itemCount'] ?? 0,
            'createdAt': headerData['createdAt'] != null
                ? DateTime.tryParse(headerData['createdAt'])
                : ziprFile.statSync().modified,
            'version': headerData['version'] ?? '1.0',
          };
        }
      }

      // Check for manifest.json (standard unencrypted container)
      ArchiveFile? manifestFile;
      for (final f in archive.files) {
        final name = f.name.replaceAll('\\', '/').toLowerCase();
        if (name == 'manifest.json' || name.endsWith('/manifest.json')) {
          manifestFile = f;
          break;
        }
      }

      if (manifestFile != null) {
        final manifestData = jsonDecode(utf8.decode(manifestFile.content as List<int>));
        return {
          'isEncrypted': false,
          'title': manifestData['title'] ?? p.basenameWithoutExtension(ziprFile.path),
          'itemCount': manifestData['itemCount'] ?? 0,
          'createdAt': manifestData['createdAt'] != null
              ? DateTime.tryParse(manifestData['createdAt'])
              : ziprFile.statSync().modified,
          'version': manifestData['version'] ?? '1.0',
        };
      }
    } catch (e) {
      debugPrint('Error inspecting archive: $e');
    }

    return {
      'isEncrypted': false,
      'title': p.basenameWithoutExtension(ziprFile.path),
      'itemCount': 0,
      'createdAt': ziprFile.statSync().modified,
      'version': '1.0',
    };
  }

  /// Packages items into a .zipr archive file with optional AES-256 encryption
  static Future<File> createZIPrArchive({
    required String title,
    String description = '',
    required List<ZIPrItem> items,
    String? password,
    required Function(double progress, String status) onProgress,
  }) async {
    try {
      final manifestItems = <ZIPrManifestItem>[];
      final innerArchive = Archive();

      int totalOrigSize = 0;
      int totalCompSize = 0;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final sourceFile = item.activeFile;

        // Preserve original extension or format
        String ext = p.extension(sourceFile.path).toLowerCase();
        if (ext.isEmpty) {
          ext = item.type == MediaType.photo ? '.webp' : '.mp4';
        }

        final fileName = 'item_${i.toString().padLeft(4, '0')}$ext';
        final fileBytes = await sourceFile.readAsBytes();
        final compSize = fileBytes.length;
        final origSize = item.originalSize > 0 ? item.originalSize : compSize;

        totalOrigSize += origSize;
        totalCompSize += compSize;

        // Add media file to archive with standard forward slashes
        innerArchive.addFile(ArchiveFile('media/$fileName', fileBytes.length, fileBytes));

        // Add thumbnail if present
        if (item.thumbnailFile != null && await item.thumbnailFile!.exists()) {
          final thumbBytes = await item.thumbnailFile!.readAsBytes();
          final thumbName = 'thumb_${i.toString().padLeft(4, '0')}.jpg';
          innerArchive.addFile(ArchiveFile('thumbs/$thumbName', thumbBytes.length, thumbBytes));
        }

        manifestItems.add(ZIPrManifestItem(
          index: i,
          id: item.id,
          fileName: fileName,
          type: item.type.name,
          caption: item.caption,
          tags: item.tags,
          originalSize: origSize,
          compressedSize: compSize,
          width: item.width,
          height: item.height,
          durationMs: item.duration?.inMilliseconds,
        ));

        onProgress((i + 1) / items.length * 0.5, 'Packaging item ${i + 1}/${items.length}...');
      }

      final isEncrypted = password != null && password.trim().isNotEmpty;

      // Create manifest model
      final manifest = ZIPrManifest(
        title: title,
        description: description,
        createdAt: DateTime.now(),
        isEncrypted: isEncrypted,
        itemCount: items.length,
        totalOriginalSize: totalOrigSize,
        totalCompressedSize: totalCompSize,
        items: manifestItems,
      );

      final manifestJsonBytes = utf8.encode(manifest.encodeJson());
      innerArchive.addFile(ArchiveFile('manifest.json', manifestJsonBytes.length, manifestJsonBytes));

      onProgress(0.7, 'Compiling container...');

      final innerZipBytes = ZipEncoder().encode(innerArchive);
      final ziprFolder = await getDedicatedAppFolder();
      final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      final finalFileName = sanitizedTitle.isEmpty ? 'Document_${DateTime.now().millisecondsSinceEpoch}' : sanitizedTitle;
      final outZipPath = p.join(ziprFolder.path, '$finalFileName.zipr');

      if (isEncrypted) {
        onProgress(0.85, 'Applying AES-256 Encryption...');
        final encResult = EncryptionService.encryptBytes(
          Uint8List.fromList(innerZipBytes),
          password.trim(),
        );

        final outerArchive = Archive();
        final headerJson = jsonEncode({
          'version': '1.0',
          'isEncrypted': true,
          'title': title,
          'description': description,
          'createdAt': DateTime.now().toIso8601String(),
          'itemCount': items.length,
          'saltHex': encResult.saltHex,
          'ivHex': encResult.ivHex,
        });

        final headerBytes = utf8.encode(headerJson);
        outerArchive.addFile(ArchiveFile('header.json', headerBytes.length, headerBytes));
        outerArchive.addFile(ArchiveFile('payload.enc', encResult.cipherBytes.length, encResult.cipherBytes));

        final outerZipBytes = ZipEncoder().encode(outerArchive);
        await File(outZipPath).writeAsBytes(outerZipBytes, flush: true);
      } else {
        // Write standard .zipr container directly
        await File(outZipPath).writeAsBytes(innerZipBytes, flush: true);
      }

      onProgress(1.0, 'Finished saving to ZIPr folder!');
      return File(outZipPath);
    } catch (e) {
      debugPrint('Error creating ZIPr archive: $e');
      rethrow;
    }
  }

  /// Opens and extracts a .zipr archive into a temporary viewing workspace
  static Future<Map<String, dynamic>> openZIPrArchive(
    File ziprFile, {
    String? password,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory(p.join(
      tempDir.path,
      'view_${p.basenameWithoutExtension(ziprFile.path)}_${DateTime.now().millisecondsSinceEpoch}',
    ));

    if (await extractDir.exists()) {
      await extractDir.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    final bytes = await ziprFile.readAsBytes();
    final outerArchive = ZipDecoder().decodeBytes(bytes);

    // Look for header.json
    ArchiveFile? headerFile;
    for (final f in outerArchive.files) {
      final name = f.name.replaceAll('\\', '/').toLowerCase();
      if (name == 'header.json' || name.endsWith('/header.json')) {
        headerFile = f;
        break;
      }
    }

    Archive targetArchive;

    if (headerFile != null) {
      final headerJson = jsonDecode(utf8.decode(headerFile.content as List<int>));
      if (headerJson['isEncrypted'] == true) {
        if (password == null || password.isEmpty) {
          return {
            'requiresPassword': true,
            'title': headerJson['title'] ?? p.basenameWithoutExtension(ziprFile.path),
            'itemCount': headerJson['itemCount'] ?? 0,
          };
        }

        ArchiveFile? payloadFile;
        for (final f in outerArchive.files) {
          final name = f.name.replaceAll('\\', '/').toLowerCase();
          if (name == 'payload.enc' || name.endsWith('/payload.enc')) {
            payloadFile = f;
            break;
          }
        }

        if (payloadFile == null) {
          throw const FormatException('Corrupted encrypted archive: missing payload.enc');
        }

        final cipherBytes = Uint8List.fromList(payloadFile.content as List<int>);
        final decryptedBytes = EncryptionService.decryptBytes(
          cipherBytes: cipherBytes,
          password: password,
          saltHex: headerJson['saltHex'],
          ivHex: headerJson['ivHex'],
        );

        targetArchive = ZipDecoder().decodeBytes(decryptedBytes);
      } else {
        targetArchive = outerArchive;
      }
    } else {
      targetArchive = outerArchive;
    }

    // Extract all files safely with directory creation
    for (final file in targetArchive.files) {
      final cleanName = file.name.replaceAll('\\', '/').replaceAll(RegExp(r'^[./\\]+'), '');
      if (cleanName.isEmpty) continue;

      final fullPath = p.join(extractDir.path, cleanName);
      if (file.isFile) {
        final outFile = File(fullPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        final outDir = Directory(fullPath);
        await outDir.create(recursive: true);
      }
    }

    // Find and read manifest.json
    ArchiveFile? manifestArchiveFile;
    for (final f in targetArchive.files) {
      final name = f.name.replaceAll('\\', '/').toLowerCase();
      if (name == 'manifest.json' || name.endsWith('/manifest.json')) {
        manifestArchiveFile = f;
        break;
      }
    }

    Map<String, dynamic> manifestData;
    final manifestFile = File(p.join(extractDir.path, 'manifest.json'));

    if (manifestArchiveFile != null) {
      manifestData = jsonDecode(utf8.decode(manifestArchiveFile.content as List<int>));
      // Ensure file exists on disk
      if (!await manifestFile.exists()) {
        await manifestFile.parent.create(recursive: true);
        await manifestFile.writeAsString(jsonEncode(manifestData), flush: true);
      }
    } else if (await manifestFile.exists()) {
      manifestData = jsonDecode(await manifestFile.readAsString());
    } else {
      throw const FormatException('Invalid ZIPr archive: manifest.json not found.');
    }

    final manifest = ZIPrManifest.fromJson(manifestData);

    return {
      'requiresPassword': false,
      'dir': extractDir,
      'manifest': manifestData,
      'manifestModel': manifest,
    };
  }

  /// Calculates total device storage usage by ZIPr
  static Future<Map<String, dynamic>> getStorageStatistics() async {
    final files = await listZIPrFiles();
    int totalBytes = 0;
    for (final f in files) {
      try {
        totalBytes += f.lengthSync();
      } catch (_) {}
    }
    return {
      'totalFiles': files.length,
      'totalBytes': totalBytes,
      'formattedSize': ZIPrItem.formatBytes(totalBytes),
    };
  }
}
