import 'dart:convert';

class ZIPrManifest {
  final String version;
  final String title;
  final String description;
  final DateTime createdAt;
  final String author;
  final bool isEncrypted;
  final String? saltHex;
  final String? ivHex;
  final int itemCount;
  final int totalOriginalSize;
  final int totalCompressedSize;
  final List<ZIPrManifestItem> items;

  ZIPrManifest({
    this.version = '1.0',
    required this.title,
    this.description = '',
    required this.createdAt,
    this.author = 'ZIPr User',
    this.isEncrypted = false,
    this.saltHex,
    this.ivHex,
    required this.itemCount,
    this.totalOriginalSize = 0,
    this.totalCompressedSize = 0,
    required this.items,
  });

  double get totalSavingsRatio {
    if (totalOriginalSize <= 0 || totalCompressedSize >= totalOriginalSize) return 0.0;
    return (1.0 - (totalCompressedSize / totalOriginalSize)) * 100.0;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'author': author,
        'isEncrypted': isEncrypted,
        if (saltHex != null) 'saltHex': saltHex,
        if (ivHex != null) 'ivHex': ivHex,
        'itemCount': itemCount,
        'totalOriginalSize': totalOriginalSize,
        'totalCompressedSize': totalCompressedSize,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory ZIPrManifest.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ZIPrManifest(
      version: json['version'] as String? ?? '1.0',
      title: json['title'] as String? ?? 'Untitled ZIPr',
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      author: json['author'] as String? ?? 'ZIPr User',
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      saltHex: json['saltHex'] as String?,
      ivHex: json['ivHex'] as String?,
      itemCount: json['itemCount'] as int? ?? rawItems.length,
      totalOriginalSize: json['totalOriginalSize'] as int? ?? 0,
      totalCompressedSize: json['totalCompressedSize'] as int? ?? 0,
      items: rawItems.map((e) => ZIPrManifestItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  String encodeJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class ZIPrManifestItem {
  final int index;
  final String id;
  final String fileName;
  final String type; // 'photo' | 'video'
  final String caption;
  final List<String> tags;
  final int originalSize;
  final int compressedSize;
  final int? width;
  final int? height;
  final int? durationMs;

  ZIPrManifestItem({
    required this.index,
    required this.id,
    required this.fileName,
    required this.type,
    this.caption = '',
    List<String>? tags,
    this.originalSize = 0,
    this.compressedSize = 0,
    this.width,
    this.height,
    this.durationMs,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
        'index': index,
        'id': id,
        'fileName': fileName,
        'type': type,
        'caption': caption,
        'tags': tags,
        'originalSize': originalSize,
        'compressedSize': compressedSize,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory ZIPrManifestItem.fromJson(Map<String, dynamic> json) {
    return ZIPrManifestItem(
      index: json['index'] as int? ?? 0,
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      type: json['type'] as String? ?? 'photo',
      caption: json['caption'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      originalSize: json['originalSize'] as int? ?? 0,
      compressedSize: json['compressedSize'] as int? ?? 0,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['durationMs'] as int?,
    );
  }
}
