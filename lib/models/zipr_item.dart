import 'dart:io';

enum MediaType { photo, video }

class ZIPrItem {
  final String id;
  final MediaType type;
  final File file;
  File? compressedFile;
  File? thumbnailFile;
  String caption;
  List<String> tags;
  int originalSize;
  int compressedSize;
  int? width;
  int? height;
  Duration? duration;

  ZIPrItem({
    required this.id,
    required this.type,
    required this.file,
    this.compressedFile,
    this.thumbnailFile,
    this.caption = '',
    List<String>? tags,
    this.originalSize = 0,
    this.compressedSize = 0,
    this.width,
    this.height,
    this.duration,
  }) : tags = tags ?? [];

  /// File currently used for display or packaging (compressed if ready, else original)
  File get activeFile => compressedFile ?? file;

  /// Human-readable original size
  String get formattedOriginalSize => formatBytes(originalSize);

  /// Human-readable compressed size
  String get formattedCompressedSize =>
      formatBytes(compressedSize > 0 ? compressedSize : (compressedFile?.lengthSync() ?? originalSize));

  /// Calculate savings percentage
  double get savingsRatio {
    final comp = compressedSize > 0 ? compressedSize : (compressedFile?.lengthSync() ?? originalSize);
    if (originalSize <= 0 || comp >= originalSize) return 0.0;
    return (1.0 - (comp / originalSize)) * 100.0;
  }

  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'caption': caption,
        'tags': tags,
        'originalSize': originalSize,
        'compressedSize': compressedSize,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
      };

  factory ZIPrItem.fromManifestJson(Map<String, dynamic> json, Directory baseMediaDir) {
    final type = json['type'] == 'video' ? MediaType.video : MediaType.photo;
    final fileName = json['fileName'] as String;
    final file = File('${baseMediaDir.path}/$fileName');

    return ZIPrItem(
      id: json['id'] as String? ?? UniqueKey().toString(),
      type: type,
      file: file,
      compressedFile: file,
      caption: json['caption'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      originalSize: json['originalSize'] as int? ?? (file.existsSync() ? file.lengthSync() : 0),
      compressedSize: json['compressedSize'] as int? ?? (file.existsSync() ? file.lengthSync() : 0),
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
    );
  }
}

class UniqueKey {
  @override
  String toString() => DateTime.now().microsecondsSinceEpoch.toString();
}
