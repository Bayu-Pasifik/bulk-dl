import 'package:bulk_dl/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final b in Brightness.values) {
    test('green scheme is green-dominant ($b)', () {
      final s = greenScheme(b);
      for (final c in [s.primary, s.primaryContainer]) {
        final hue = HSLColor.fromColor(c).hue;
        expect(hue, inInclusiveRange(90, 150), reason: '$c hue $hue');
      }
    });
  }

  test('buildTheme uses material 3 with the given scheme', () {
    final s = greenScheme(Brightness.light);
    final t = buildTheme(s);
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.primary, s.primary);
  });
}
