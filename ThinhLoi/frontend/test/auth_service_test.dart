import 'package:flutter_test/flutter_test.dart';
import 'package:packflow/auth/auth_service.dart';

void main() {
  group('Vietnamese phone normalization', () {
    test('normalizes local number', () {
      expect(normalizeVietnamesePhone('0968 373 066'), '+84968373066');
      expect(isVietnamesePhone('0968 373 066'), isTrue);
    });

    test('keeps E.164 number', () {
      expect(normalizeVietnamesePhone('+84968373066'), '+84968373066');
    });
  });

  test('username accepts only normalized safe identifiers', () {
    expect(isUsername('thinhloibaobi'), isTrue);
    expect(isUsername('ThinhLoi_BaoBi'), isTrue);
    expect(isUsername('bad user'), isFalse);
    expect(isUsername('ab'), isFalse);
  });
}
