import 'package:flutter_test/flutter_test.dart';
import 'package:reels_maker/core/settings.dart';
import 'package:reels_maker/services/captions.dart';

void main() {
  test('settings round trip', () {
    final s = AppSettings(anthropicKey: 'k', reelsPerRun: 3);
    final r = AppSettings.fromJson(s.toJson());
    expect(r.anthropicKey, 'k');
    expect(r.reelsPerRun, 3);
  });

  test('chunks arabic text', () {
    final c = chunkWords('يا جماعة هاد الخبر قلب السوشال ميديا كلها اليوم');
    expect(c.isNotEmpty, true);
    expect(c.every((x) => x.length <= 3), true);
  });

  test('ass colors', () {
    expect(assColor('FFE500'), '&H0000E5FF');
  });
}
