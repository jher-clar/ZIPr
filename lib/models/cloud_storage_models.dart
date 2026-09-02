import 'package:flutter/material.dart';

enum CloudProvider {
  gdrive('Google Drive', 'gdrive', Color(0xFF4285F4), Icons.add_to_drive_rounded, 'Cloud backup & team drive'),
  mega('MEGA.nz', 'mega', Color(0xFFD9272E), Icons.lock_rounded, 'Zero-knowledge encrypted cloud'),
  onedrive('OneDrive / OneCloud', 'onedrive', Color(0xFF0078D4), Icons.cloud_circle_rounded, 'Microsoft cloud vault'),
  megadrive('MegaDrive / WebDAV', 'megadrive', Color(0xFFA855F7), Icons.dns_rounded, 'Custom self-hosted WebDAV cloud'),
  directUrl('Direct Cloud Link', 'directUrl', Color(0xFF10B981), Icons.link_rounded, 'Import from any public/shared link');

  final String displayName;
  final String keyName;
  final Color brandColor;
  final IconData icon;
  final String subtitle;
  const CloudProvider(this.displayName, this.keyName, this.brandColor, this.icon, this.subtitle);
}

class CloudAccount {
  final String id;
  final CloudProvider provider;
  final String emailOrUser;
  final String accountName;
  final bool isConnected;
  final int usedBytes;
  final int totalBytes;
  final String? serverEndpoint;
  final String? authToken;
  final DateTime connectedAt;

  CloudAccount({
    required this.id,
    required this.provider,
    required this.emailOrUser,
    required this.accountName,
    this.isConnected = true,
    this.usedBytes = 0,
    this.totalBytes = 100 * 1024 * 1024 * 1024, // 100 GB default
    this.serverEndpoint,
    this.authToken,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  double get usedPercentage => totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.keyName,
        'emailOrUser': emailOrUser,
        'accountName': accountName,
        'isConnected': isConnected,
        'usedBytes': usedBytes,
        'totalBytes': totalBytes,
        'serverEndpoint': serverEndpoint,
        'authToken': authToken,
        'connectedAt': connectedAt.toIso8601String(),
      };

  factory CloudAccount.fromJson(Map<String, dynamic> json) {
    final provKey = json['provider'] as String? ?? 'gdrive';
    final provider = CloudProvider.values.firstWhere(
      (p) => p.keyName == provKey,
      orElse: () => CloudProvider.gdrive,
    );

    return CloudAccount(
      id: json['id'] as String? ?? 'acc_default',
      provider: provider,
      emailOrUser: json['emailOrUser'] as String? ?? 'user@cloud.vault',
      accountName: json['accountName'] as String? ?? provider.displayName,
      isConnected: json['isConnected'] as bool? ?? true,
      usedBytes: json['usedBytes'] as int? ?? 15 * 1024 * 1024 * 1024,
      totalBytes: json['totalBytes'] as int? ?? 100 * 1024 * 1024 * 1024,
      serverEndpoint: json['serverEndpoint'] as String?,
      authToken: json['authToken'] as String?,
      connectedAt: json['connectedAt'] != null
          ? DateTime.tryParse(json['connectedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CloudFileItem {
  final String id;
  final String name;
  final CloudProvider provider;
  final int sizeBytes;
  final DateTime modifiedDate;
  final bool isEncrypted;
  final int itemCount;
  final String downloadUrl;
  final String? remotePath;
  final String? localCachedPath;

  CloudFileItem({
    required this.id,
    required this.name,
    required this.provider,
    required this.sizeBytes,
    required this.modifiedDate,
    this.isEncrypted = false,
    this.itemCount = 0,
    required this.downloadUrl,
    this.remotePath,
    this.localCachedPath,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double s = sizeBytes.toDouble();
    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider.keyName,
        'sizeBytes': sizeBytes,
        'modifiedDate': modifiedDate.toIso8601String(),
        'isEncrypted': isEncrypted,
        'itemCount': itemCount,
        'downloadUrl': downloadUrl,
        'remotePath': remotePath,
        'localCachedPath': localCachedPath,
      };

  factory CloudFileItem.fromJson(Map<String, dynamic> json) {
    final provKey = json['provider'] as String? ?? 'gdrive';
    final provider = CloudProvider.values.firstWhere(
      (p) => p.keyName == provKey,
      orElse: () => CloudProvider.gdrive,
    );

    return CloudFileItem(
      id: json['id'] as String? ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Document.zipr',
      provider: provider,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      modifiedDate: json['modifiedDate'] != null
          ? DateTime.tryParse(json['modifiedDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      itemCount: json['itemCount'] as int? ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      remotePath: json['remotePath'] as String?,
      localCachedPath: json['localCachedPath'] as String?,
    );
  }
}
