import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/errors/app_failure.dart';
import 'package:shared_living_app/core/models/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Money.parse parsing tests', () {
      expect(Money.parse('10.5').paisa, 1050);
      expect(Money.parse('1,500').paisa, 150000);
      expect(Money.parse('333.34').paisa, 33334);
      expect(Money.parse('780.00').paisa, 78000);

      // Rejects amounts above 10,000,000.00
      expect(
        () => Money.parse('10000000.01'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
      );

      // Rejects zero and negative
      expect(
        () => Money.parse('0'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
      );
      expect(
        () => Money.parse('-100'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
      );
      expect(
        () => Money.parse('abc'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
      );
      expect(
        () => Money.parse('10.999'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
      );
    });

    test('Money.format tests with thousands separators', () {
      expect(const Money(0).format(), 'PKR 0.00');
      expect(const Money(5).format(), 'PKR 0.05');
      expect(const Money(123456789).format(), 'PKR 1,234,567.89');
      expect(const Money(150000).format(), 'PKR 1,500.00');
      expect(const Money(-45000).format(), '-PKR 450.00');
      expect(const Money(25000).format(), 'PKR 250.00');
    });

    test('Money.toJsonString tests', () {
      expect(const Money(78000).toJsonString(), '780.00');
      expect(const Money(33334).toJsonString(), '333.34');
      expect(const Money(0).toJsonString(), '0.00');
    });
  });
}
