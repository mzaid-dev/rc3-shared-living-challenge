/// Shared Application Constants
class AppConstants {
  /// Exactly four valid units for shopping items
  static const List<String> validUnits = ['pack', 'dozen', 'bottle', 'bag'];

  /// Default currency code
  static const String currency = 'PKR';

  /// Default monthly budget limit in paisa (PKR 5,000.00)
  static const int defaultMonthlyBudgetPaisa = 500000;

  /// Default household members
  static const List<String> defaultMemberIds = ['M01', 'M02', 'M03'];

  /// Maximum allowed amount in paisa: 10,000,000.00 PKR (1,000,000,000 paisa)
  static const int maxAmountPaisa = 1000000000;
}
