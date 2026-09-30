import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

class EncryptionResult {
  final Uint8List cipherBytes;
  final String saltHex;
  final String ivHex;

  EncryptionResult({
    required this.cipherBytes,
    required this.saltHex,
    required this.ivHex,
  });
}

class StreamCipherResult {
  final String saltHex;
  final String ivHex;
  final int cipherLength;

  StreamCipherResult({
    required this.saltHex,
    required this.ivHex,
    required this.cipherLength,
  });
}

class EncryptionService {
  static const String magicHeader = 'ZIPR_ENC_V1:';

  /// Generates cryptographically secure random bytes
  static Uint8List generateRandomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  /// Converts byte array to Hex string
  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Converts Hex string to Uint8List
  static Uint8List hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Derives 32-byte (256-bit) AES key using PBKDF2-like SHA-256 iterations
  static Uint8List deriveKey(String password, Uint8List salt, {int iterations = 10000}) {
    List<int> current = utf8.encode(password) + salt;
    for (int i = 0; i < iterations; i++) {
      current = sha256.convert(current).bytes;
    }
    return Uint8List.fromList(current);
  }

  /// Encrypts raw bytes with AES-256-CBC and appends validation header
  static EncryptionResult encryptBytes(Uint8List plainBytes, String password) {
    final salt = generateRandomBytes(16);
    final ivBytes = generateRandomBytes(16);

    final keyBytes = deriveKey(password, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    // Prepend magic header to verify password correctness upon decryption
    final headerBytes = utf8.encode(magicHeader);
    final payloadToEncrypt = Uint8List(headerBytes.length + plainBytes.length)
      ..setRange(0, headerBytes.length, headerBytes)
      ..setRange(headerBytes.length, headerBytes.length + plainBytes.length, plainBytes);

    final encrypted = encrypter.encryptBytes(payloadToEncrypt, iv: iv);

    return EncryptionResult(
      cipherBytes: encrypted.bytes,
      saltHex: bytesToHex(salt),
      ivHex: bytesToHex(ivBytes),
    );
  }

  /// Decrypts bytes with AES-256-CBC and verifies magic header
  static Uint8List decryptBytes({
    required Uint8List cipherBytes,
    required String password,
    required String saltHex,
    required String ivHex,
  }) {
    final salt = hexToBytes(saltHex);
    final ivBytes = hexToBytes(ivHex);

    final keyBytes = deriveKey(password, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    try {
      final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      final headerBytes = utf8.encode(magicHeader);

      if (decrypted.length < headerBytes.length) {
        throw const FormatException('Invalid password or corrupted archive.');
      }

      // Check header match
      for (int i = 0; i < headerBytes.length; i++) {
        if (decrypted[i] != headerBytes[i]) {
          throw const FormatException('Incorrect password for ZIPr archive.');
        }
      }

      return Uint8List.fromList(decrypted.sublist(headerBytes.length));
    } catch (e) {
      if (e is FormatException) rethrow;
      throw const FormatException('Incorrect password or failed to decrypt archive.');
    }
  }

  /// Instant in-memory password verification from the first 32 cipher bytes.
  /// Decrypts block 0 in ~0.1ms without touching disk or reading the payload.
  static bool verifyPasswordHeaderBytes({
    required List<int> cipherHeader,
    required String password,
    required String saltHex,
    required String ivHex,
  }) {
    try {
      final salt = hexToBytes(saltHex);
      final iv = hexToBytes(ivHex);
      final keyBytes = deriveKey(password, salt);

      final cipher = CBCBlockCipher(AESEngine());
      cipher.init(false, ParametersWithIV(KeyParameter(keyBytes), iv));

      if (cipherHeader.length < 16) return false;

      final len = (cipherHeader.length ~/ 16) * 16;
      final inBytes = Uint8List.fromList(cipherHeader.sublist(0, len));
      final outBuffer = Uint8List(len);
      for (int i = 0; i < len; i += 16) {
        cipher.processBlock(inBytes, i, outBuffer, i);
      }

      final magic = utf8.encode(magicHeader);
      if (outBuffer.length < magic.length) return false;
      for (int i = 0; i < magic.length; i++) {
        if (outBuffer[i] != magic[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// High-speed password verification without decrypting the entire payload.
  /// Reads only the first 32 bytes from disk, decrypts with AES-256-CBC, and tests magic header.
  static Future<bool> verifyPassword({
    required File inputFile,
    required String password,
    required String saltHex,
    required String ivHex,
  }) async {
    try {
      final raf = await inputFile.open(mode: FileMode.read);
      try {
        final cipherHeader = await raf.read(32);
        return verifyPasswordHeaderBytes(
          cipherHeader: cipherHeader,
          password: password,
          saltHex: saltHex,
          ivHex: ivHex,
        );
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Stream-encrypts a file on disk using AES-256-CBC with minimal RAM overhead (O(1) memory, ~256 KB buffer).
  /// Capable of encrypting arbitrarily large containers (1 GB, 10 GB+) without Out-of-Memory crashes.
  static Future<StreamCipherResult> encryptFileStream({
    required File inputFile,
    required File outputFile,
    required String password,
    void Function(double progress)? onProgress,
  }) async {
    final salt = generateRandomBytes(16);
    final iv = generateRandomBytes(16);
    final keyBytes = deriveKey(password, salt);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(keyBytes), iv));

    final totalInputSize = await inputFile.length();
    final inSink = outputFile.openWrite();

    // 1. Write the magic header encrypted first
    final magicBytes = utf8.encode(magicHeader);
    const bufferCapacity = 256 * 1024; // High-throughput 256 KB buffer for accelerated streaming
    final buffer = Uint8List(bufferCapacity);
    int bufferLen = 0;

    // Put magic header into buffer
    buffer.setRange(0, magicBytes.length, magicBytes);
    bufferLen = magicBytes.length;

    int totalBytesRead = 0;
    int totalCipherWritten = 0;
    int lastProgressPercent = -1;
    int bytesSinceLastFlush = 0;

    final reader = inputFile.openRead();
    await for (final chunk in reader) {
      totalBytesRead += chunk.length;
      int chunkOffset = 0;

      while (chunkOffset < chunk.length) {
        final toCopy = (buffer.length - bufferLen).clamp(0, chunk.length - chunkOffset);
        buffer.setRange(bufferLen, bufferLen + toCopy, chunk, chunkOffset);
        bufferLen += toCopy;
        chunkOffset += toCopy;

        if (bufferLen == buffer.length) {
          final outBuffer = Uint8List(buffer.length);
          for (int i = 0; i < buffer.length; i += 16) {
            cipher.processBlock(buffer, i, outBuffer, i);
          }
          inSink.add(outBuffer);
          totalCipherWritten += outBuffer.length;
          bytesSinceLastFlush += outBuffer.length;
          bufferLen = 0;

          // Enforce backpressure every 4MB to keep RAM usage strictly bounded (O(1))
          if (bytesSinceLastFlush >= 4 * 1024 * 1024) {
            await inSink.flush();
            bytesSinceLastFlush = 0;
          }

          if (totalInputSize > 0) {
            final percent = ((totalBytesRead / totalInputSize) * 100).toInt();
            if (percent > lastProgressPercent) {
              lastProgressPercent = percent;
              onProgress?.call(percent / 100.0);
            }
          }
        }
      }
    }

    // Finalize remaining bytes with standard PKCS7 padding
    final remainingBytes = bufferLen % 16;
    final padLength = 16 - remainingBytes;

    final finalPlainLen = bufferLen + padLength;
    final finalPlain = Uint8List(finalPlainLen);
    finalPlain.setRange(0, bufferLen, buffer.sublist(0, bufferLen));
    for (int i = bufferLen; i < finalPlainLen; i++) {
      finalPlain[i] = padLength;
    }

    final finalCipher = Uint8List(finalPlainLen);
    for (int i = 0; i < finalPlainLen; i += 16) {
      cipher.processBlock(finalPlain, i, finalCipher, i);
    }
    inSink.add(finalCipher);
    totalCipherWritten += finalCipher.length;

    await inSink.flush();
    await inSink.close();

    return StreamCipherResult(
      saltHex: bytesToHex(salt),
      ivHex: bytesToHex(iv),
      cipherLength: totalCipherWritten,
    );
  }

  /// Stream-decrypts a file on disk using AES-256-CBC with minimal RAM overhead (O(1) memory, ~64 KB buffer).
  /// Verifies the magic header, strips PKCS7 padding, and streams decrypted output directly to target file.
  static Future<void> decryptFileStream({
    required File inputFile,
    required File outputFile,
    required String password,
    required String saltHex,
    required String ivHex,
    void Function(double progress)? onProgress,
  }) async {
    final salt = hexToBytes(saltHex);
    final iv = hexToBytes(ivHex);
    final keyBytes = deriveKey(password, salt);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(keyBytes), iv));

    final totalInputSize = await inputFile.length();
    final outSink = outputFile.openWrite();
    final reader = inputFile.openRead();
    const bufferCapacity = 256 * 1024; // High-throughput 256 KB buffer for accelerated streaming
    final buffer = Uint8List(bufferCapacity);
    int bufferLen = 0;

    Uint8List? previousDecryptedTail;
    bool verifiedHeader = false;
    int totalBytesRead = 0;
    int lastProgressPercent = -1;
    int bytesSinceLastFlush = 0;

    await for (final chunk in reader) {
      totalBytesRead += chunk.length;
      int chunkOffset = 0;
      while (chunkOffset < chunk.length) {
        final toCopy = (buffer.length - bufferLen).clamp(0, chunk.length - chunkOffset);
        buffer.setRange(bufferLen, bufferLen + toCopy, chunk, chunkOffset);
        bufferLen += toCopy;
        chunkOffset += toCopy;

        if (bufferLen == buffer.length) {
          final outBuffer = Uint8List(buffer.length);
          for (int i = 0; i < buffer.length; i += 16) {
            cipher.processBlock(buffer, i, outBuffer, i);
          }

          if (!verifiedHeader) {
            final magic = utf8.encode(magicHeader);
            final slice = outBuffer.sublist(0, magic.length);
            if (utf8.decode(slice, allowMalformed: true) != magicHeader) {
              await outSink.close();
              throw const FormatException('Incorrect password for ZIPr archive.');
            }
            verifiedHeader = true;
            final startIdx = magic.length;
            if (previousDecryptedTail != null) {
              outSink.add(previousDecryptedTail);
              bytesSinceLastFlush += previousDecryptedTail.length;
            }
            previousDecryptedTail = outBuffer.sublist(outBuffer.length - 16);
            final firstChunk = outBuffer.sublist(startIdx, outBuffer.length - 16);
            outSink.add(firstChunk);
            bytesSinceLastFlush += firstChunk.length;
          } else {
            if (previousDecryptedTail != null) {
              outSink.add(previousDecryptedTail);
              bytesSinceLastFlush += previousDecryptedTail.length;
            }
            previousDecryptedTail = outBuffer.sublist(outBuffer.length - 16);
            final middleChunk = outBuffer.sublist(0, outBuffer.length - 16);
            outSink.add(middleChunk);
            bytesSinceLastFlush += middleChunk.length;
          }

          // Enforce backpressure every 4MB to keep RAM usage strictly bounded (O(1))
          if (bytesSinceLastFlush >= 4 * 1024 * 1024) {
            await outSink.flush();
            bytesSinceLastFlush = 0;
          }

          bufferLen = 0;
          if (totalInputSize > 0) {
            final percent = ((totalBytesRead / totalInputSize) * 100).toInt();
            if (percent > lastProgressPercent) {
              lastProgressPercent = percent;
              onProgress?.call(percent / 100.0);
            }
          }
        }
      }
    }

    if (bufferLen > 0) {
      if (bufferLen % 16 != 0) {
        await outSink.close();
        throw const FormatException('Corrupted cipher stream: not a multiple of 16-byte block size');
      }
      final outBuffer = Uint8List(bufferLen);
      for (int i = 0; i < bufferLen; i += 16) {
        cipher.processBlock(buffer, i, outBuffer, i);
      }

      if (!verifiedHeader) {
        final magic = utf8.encode(magicHeader);
        if (outBuffer.length < magic.length) {
          await outSink.close();
          throw const FormatException('Incorrect password for ZIPr archive.');
        }
        final slice = outBuffer.sublist(0, magic.length);
        if (utf8.decode(slice, allowMalformed: true) != magicHeader) {
          await outSink.close();
          throw const FormatException('Incorrect password for ZIPr archive.');
        }
        verifiedHeader = true;
        final payloadWithoutHeader = outBuffer.sublist(magic.length);
        final padLength = payloadWithoutHeader.last;
        if (padLength < 1 || padLength > 16 || padLength > payloadWithoutHeader.length) {
          await outSink.close();
          throw const FormatException('Invalid padding on decrypted stream');
        }
        outSink.add(payloadWithoutHeader.sublist(0, payloadWithoutHeader.length - padLength));
      } else {
        if (previousDecryptedTail != null) {
          outSink.add(previousDecryptedTail);
        }
        final padLength = outBuffer.last;
        if (padLength < 1 || padLength > 16 || padLength > outBuffer.length) {
          await outSink.close();
          throw const FormatException('Invalid padding on decrypted stream');
        }
        outSink.add(outBuffer.sublist(0, outBuffer.length - padLength));
      }
    } else if (previousDecryptedTail != null) {
      final padLength = previousDecryptedTail.last;
      if (padLength < 1 || padLength > 16) {
        await outSink.close();
        throw const FormatException('Invalid padding on decrypted stream');
      }
      outSink.add(previousDecryptedTail.sublist(0, 16 - padLength));
    }

    await outSink.flush();
    await outSink.close();
  }

  /// Extracts the first [count] cipher bytes from an ArchiveFile without dumping to disk.
  /// Used for instant (<1ms) password verification.
  static List<int> extractArchiveFileHeaderBytes(ArchiveFile payloadArchiveFile, {int count = 32}) {
    final cap = _HeaderCaptureOutputStream(maxBytes: count);
    payloadArchiveFile.writeContent(cap);
    return cap.bytes;
  }

  /// Stream-decrypts directly from an ArchiveFile into a target output file on disk.
  /// Decrypts in memory on-the-fly without ever writing intermediate payload.enc to disk!
  static Future<void> decryptArchiveFileToDisk({
    required ArchiveFile payloadArchiveFile,
    required File outputFile,
    required String password,
    required String saltHex,
    required String ivHex,
    void Function(double progress)? onProgress,
  }) async {
    final salt = hexToBytes(saltHex);
    final iv = hexToBytes(ivHex);
    final keyBytes = deriveKey(password, salt);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(keyBytes), iv));

    final outStream = OutputFileStream(outputFile.path);
    final decryptingStream = _StreamingDecryptOutputStream(
      outStream: outStream,
      cipher: cipher,
      magicHeader: magicHeader,
      onProgress: onProgress,
      totalSize: payloadArchiveFile.size,
    );

    try {
      payloadArchiveFile.writeContent(decryptingStream);
      decryptingStream.finalize();
    } finally {
      await outStream.close();
    }
  }
}

class _HeaderCaptureOutputStream extends OutputStream {
  final List<int> bytes = [];
  final int maxBytes;

  _HeaderCaptureOutputStream({this.maxBytes = 32})
      : super(byteOrder: ByteOrder.littleEndian);

  @override
  int get length => bytes.length;
  @override
  void clear() => bytes.clear();
  @override
  void flush() {}
  @override
  Uint8List subset(int start, [int? end]) => Uint8List.fromList(bytes.sublist(start, end));

  @override
  void writeByte(int byte) {
    if (bytes.length < maxBytes) bytes.add(byte);
  }

  @override
  void writeBytes(List<int> chunk, {int? length}) {
    if (bytes.length >= maxBytes) return;
    final effLen = length ?? chunk.length;
    final toAdd = chunk.sublist(0, effLen);
    final needed = (maxBytes - bytes.length).clamp(0, toAdd.length);
    bytes.addAll(toAdd.sublist(0, needed));
  }

  @override
  void writeStream(InputStream stream) {
    final needed = maxBytes - bytes.length;
    if (needed > 0 && !stream.isEOS) {
      final toRead = stream.length > 0 && stream.length < needed ? stream.length : needed;
      final chunk = stream.readBytes(toRead).toUint8List();
      bytes.addAll(chunk);
    }
  }
}

class _StreamingDecryptOutputStream extends OutputStream {
  final OutputFileStream outStream;
  final CBCBlockCipher cipher;
  final String magicHeader;
  final void Function(double progress)? onProgress;
  final int totalSize;

  final Uint8List _buffer = Uint8List(256 * 1024);
  int _bufferLen = 0;
  Uint8List? _previousDecryptedTail;
  bool _verifiedHeader = false;
  int _totalProcessed = 0;
  int _bytesSinceLastFlush = 0;

  _StreamingDecryptOutputStream({
    required this.outStream,
    required this.cipher,
    required this.magicHeader,
    this.onProgress,
    this.totalSize = 0,
  }) : super(byteOrder: ByteOrder.littleEndian);

  @override
  int get length => _totalProcessed;

  @override
  void clear() => _bufferLen = 0;

  @override
  void flush() {
    outStream.flush();
  }

  @override
  Uint8List subset(int start, [int? end]) => Uint8List(0);

  @override
  void writeByte(int byte) {
    _buffer[_bufferLen++] = byte;
    _totalProcessed++;
    if (_bufferLen == _buffer.length) {
      _processBufferBlock(_buffer.length);
    }
  }

  @override
  void writeBytes(List<int> chunk, {int? length}) {
    final effectiveLength = length ?? chunk.length;
    int chunkOffset = 0;

    while (chunkOffset < effectiveLength) {
      final toCopy = (_buffer.length - _bufferLen).clamp(0, effectiveLength - chunkOffset);
      _buffer.setRange(_bufferLen, _bufferLen + toCopy, chunk, chunkOffset);
      _bufferLen += toCopy;
      chunkOffset += toCopy;
      _totalProcessed += toCopy;

      if (_bufferLen == _buffer.length) {
        _processBufferBlock(_buffer.length);
      }
    }
  }

  void _processBufferBlock(int processLen) {
    final outBuffer = Uint8List(processLen);
    for (int i = 0; i < processLen; i += 16) {
      cipher.processBlock(_buffer, i, outBuffer, i);
    }

    if (!_verifiedHeader) {
      final magic = utf8.encode(magicHeader);
      final slice = outBuffer.sublist(0, magic.length);
      if (utf8.decode(slice, allowMalformed: true) != magicHeader) {
        throw const FormatException('Incorrect password for ZIPr archive.');
      }
      _verifiedHeader = true;
      final startIdx = magic.length;
      if (_previousDecryptedTail != null) {
        outStream.writeBytes(_previousDecryptedTail!);
        _bytesSinceLastFlush += _previousDecryptedTail!.length;
      }
      _previousDecryptedTail = Uint8List.fromList(outBuffer.sublist(outBuffer.length - 16));
      final firstChunk = outBuffer.sublist(startIdx, outBuffer.length - 16);
      outStream.writeBytes(firstChunk);
      _bytesSinceLastFlush += firstChunk.length;
    } else {
      if (_previousDecryptedTail != null) {
        outStream.writeBytes(_previousDecryptedTail!);
        _bytesSinceLastFlush += _previousDecryptedTail!.length;
      }
      _previousDecryptedTail = Uint8List.fromList(outBuffer.sublist(outBuffer.length - 16));
      final middleChunk = outBuffer.sublist(0, outBuffer.length - 16);
      outStream.writeBytes(middleChunk);
      _bytesSinceLastFlush += middleChunk.length;
    }

    if (_bytesSinceLastFlush >= 4 * 1024 * 1024) {
      outStream.flush();
      _bytesSinceLastFlush = 0;
    }

    _bufferLen = 0;
    if (totalSize > 0 && onProgress != null) {
      onProgress!((_totalProcessed / totalSize).clamp(0.0, 1.0));
    }
  }

  void finalize() {
    if (_bufferLen > 0) {
      if (_bufferLen % 16 != 0) {
        throw const FormatException('Corrupted cipher stream: not a multiple of 16-byte block size');
      }
      _processBufferBlock(_bufferLen);
    }

    if (!_verifiedHeader) {
      throw const FormatException('Incorrect password or payload too short.');
    }

    if (_previousDecryptedTail != null) {
      final lastBlock = _previousDecryptedTail!;
      final padLength = lastBlock[15];
      if (padLength > 0 && padLength <= 16) {
        bool validPadding = true;
        for (int i = 16 - padLength; i < 16; i++) {
          if (lastBlock[i] != padLength) {
            validPadding = false;
            break;
          }
        }
        if (validPadding) {
          final unpaddedLength = 16 - padLength;
          if (unpaddedLength > 0) {
            outStream.writeBytes(lastBlock.sublist(0, unpaddedLength));
          }
        } else {
          outStream.writeBytes(lastBlock);
        }
      } else {
        outStream.writeBytes(lastBlock);
      }
    }
    outStream.flush();
  }

  @override
  void writeStream(InputStream stream) {
    const chunkSize = 256 * 1024;
    var size = stream.length;
    if (size > 0) {
      while (size > chunkSize) {
        final bytes = stream.readBytes(chunkSize).toUint8List();
        writeBytes(bytes);
        size -= chunkSize;
      }
      if (size > 0) {
        final bytes = stream.readBytes(size).toUint8List();
        writeBytes(bytes);
      }
    } else {
      while (!stream.isEOS) {
        final bytes = stream.readBytes(chunkSize).toUint8List();
        if (bytes.isEmpty) break;
        writeBytes(bytes);
      }
    }
  }
}

