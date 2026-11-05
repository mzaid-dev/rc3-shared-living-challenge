import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/expenses/presentation/cubit/expenses_cubit.dart';
import 'package:shared_living_app/features/expenses/presentation/cubit/expenses_state.dart';
import 'package:shared_living_app/features/shared_living/data/models/balances_response.dart';
import 'package:shared_living_app/features/shared_living/data/models/expense.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';

void main() {
  late MockSharedLivingRepository repository;

  setUp(() {
    repository = MockSharedLivingRepository(latency: Duration.zero);
  });

  group('ExpensesCubit Tests', () {
    test('Loads shared expenses and balances', () async {
      final cubit = ExpensesCubit(repository: repository);
      await cubit.loadExpensesAndBalances();

      final state = cubit.state as ExpensesLoaded;
      expect(state.expenses.length, 4);
      expect(state.balances.balances.length, 3);
      expect(state.balances.sumPaisa, 0); // Zero-sum invariant
      cubit.close();
    });

    test('addExpense with custom split updates expenses and balances', () async {
      final cubit = ExpensesCubit(repository: repository);
      await cubit.loadExpensesAndBalances();

      const dto = CreateExpenseDto(
        title: 'Snack Run',
        category: 'Groceries',
        amount: '600.00',
        payerId: 'M01',
        splitType: 'custom',
        customSplits: [
          CustomSplitItemDto(memberId: 'M01', amount: '200.00'),
          CustomSplitItemDto(memberId: 'M02', amount: '200.00'),
          CustomSplitItemDto(memberId: 'M03', amount: '200.00'),
        ],
      );

      final success = await cubit.addExpense(dto, idempotencyKey: 'key_add_exp_1');
      expect(success, true);

      final state = cubit.state as ExpensesLoaded;
      expect(state.expenses.first.title, 'Snack Run');
      expect(state.actionSuccessMessage, isNotNull);
      cubit.close();
    });

    test('recordSettlement updates live member balance table', () async {
      final cubit = ExpensesCubit(repository: repository);
      await cubit.loadExpensesAndBalances();

      // Ayesha pays Ali 250.00
      const dto = SettlementRequestDto(
        senderId: 'M02',
        recipientId: 'M01',
        amount: '250.00',
      );

      final success = await cubit.recordSettlement(dto, idempotencyKey: 'key_settle_cubit_1');
      expect(success, true);

      final state = cubit.state as ExpensesLoaded;
      final ali = state.balances.balances.firstWhere((b) => b.memberId == 'M01');
      final ayesha = state.balances.balances.firstWhere((b) => b.memberId == 'M02');

      expect(ali.netBalancePaisa, 0); // Ali settled!
      expect(ayesha.netBalancePaisa, -20000); // -PKR 200.00
      expect(state.actionSuccessMessage, isNotNull);
      cubit.close();
    });
  });
}
