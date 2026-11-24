import 'package:bulk_dl/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('en and id both resolve with placeholders', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final id = lookupAppLocalizations(const Locale('id'));
    expect(en.navQueue, 'Queue');
    expect(id.navQueue, 'Antrean');
    expect(en.pickerSelected(3), '3 selected');
    expect(id.pickerSelected(3), '3 dipilih');
    expect(en.downloadNSizeUnknown(2, '5 MB', 1), 'Download 2 · 5 MB (+1 ?)');
  });
}
