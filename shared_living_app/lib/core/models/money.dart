import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';
import '../errors/app_failure.dart';

/// Immutable monetary value object stored strictly in integer paisa.
class Money extends Equatable {
  final int paisa;

  const Money(this.paisa);

  factory Money.fromPaisa(int paisa) => Money(paisa);

  /// Parses input string to integer paisa.
  /// Rejects amounts <= 0, malformed strings, or amounts > 10,000,000.00 (1,000,000,000 paisa).
  factory Money.parse(String input) {
    final sanitized = input.trim().replaceAll(',', '');
    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(sanitized)) {
      throw const AppFailure(
        code: 'INVALID_AMOUNT',
        message: 'Amount must be a valid positive number with up to 2 decimal places.',
      );
    }

    final parts = sanitized.split('.');
    final rupees = int.tryParse(parts[0]);
    if (rupees == null) {
      throw const AppFailure(
        code: 'INVALID_AMOUNT',
        message: 'Invalid rupee portion.',
      );
    }

    final cents = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
    final total = (rupees * 100) + cents;

    if (total <= 0) {
      throw const AppFailure(
        code: 'INVALID_AMOUNT',
        message: 'Amount must be greater than zero.',
      );
    }

    if (total > AppConstants.maxAmountPaisa) {
      throw const AppFailure(
        code: 'INVALID_AMOUNT',
        message: 'Amount exceeds maximum permitted limit of PKR 10,000,000.00.',
      );
    }

    return Money(total);
  }

  /// Serializes to exact 2-decimal string for JSON payloads (e.g. 78000 -> "780.00").
  /// Asserts paisa >= 0.
  String toJsonString() {
    assert(paisa >= 0, 'paisa must be non-negative for toJsonString');
    final rupees = paisa ~/ 100;
    final cents = (paisa % 100).toString().padLeft(2, '0');
    return '$rupees.$cents';
  }

  /// Formats currency with thousands separators.
  /// format(0) -> "PKR 0.00"
  /// format(5) -> "PKR 0.05"
  /// format(123456789) -> "PKR 1,234,567.89"
  String format({bool includePrefix = true}) {
    final isNegative = paisa < 0;
    final absPaisa = paisa.abs();
    final rupees = absPaisa ~/ 100;
    final cents = (absPaisa % 100).toString().padLeft(2, '0');

    final rupeeStr = rupees.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    final sign = isNegative ? '-' : '';
    final prefix = includePrefix ? 'PKR ' : '';
    return '$sign$prefix$rupeeStr.$cents';
  }

  Money operator +(Money other) => Money(paisa + other.paisa);
  Money operator -(Money other) => Money(paisa - other.paisa);
  bool operator <(Money other) => paisa < other.paisa;
  bool operator <=(Money other) => paisa <= other.paisa;
  bool operator >(Money other) => paisa > other.paisa;
  bool operator >=(Money other) => paisa >= other.paisa;

  @override
  List<Object?> get props => [paisa];

  @override
  String toString() => format();
}
