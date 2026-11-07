import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

final String hexCiphertext =
    '''8E524060A10351BC2A83AD84E60698DA0C81C4DD5CC171AE7EBF3FC3250655E296FBEB788BED5BF5A0D042C5A2AFD1E2636128A5673428165AB11D92F5AE651AA8CB7DC3A9C463BFF1A7CE8E0F1264633A316A82E33EDA49EA7200E5F63AEF581DF8F57EE82594EF1AD52A43F87D9928A43EC8F9E468C6C8B3587AF974FC77580AE3964714271243AA9309D796F63A39BB3CBE905A84334483B79FDD45A8B8451B0A8E7C73906E44FE547ED81B2F4C2267655955C65841DD59C4305039E14B5FE450ECB1E1017F098D9712399CC66B4ABE32ADA53A62C242B2B998DE6440160D3584A520E933A713ED31C0C843C8B6C2B47C63A528AFECDA63BC9BBA195EEA71110631C351AAC369DF181DE02A14665EE9363F15E4976EC24E645D1B8D40A76E3A95D3C997B24A6F03A7185C91E29E0F96874C090BA4A1DFACDB4D4CCFDBD39D211A53877D398CFCB7732E8ED6E9AD08041B36DC58651D3E54FEDAA464E80B512F9D6F330155539D3374C59ED7949E72A1EDC25518101518A635AA81BC6EFB7A974FC20F8C1FA9441B25B57C7943E23C08AB63E077907D39A0B85974EBC5F92186F49EB51B34E8780FFE908E1204E8CE404CF18D52B90EFAAAC58C55F87D633FA72D0F440D8A92EB7FD1FCA2A2A8017443DB88F9071124C42890434AF0EC0B3C5C7CB5CD2A34428888CB588330FC709CCE237D6AD2D66AB879A2539D36F295300AD3FB203E00E06365FC6273F72C51F9DCC46F2A460E70BF4DFD2D6F82A654E061109BC3F79C352EF78CAEE429F2FC8AC2ACE392086A215E05DB80792FF94532CBD76D9816EF8CF790F0ECE89023EA4F8B0A893F60102E6E60E16A1680FFCD84BCAFB33C33FDF502ED147F55030B9BFF191F2AD42F92D521C81D964674A1A26750EAC6C88221A5C3C8BB9ABA680AAAF64EB6E1C79BED12C419F7EC0D07465E73E2D0DDB0BA73191458248D95D9147802B2F7A94BE87267D086566BA81DE28F5640549A197A828A6CA199274793150BF655C9A2BE63CE9B419510397F39D7DB113371A398AAF309C889C97C26D62D051E280A09A27F3FA0BAEFC056965542E2D6BABA8FA2532F82AFB40EC0F4A2FEDF7E6C4048C362163D6CE76735B806752A0089185BBBE8155A382F9648C1DF81A9AF5C0126C5C073807D427000820ECEE7153C899C3CA5D122DF5E8DCDEF9379323B00D1B1D543D40FD4C183E703DBE42F250528600BFD33D6F17880BDC3DC6241C16FAFC9EEBB203F09BDC02A7CD27C0E95571CC8E7AB2D7E0167C3DB6945A17F92ED04E4383187F4E1748B2EE2BDED9014151AFB7086E8241F0A1B430011B9DFFA5D4B4163DBFE734D9CB3AADF4C481C31C4D4366140F3B6EEEC1EE80CF2B139933FBD131FA2D6095DD2185AC39D7CB00FD9ECC24''';

Uint8List hexToBytes(String hex) {
  hex = hex.replaceAll(' ', '').replaceAll('\n', '');
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

Uint8List mash(List<int> input, int outLen, int iterations) {
  final sha1 = SHA1Digest();
  final bufSize = ((outLen + 19) ~/ 20) * 20;
  final outBuf = Uint8List(bufSize);
  final b = Uint8List(2);
  for (var i = 0; i < outLen; i += 20) {
    b[0] = (i >> 8) & 0xff;
    b[1] = i & 0xff;
    sha1.reset();
    sha1.update(b, 0, 2);
    sha1.update(Uint8List.fromList(input), 0, input.length);
    final d = sha1.process(Uint8List(0));
    outBuf.setRange(i, i + 20, d);
  }
  for (var iter = 1; iter < iterations; iter++) {
    final buf = Uint8List.fromList(outBuf);
    for (var i = 0; i < bufSize; i += 20) {
      b[0] = (i >> 8) & 0xff;
      b[1] = i & 0xff;
      sha1.reset();
      sha1.update(b, 0, 2);
      sha1.update(buf, 0, buf.length);
      final d = sha1.process(Uint8List(0));
      outBuf.setRange(i, i + 20, d);
    }
  }
  return Uint8List.fromList(outBuf.sublist(0, outLen));
}

Uint8List expandKey(Uint8List key16) {
  if (key16.length == 16)
    return Uint8List.fromList([...key16, ...key16.sublist(0, 8)]);
  return key16;
}

Uint8List processBlocks(BlockCipher cipher, Uint8List input) {
  final out = Uint8List(input.length);
  for (var offset = 0; offset < input.length; offset += cipher.blockSize) {
    cipher.processBlock(input, offset, out, offset);
  }
  return out;
}

bool listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
  return true;
}

String? tryDecrypt(int saltSize, int macSize) {
  final raw = hexToBytes(hexCiphertext);
  final passphrase = '%\$%###&*@~!~!?/.@#\$\$%^&*';
  final passphraseBytes = utf8.encode(passphrase);
  if (raw.length < saltSize + macSize + 8) return null;
  final salt = raw.sublist(0, saltSize);
  final ciphertext = raw.sublist(saltSize, raw.length - macSize);
  final macReceived = raw.sublist(raw.length - macSize);
  print(
      'saltSize=$saltSize macSize=$macSize raw=${raw.length} ciphertext=${ciphertext.length}');
  if (ciphertext.isEmpty || ciphertext.length % 8 != 0) {
    print('  ciphertext invalid or not block aligned');
    return null;
  }
  final keyIv = mash([...passphraseBytes, ...salt], 24, 200);
  final key = keyIv.sublist(0, 16);
  final iv = keyIv.sublist(16, 24);
  final cipher = CBCBlockCipher(DESedeEngine())
    ..init(false, ParametersWithIV(KeyParameter(expandKey(key)), iv));
  final paddedPlain = processBlocks(cipher, ciphertext);
  final sha1 = Digest('SHA-1');
  sha1.update(passphraseBytes, 0, passphraseBytes.length);
  sha1.update(salt, 0, salt.length);
  final keyCheck = sha1.process(Uint8List(0)).sublist(0, 8);
  final actualKeyCheck = paddedPlain.sublist(0, 8);
  print('  decrypted keyCheck begin ' +
      actualKeyCheck.map((e) => e.toRadixString(16).padLeft(2, '0')).join());
  if (!listEquals(actualKeyCheck, keyCheck)) {
    print('  keyCheck mismatch');
    return null;
  }
  final message = paddedPlain.sublist(8, paddedPlain.length - macSize);
  final macKey = mash(passphraseBytes, 16, 1);
  final hmac = HMac(SHA1Digest(), 64)..init(KeyParameter(macKey));
  hmac.update(message, 0, message.length);
  final macComputed = hmac.process(Uint8List(0));
  print(
      '  macReceived len=${macReceived.length} macComputed len=${macComputed.length}');
  if (!listEquals(macComputed, macReceived)) {
    print('  MAC mismatch');
    return null;
  }
  return utf8.decode(message);
}

void tryAll() {
  final raw = hexToBytes(hexCiphertext);
  print('raw length bytes=${raw.length} hex=${raw.length * 2}');
  for (var saltSize in [7, 8, 16]) {
    for (var macSize in [16, 20, 24, 28, 32]) {
      final cipherLen = raw.length - saltSize - macSize;
      if (cipherLen > 0 && cipherLen % 8 == 0) {
        print('possible salt=$saltSize mac=$macSize cipherLen=$cipherLen');
      }
    }
  }
}

void main() {
  tryAll();
  for (var saltSize in [7, 8, 16]) {
    for (var macSize in [16, 20, 24, 28, 32]) {
      print('\ntrying salt=$saltSize mac=$macSize');
      final text = tryDecrypt(saltSize, macSize);
      print('result=' + (text ?? '<null>'));
    }
  }
}
