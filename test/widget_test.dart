import 'package:bizhub_admin/core/format.dart';
import 'package:bizhub_admin/core/web_login.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone numbers become +855…', () {
    expect(normalizePhone('012 345 678'), '+85512345678');
    expect(normalizePhone('+855 12 345 678'), '+85512345678');
    expect(normalizePhone('12'), isNull);
  });

  test('web login string looks like crypto-js', () {
    final s = cryptoJsEncrypt('{"a":1}');
    expect(s.startsWith('U2FsdGVkX1'), isTrue); // "Salted__" in base64
  });
}
