import 'dart:typed_data';

import 'package:app/core/services/encryption_service.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GCM encrypted bytes include tag', () {
    final key = Key.fromUtf8(List.filled(32, 'a').join());
    final iv = IV(Uint8List.fromList(List.filled(EncryptionService.ivLength, 1)));
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

    final data = Uint8List.fromList(List<int>.generate(100, (i) => i % 256));
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // ignore: avoid_print
    print('plaintext=${data.length}, encrypted=${encrypted.bytes.length}');
    expect(encrypted.bytes.length, data.length + EncryptionService.gcmTagLength);
  });
}
