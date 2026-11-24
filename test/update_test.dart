import 'package:bulk_dl/update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version compare', () {
    expect(Updater.isNewer('v1.2.1', '1.2.0'), true);
    expect(Updater.isNewer('v1.10.0', '1.9.9'), true);
    expect(Updater.isNewer('v1.2.0', '1.2.0'), false);
    expect(Updater.isNewer('v1.2.0', '1.2.0+3'), false);
    expect(Updater.isNewer('v1.1.9', '1.2.0'), false);
    expect(Updater.isNewer('v2', '1.9.9'), true);
  });

  test('apk name by abi order', () {
    expect(
      Updater.apkName(['arm64-v8a', 'armeabi-v7a']),
      'app-arm64-v8a-release.apk',
    );
    expect(Updater.apkName(['x86', 'x86_64']), 'app-x86_64-release.apk');
    expect(Updater.apkName(['mips']), null);
  });
}
