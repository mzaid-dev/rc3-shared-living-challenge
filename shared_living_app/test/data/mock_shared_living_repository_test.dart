import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/errors/app_failure.dart';
import 'package:shared_living_app/features/shared_living/data/models/balances_response.dart';
import 'package:shared_living_app/features/shared_living/data/models/checkout_request_dto.dart';
import 'package:shared_living_app/features/shared_living/data/models/expense.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';

void main() {
  late MockSharedLivingRepository repository;

  setUp(() {
    // 0ms latency for fast test runs
    repository = MockSharedLivingRepository(latency: Duration.zero);
  });

  group('MockSharedLivingRepository Benchmark Verification', () {
    test('Reproduces official benchmark spending, budget, and zero-sum balances', () async {
      // 1. Budget Summary
      final budget = await repository.getBudgetSummary();
      expect(budget.spentPaisa, 420000); // PKR 4,200.00
      expect(budget.limitPaisa, 500000); // PKR 5,000.00
      expect(budget.remainingPaisa, 80000); // PKR 800.00
      expect(budget.percent, 84);
      expect(budget.status, 'near_limit');

      // 2. Balances Response
      final balances = await repository.getBalances();
      expect(balances.sumPaisa, 0); // Strict zero-sum invariant

      final ali = balances.balances.firstWhere((b) => b.memberId == 'M01');
      final ayesha = balances.balances.firstWhere((b) => b.memberId == 'M02');
      final bilal = balances.balances.firstWhere((b) => b.memberId == 'M03');

      expect(ali.netBalancePaisa, 25000); // +PKR 250.00
      expect(ali.status, 'owed');

      expect(ayesha.netBalancePaisa, -45000); // -PKR 450.00
      expect(ayesha.status, 'owes');

      expect(bilal.netBalancePaisa, 20000); // +PKR 200.00
      expect(bilal.status, 'owed');

      // 3. Dashboard Messages
      final aliDash = await repository.getDashboard(memberId: 'M01');
      expect(aliDash.member.message, 'You are owed PKR 250.00');

      final ayeshaDash = await repository.getDashboard(memberId: 'M02');
      expect(ayeshaDash.member.message, 'You owe PKR 450.00');

      final bilalDash = await repository.getDashboard(memberId: 'M03');
      expect(bilalDash.member.message, 'You are owed PKR 200.00');
    });

    test('Network failure dev toggle throws NetworkFailure', () async {
      repository.simulateNetworkFailure = true;
      expect(() => repository.getMembers(), throwsA(isA<NetworkFailure>()));
    });
  });

  group('Settlement Validation and Rule 6 Order Tests', () {
    test('Throws INVALID_AMOUNT for non-positive settlement', () async {
      expect(
        () => repository.recordSettlement(
          const SettlementRequestDto(
            senderId: 'M02',
            recipientId: 'M01',
            amount: '0.00',
          ),
          idempotencyKey: 'key_1',
        ),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'INVALID_AMOUNT')),
      );
    });

    test('Throws SELF_SETTLEMENT when sender == recipient', () async {
      expect(
        () => repository.recordSettlement(
          const SettlementRequestDto(
            senderId: 'M01',
            recipientId: 'M01',
            amount: '100.00',
          ),
          idempotencyKey: 'key_2',
        ),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'SELF_SETTLEMENT')),
      );
    });

    test('Rule 6 order: Ayesha pays Bilal 500.00 throws SETTLE_EXCEEDS_DEBT', () async {
      // Ayesha owes 450.00, Bilal is owed 200.00
      // 500.00 exceeds both, but SETTLE_EXCEEDS_DEBT must trigger first!
      expect(
        () => repository.recordSettlement(
          const SettlementRequestDto(
            senderId: 'M02',
            recipientId: 'M03',
            amount: '500.00',
          ),
          idempotencyKey: 'key_3',
        ),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'SETTLE_EXCEEDS_DEBT')),
      );
    });

    test('Rule 6 order: Ayesha pays Bilal 300.00 throws SETTLE_EXCEEDS_CREDIT', () async {
      // Ayesha owes 450.00 (so 300 <= 450 debt is OK)
      // Bilal credit is only 200.00 (300 > 200 credit fails!)
      expect(
        () => repository.recordSettlement(
          const SettlementRequestDto(
            senderId: 'M02',
            recipientId: 'M03',
            amount: '300.00',
          ),
          idempotencyKey: 'key_4',
        ),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'SETTLE_EXCEEDS_CREDIT')),
      );
    });

    test('Successful settlement updates balances and leaves spending unchanged at 420000', () async {
      // Ayesha pays Ali 250.00 (clearing Ali's balance)
      final result = await repository.recordSettlement(
        const SettlementRequestDto(
          senderId: 'M02',
          recipientId: 'M01',
          amount: '250.00',
        ),
        idempotencyKey: 'key_5',
      );

      final ali = result.balances.balances.firstWhere((b) => b.memberId == 'M01');
      final ayesha = result.balances.balances.firstWhere((b) => b.memberId == 'M02');

      expect(ali.netBalancePaisa, 0);
      expect(ali.status, 'settled');

      expect(ayesha.netBalancePaisa, -20000); // -PKR 200.00 remaining debt
      expect(ayesha.status, 'owes');

      // Spending remains invariant: exactly 420000 paisa (PKR 4,200.00)
      final budget = await repository.getBudgetSummary();
      expect(budget.spentPaisa, 420000);

      // Dashboard message for settled member
      final aliDash = await repository.getDashboard(memberId: 'M01');
      expect(aliDash.member.message, 'You are all settled up');
    });
  });

  group('Idempotency Replay & Atomic Checkout Tests', () {
    test('Idempotency replay returns stored response with exactly one expense created', () async {
      const key = 'idem_key_expense_1';
      final dto = const CreateExpenseDto(
        title: 'New Water Bottles',
        category: 'Groceries',
        amount: '200.00',
        payerId: 'M01',
        splitType: 'equal',
      );

      final expensesBefore = (await repository.getExpenses()).length;

      // First submit
      final exp1 = await repository.addExpense(dto, idempotencyKey: key);
      final expensesAfterFirst = (await repository.getExpenses()).length;
      expect(expensesAfterFirst, expensesBefore + 1);

      // Replay submit with same key and same payload
      final exp2 = await repository.addExpense(dto, idempotencyKey: key);
      final expensesAfterReplay = (await repository.getExpenses()).length;

      expect(expensesAfterReplay, expensesBefore + 1); // Exactly one record!
      expect(exp2.id, exp1.id);
    });

    test('Reusing idempotency key with different payload throws IDEMPOTENCY_KEY_REUSED', () async {
      const key = 'idem_key_expense_2';
      final dto1 = const CreateExpenseDto(
        title: 'Snacks',
        category: 'Groceries',
        amount: '100.00',
        payerId: 'M01',
        splitType: 'equal',
      );
      final dto2 = const CreateExpenseDto(
        title: 'Snacks and Drinks',
        category: 'Groceries',
        amount: '300.00',
        payerId: 'M01',
        splitType: 'equal',
      );

      await repository.addExpense(dto1, idempotencyKey: key);

      expect(
        () => repository.addExpense(dto2, idempotencyKey: key),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'IDEMPOTENCY_KEY_REUSED')),
      );
    });

    test('Atomic checkout: item already bought throws ITEM_ALREADY_BOUGHT and mutates nothing', () async {
      // Item ID 4 is already seeded as 'bought'
      final dto = const CheckoutRequestDto(
        itemIds: [4],
        totalPaid: '300.00',
        payerId: 'M01',
        splitMembers: ['M01', 'M02', 'M03'],
      );

      final expensesBefore = (await repository.getExpenses()).length;

      expect(
        () => repository.checkoutShopping(dto, idempotencyKey: 'key_atomic_1'),
        throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'ITEM_ALREADY_BOUGHT')),
      );

      final expensesAfter = (await repository.getExpenses()).length;
      expect(expensesAfter, expensesBefore); // Nothing mutated!
    });
  });
}
