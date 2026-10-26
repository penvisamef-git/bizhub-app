import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

// The web keeps the login in localStorage, encrypted with crypto-js:
//   AES.encrypt(JSON.stringify(login), "bizhub-client").toString()
// That is the OpenSSL format: "Salted__" + 8-byte salt + AES-256-CBC, key/iv from EVP_BytesToKey (MD5).
// We make the same string so a web page opened inside the app is already logged in.
String cryptoJsEncrypt(String text, {String passphrase = 'bizhub-client'}) {
  final rnd = Random.secure();
  final salt = Uint8List.fromList(List.generate(8, (_) => rnd.nextInt(256)));
  final pass = utf8.encode(passphrase);
  // EVP_BytesToKey: D_i = MD5(D_{i-1} || pass || salt) until 48 bytes (32 key + 16 iv)
  final out = BytesBuilder();
  var prev = Uint8List(0);
  while (out.length < 48) {
    final md5 = MD5Digest();
    final input = Uint8List.fromList([...prev, ...pass, ...salt]);
    prev = md5.process(input);
    out.add(prev);
  }
  final kv = out.toBytes();
  final key = kv.sublist(0, 32), iv = kv.sublist(32, 48);
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))..init(true, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null));
  final enc = cipher.process(Uint8List.fromList(utf8.encode(text)));
  return base64.encode([...utf8.encode('Salted__'), ...salt, ...enc]);
}
