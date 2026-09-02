import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

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
}
