import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionStatusModel {
  final bool mediaGranted;
  final bool cameraGranted;
  final bool storageGranted;

  PermissionStatusModel({
    required this.mediaGranted,
    required this.cameraGranted,
    required this.storageGranted,
  });

  bool get allEssentialGranted => (mediaGranted || storageGranted) && cameraGranted;
}

class PermissionService {
  static const String _prefKey = 'zipr_permissions_granted_v1';

  /// Checks current live permission status
  static Future<PermissionStatusModel> checkStatus() async {
    if (kIsWeb) {
      return PermissionStatusModel(
        mediaGranted: true,
        cameraGranted: true,
        storageGranted: true,
      );
    }

    bool media = false;
    bool camera = false;
    bool storage = false;

    try {
      if (Platform.isAndroid) {
        // Photos & Videos permission for Android 13+ (API 33+)
        final photoStatus = await Permission.photos.status;
        final videoStatus = await Permission.videos.status;
        final storageStatus = await Permission.storage.status;
        final manageStatus = await Permission.manageExternalStorage.status;

        media = photoStatus.isGranted || videoStatus.isGranted || storageStatus.isGranted;
        storage = manageStatus.isGranted || storageStatus.isGranted;
        camera = (await Permission.camera.status).isGranted;
      } else if (Platform.isIOS) {
        final photoStatus = await Permission.photos.status;
        media = photoStatus.isGranted || photoStatus.isLimited;
        camera = (await Permission.camera.status).isGranted;
        storage = true;
      } else {
        media = true;
        camera = true;
        storage = true;
      }
    } catch (e) {
      debugPrint('Permission status check error: $e');
    }

    return PermissionStatusModel(
      mediaGranted: media,
      cameraGranted: camera,
      storageGranted: storage,
    );
  }

  /// Checks if user has already granted all essential permissions in past sessions
  static Future<bool> hasCompletedSetup() async {
    try {
      final status = await checkStatus();
      if (status.allEssentialGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKey, true);
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request all essential permissions
  static Future<PermissionStatusModel> requestAllPermissions() async {
    if (kIsWeb) {
      return PermissionStatusModel(
        mediaGranted: true,
        cameraGranted: true,
        storageGranted: true,
      );
    }

    try {
      if (Platform.isAndroid) {
        // 1. Request Media / Storage
        await [
          Permission.photos,
          Permission.videos,
          Permission.storage,
          Permission.camera,
        ].request();

        // 2. If Android 11+ and manageExternalStorage is available, request it
        try {
          if (await Permission.manageExternalStorage.isDenied) {
            await Permission.manageExternalStorage.request();
          }
        } catch (_) {}
      } else if (Platform.isIOS) {
        await [
          Permission.photos,
          Permission.camera,
        ].request();
      }

      final current = await checkStatus();
      if (current.allEssentialGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKey, true);
      }
      return current;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return await checkStatus();
    }
  }

  /// Marks setup as completed manually
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Opens system app settings if permanently denied
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
