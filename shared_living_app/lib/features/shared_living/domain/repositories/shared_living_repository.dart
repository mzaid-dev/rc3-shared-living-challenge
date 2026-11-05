import '../../data/models/balances_response.dart';
import '../../data/models/budget_and_dashboard.dart';
import '../../data/models/checkout_request_dto.dart';
import '../../data/models/expense.dart';
import '../../data/models/member.dart';
import '../../data/models/shopping_item.dart';

/// Abstract contract for Shared Living Household API operations.
/// Note: No Annexure A surprise task methods are included per Rule 9.
abstract class SharedLivingRepository {
  /// GET /api/members
  Future<List<Member>> getMembers();

  /// GET /api/shopping
  Future<List<ShoppingItem>> getShopping();

  /// POST /api/shopping
  Future<ShoppingItem> addShoppingItem(
    CreateShoppingItemDto dto, {
    required String idempotencyKey,
  });

  /// POST /api/shopping/checkout
  Future<Expense> checkoutShopping(
    CheckoutRequestDto dto, {
    required String idempotencyKey,
  });

  /// GET /api/expenses
  Future<List<Expense>> getExpenses();

  /// POST /api/expenses
  Future<Expense> addExpense(
    CreateExpenseDto dto, {
    required String idempotencyKey,
  });

  /// GET /api/balances
  Future<BalancesResponse> getBalances();

  /// POST /api/settle
  Future<SettlementResult> recordSettlement(
    SettlementRequestDto dto, {
    required String idempotencyKey,
  });

  /// GET /api/budget/summary
  Future<BudgetSummary> getBudgetSummary();

  /// GET /api/dashboard?member_id=
  Future<DashboardResponse> getDashboard({required String memberId});
}
