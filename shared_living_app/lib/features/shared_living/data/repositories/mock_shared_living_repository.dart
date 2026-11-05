import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/models/money.dart';
import '../../../../core/utils/split_preview_calculator.dart';
import '../../domain/repositories/shared_living_repository.dart';
import '../models/balances_response.dart';
import '../models/budget_and_dashboard.dart';
import '../models/checkout_item_ref.dart';
import '../models/checkout_request_dto.dart';
import '../models/expense.dart';
import '../models/member.dart';
import '../models/shopping_item.dart';

class _StoredRecord {
  final String payloadHash;
  final dynamic response;
  const _StoredRecord({required this.payloadHash, required this.response});
}

class MockSharedLivingRepository implements SharedLivingRepository {
  /// Dev toggle to simulate offline network errors
  bool simulateNetworkFailure = false;

  /// Simulated network latency (400ms)
  final Duration latency;

  MockSharedLivingRepository({
    this.latency = const Duration(milliseconds: 400),
  }) {
    _seedBenchmarkData();
  }

  // In-memory data tables
  final List<Member> _members = [];
  final List<ShoppingItem> _shoppingItems = [];
  final List<Expense> _expenses = [];
  final Map<String, int> _memberPaidPaisa = {};
  final Map<String, int> _memberShareOwedPaisa = {};
  final Map<String, int> _memberSettlementsReceivedPaisa = {};
  final Map<String, int> _memberSettlementsSentPaisa = {};

  int _nextShoppingItemId = 5;
  int _nextExpenseId = 5;

  // Idempotency store: key -> _StoredRecord
  final Map<String, _StoredRecord> _idempotencyStore = {};

  void _seedBenchmarkData() {
    _members.clear();
    _members.addAll(const [
      Member(id: 'M01', name: 'Ali'),
      Member(id: 'M02', name: 'Ayesha'),
      Member(id: 'M03', name: 'Bilal'),
    ]);

    for (final m in _members) {
      _memberPaidPaisa[m.id] = 0;
      _memberShareOwedPaisa[m.id] = 0;
      _memberSettlementsReceivedPaisa[m.id] = 0;
      _memberSettlementsSentPaisa[m.id] = 0;
    }

    _shoppingItems.clear();
    _shoppingItems.addAll(const [
      ShoppingItem(
        id: 1,
        title: 'Olpers Full Cream Milk',
        unit: 'pack',
        requestedQty: 2,
        status: 'pending',
      ),
      ShoppingItem(
        id: 2,
        title: 'Basmati Rice (Kernel)',
        unit: 'bag',
        requestedQty: 1,
        status: 'pending',
      ),
      ShoppingItem(
        id: 3,
        title: 'Dishwashing Gel (Max)',
        unit: 'bottle',
        requestedQty: 1,
        status: 'pending',
      ),
      ShoppingItem(
        id: 4,
        title: 'Surface Cleaning Wipes',
        unit: 'pack',
        requestedQty: 1,
        status: 'bought',
      ),
    ]);

    _expenses.clear();

    // 1. Grocery Trip (Milk & Rice) - PKR 780.00 paid by Ali (M01), Equal across 3
    _recordSeededExpense(
      id: 1,
      title: 'Grocery Trip (Milk & Rice)',
      category: 'Groceries',
      amountPaisa: 78000,
      payerId: 'M01',
      splitType: 'equal',
      date: '2026-11-04',
      source: 'checkout',
      splitMembers: ['M01', 'M02', 'M03'],
      items: const [
        CheckoutItemRef(id: 1, title: 'Olpers Full Cream Milk', status: 'bought'),
        CheckoutItemRef(id: 2, title: 'Basmati Rice (Kernel)', status: 'bought'),
      ],
    );

    // 2. Cleaning Supplies - PKR 900.00 paid by Ayesha (M02), Equal Ali & Ayesha
    _recordSeededExpense(
      id: 2,
      title: 'Cleaning Supplies',
      category: 'Cleaning',
      amountPaisa: 90000,
      payerId: 'M02',
      splitType: 'equal',
      date: '2026-11-03',
      source: 'manual',
      splitMembers: ['M01', 'M02'],
    );

    // 3. Internet Bill - PKR 1,500.00 paid by Bilal (M03), Custom: Ali 500, Ayesha 300, Bilal 700
    _recordSeededExpense(
      id: 3,
      title: 'Internet Bill',
      category: 'Utilities',
      amountPaisa: 150000,
      payerId: 'M03',
      splitType: 'custom',
      date: '2026-11-02',
      source: 'manual',
      customShares: {'M01': 50000, 'M02': 30000, 'M03': 70000},
    );

    // 4. Electricity Bill - PKR 1,020.00 paid by Ali (M01), Equal across 3
    _recordSeededExpense(
      id: 4,
      title: 'Electricity Bill',
      category: 'Utilities',
      amountPaisa: 102000,
      payerId: 'M01',
      splitType: 'equal',
      date: '2026-11-01',
      source: 'manual',
      splitMembers: ['M01', 'M02', 'M03'],
    );
  }

  void _recordSeededExpense({
    required int id,
    required String title,
    required String category,
    required int amountPaisa,
    required String payerId,
    required String splitType,
    required String date,
    required String source,
    List<String>? splitMembers,
    Map<String, int>? customShares,
    List<CheckoutItemRef> items = const [],
  }) {
    _memberPaidPaisa[payerId] = (_memberPaidPaisa[payerId] ?? 0) + amountPaisa;

    final shares = <String, int>{};
    if (splitType == 'equal') {
      final members = splitMembers ?? _members.map((m) => m.id).toList();
      final preview = SplitPreviewCalculator.previewEqualSplit(
        totalPaisa: amountPaisa,
        memberIds: members,
      );
      shares.addAll(preview);
    } else {
      shares.addAll(customShares ?? {});
    }

    final splitList = <ExpenseSplitShare>[];
    shares.forEach((memberId, sharePaisa) {
      _memberShareOwedPaisa[memberId] =
          (_memberShareOwedPaisa[memberId] ?? 0) + sharePaisa;
      splitList.add(ExpenseSplitShare(
        memberId: memberId,
        share: Money.fromPaisa(sharePaisa).toJsonString(),
        sharePaisa: sharePaisa,
      ));
    });

    _expenses.add(Expense(
      id: id,
      title: title,
      category: category,
      amount: Money.fromPaisa(amountPaisa).toJsonString(),
      amountPaisa: amountPaisa,
      payerId: payerId,
      splitType: splitType,
      date: date,
      source: source,
      splits: splitList,
      items: items,
    ));
  }

  Future<void> _checkPreconditions() async {
    if (latency.inMilliseconds > 0) {
      await Future.delayed(latency);
    }
    if (simulateNetworkFailure) {
      throw const NetworkFailure();
    }
  }

  String _hashPayload(dynamic payload) {
    final str = jsonEncode(payload);
    return sha256.convert(utf8.encode(str)).toString();
  }

  T? _checkIdempotency<T>(String key, dynamic payload) {
    if (_idempotencyStore.containsKey(key)) {
      final stored = _idempotencyStore[key]!;
      final currentHash = _hashPayload(payload);
      if (stored.payloadHash == currentHash) {
        return stored.response as T;
      } else {
        throw const AppFailure(
          code: 'IDEMPOTENCY_KEY_REUSED',
          message: 'Idempotency key reused with different payload.',
        );
      }
    }
    return null;
  }

  void _storeIdempotency(String key, dynamic payload, dynamic response) {
    _idempotencyStore[key] = _StoredRecord(
      payloadHash: _hashPayload(payload),
      response: response,
    );
  }

  @override
  Future<List<Member>> getMembers() async {
    await _checkPreconditions();
    return List.unmodifiable(_members);
  }

  @override
  Future<List<ShoppingItem>> getShopping() async {
    await _checkPreconditions();
    return List.unmodifiable(_shoppingItems);
  }

  @override
  Future<ShoppingItem> addShoppingItem(
    CreateShoppingItemDto dto, {
    required String idempotencyKey,
  }) async {
    await _checkPreconditions();

    final replayed = _checkIdempotency<ShoppingItem>(idempotencyKey, dto.toJson());
    if (replayed != null) return replayed;

    if (dto.title.trim().isEmpty) {
      throw const AppFailure(
        code: 'INVALID_TITLE',
        message: 'Item title cannot be empty.',
        fields: [FieldViolation(field: 'title', issue: 'Required')],
      );
    }

    if (!AppConstants.validUnits.contains(dto.unit)) {
      throw AppFailure(
        code: 'INVALID_UNIT',
        message: 'Unit must be one of: ${AppConstants.validUnits.join(", ")}.',
        fields: const [FieldViolation(field: 'unit', issue: 'Invalid unit')],
      );
    }

    if (dto.requestedQty <= 0) {
      throw const AppFailure(
        code: 'INVALID_QUANTITY',
        message: 'Quantity must be greater than zero.',
        fields: [FieldViolation(field: 'requested_qty', issue: 'Must be > 0')],
      );
    }

    final newItem = ShoppingItem(
      id: _nextShoppingItemId++,
      title: dto.title.trim(),
      unit: dto.unit,
      requestedQty: dto.requestedQty,
      status: 'pending',
    );

    _shoppingItems.insert(0, newItem);
    _storeIdempotency(idempotencyKey, dto.toJson(), newItem);
    return newItem;
  }

  @override
  Future<Expense> checkoutShopping(
    CheckoutRequestDto dto, {
    required String idempotencyKey,
  }) async {
    await _checkPreconditions();

    final replayed = _checkIdempotency<Expense>(idempotencyKey, dto.toJson());
    if (replayed != null) return replayed;

    // ATOMIC VALIDATION: Validate everything first, mutate nothing on failure!
    if (dto.itemIds.isEmpty) {
      throw const AppFailure(
        code: 'EMPTY_CART',
        message: 'Select at least one item to checkout.',
        fields: [FieldViolation(field: 'item_ids', issue: 'Cannot be empty')],
      );
    }

    final selectedItems = <ShoppingItem>[];
    for (final id in dto.itemIds) {
      final item = _shoppingItems.firstWhere(
        (i) => i.id == id,
        orElse: () => throw AppFailure(
          code: 'ITEM_NOT_FOUND',
          message: 'Item with ID $id was not found.',
          fields: [FieldViolation(field: 'item_ids', issue: 'ID $id not found')],
        ),
      );

      if (item.status == 'bought') {
        throw const AppFailure(
          code: 'ITEM_ALREADY_BOUGHT',
          message: 'One or more items have already been bought.',
          fields: [FieldViolation(field: 'item_ids', issue: 'Already bought')],
        );
      }
      selectedItems.add(item);
    }

    final totalMoney = Money.parse(dto.totalPaid);

    if (!_members.any((m) => m.id == dto.payerId)) {
      throw const AppFailure(
        code: 'INVALID_PAYER',
        message: 'Payer does not exist in household.',
        fields: [FieldViolation(field: 'payer_id', issue: 'Unknown member')],
      );
    }

    if (dto.splitMembers.isEmpty) {
      throw const AppFailure(
        code: 'EMPTY_SPLIT_MEMBERS',
        message: 'Must split among at least one member.',
        fields: [FieldViolation(field: 'split_members', issue: 'Required')],
      );
    }

    // MUTATION PHASE: All validations passed!
    // 1. Tag items as bought
    for (int i = 0; i < _shoppingItems.length; i++) {
      if (dto.itemIds.contains(_shoppingItems[i].id)) {
        _shoppingItems[i] = _shoppingItems[i].copyWith(status: 'bought');
      }
    }

    // 2. Compute shares with numerical member ID sorting
    final shares = SplitPreviewCalculator.previewEqualSplit(
      totalPaisa: totalMoney.paisa,
      memberIds: dto.splitMembers,
    );

    _memberPaidPaisa[dto.payerId] =
        (_memberPaidPaisa[dto.payerId] ?? 0) + totalMoney.paisa;

    final splitList = <ExpenseSplitShare>[];
    shares.forEach((memberId, sharePaisa) {
      _memberShareOwedPaisa[memberId] =
          (_memberShareOwedPaisa[memberId] ?? 0) + sharePaisa;
      splitList.add(ExpenseSplitShare(
        memberId: memberId,
        share: Money.fromPaisa(sharePaisa).toJsonString(),
        sharePaisa: sharePaisa,
      ));
    });

    final itemRefs = selectedItems
        .map((i) => CheckoutItemRef(id: i.id, title: i.title, status: 'bought'))
        .toList();

    final itemTitles = selectedItems.map((i) => i.title).join(', ');
    final title = 'Grocery Trip ($itemTitles)';

    final newExpense = Expense(
      id: _nextExpenseId++,
      title: title.length > 50 ? '${title.substring(0, 47)}...' : title,
      category: 'Groceries',
      amount: totalMoney.toJsonString(),
      amountPaisa: totalMoney.paisa,
      payerId: dto.payerId,
      splitType: 'equal',
      date: DateTime.now().toIso8601String().substring(0, 10),
      source: 'checkout',
      splits: splitList,
      items: itemRefs,
    );

    _expenses.insert(0, newExpense);
    _storeIdempotency(idempotencyKey, dto.toJson(), newExpense);
    return newExpense;
  }

  @override
  Future<List<Expense>> getExpenses() async {
    await _checkPreconditions();
    return List.unmodifiable(_expenses);
  }

  @override
  Future<Expense> addExpense(
    CreateExpenseDto dto, {
    required String idempotencyKey,
  }) async {
    await _checkPreconditions();

    final replayed = _checkIdempotency<Expense>(idempotencyKey, dto.toJson());
    if (replayed != null) return replayed;

    if (dto.title.trim().isEmpty) {
      throw const AppFailure(
        code: 'INVALID_TITLE',
        message: 'Expense title cannot be empty.',
        fields: [FieldViolation(field: 'title', issue: 'Required')],
      );
    }

    final totalMoney = Money.parse(dto.amount);

    if (!_members.any((m) => m.id == dto.payerId)) {
      throw const AppFailure(
        code: 'INVALID_PAYER',
        message: 'Payer does not exist in household.',
        fields: [FieldViolation(field: 'payer_id', issue: 'Unknown member')],
      );
    }

    final shares = <String, int>{};
    if (dto.splitType == 'equal') {
      final members = dto.equalMemberIds ?? _members.map((m) => m.id).toList();
      shares.addAll(SplitPreviewCalculator.previewEqualSplit(
        totalPaisa: totalMoney.paisa,
        memberIds: members,
      ));
    } else if (dto.splitType == 'custom') {
      if (dto.customSplits == null || dto.customSplits!.isEmpty) {
        throw const AppFailure(
          code: 'EMPTY_CUSTOM_SPLITS',
          message: 'Custom split must define allocations.',
          fields: [FieldViolation(field: 'splits', issue: 'Required')],
        );
      }

      int sumCustomPaisa = 0;
      for (final split in dto.customSplits!) {
        final shareMoney = Money.parse(split.amount);
        shares[split.memberId] = shareMoney.paisa;
        sumCustomPaisa += shareMoney.paisa;
      }

      if (sumCustomPaisa != totalMoney.paisa) {
        throw AppFailure(
          code: 'SPLIT_SUM_MISMATCH',
          message: 'Sum of custom allocations (${Money.fromPaisa(sumCustomPaisa).format()}) does not match total amount (${totalMoney.format()}).',
          fields: const [FieldViolation(field: 'splits', issue: 'Sum mismatch')],
        );
      }
    } else {
      throw const AppFailure(
        code: 'INVALID_SPLIT_TYPE',
        message: 'split_type must be equal or custom.',
        fields: [FieldViolation(field: 'split_type', issue: 'Invalid')],
      );
    }

    // MUTATION
    _memberPaidPaisa[dto.payerId] =
        (_memberPaidPaisa[dto.payerId] ?? 0) + totalMoney.paisa;

    final splitList = <ExpenseSplitShare>[];
    shares.forEach((memberId, sharePaisa) {
      _memberShareOwedPaisa[memberId] =
          (_memberShareOwedPaisa[memberId] ?? 0) + sharePaisa;
      splitList.add(ExpenseSplitShare(
        memberId: memberId,
        share: Money.fromPaisa(sharePaisa).toJsonString(),
        sharePaisa: sharePaisa,
      ));
    });

    final newExpense = Expense(
      id: _nextExpenseId++,
      title: dto.title.trim(),
      category: dto.category.trim().isEmpty ? 'General' : dto.category.trim(),
      amount: totalMoney.toJsonString(),
      amountPaisa: totalMoney.paisa,
      payerId: dto.payerId,
      splitType: dto.splitType,
      date: dto.date ?? DateTime.now().toIso8601String().substring(0, 10),
      source: 'manual',
      splits: splitList,
    );

    _expenses.insert(0, newExpense);
    _storeIdempotency(idempotencyKey, dto.toJson(), newExpense);
    return newExpense;
  }

  @override
  Future<BalancesResponse> getBalances() async {
    await _checkPreconditions();
    return _computeBalancesResponse();
  }

  BalancesResponse _computeBalancesResponse() {
    int totalNetPaisa = 0;
    final list = <MemberBalance>[];

    for (final member in _members) {
      final paid = _memberPaidPaisa[member.id] ?? 0;
      final owed = _memberShareOwedPaisa[member.id] ?? 0;
      final rec = _memberSettlementsReceivedPaisa[member.id] ?? 0;
      final sent = _memberSettlementsSentPaisa[member.id] ?? 0;

      // Net Balance = Paid - Share Owed + Settlements Sent - Settlements Received
      // Sent settlements reduce debt; received settlements reduce credit
      final net = paid - owed + sent - rec;
      totalNetPaisa += net;

      String status = 'settled';
      if (net > 0) {
        status = 'owed'; // member is owed money (receivable)
      } else if (net < 0) {
        status = 'owes'; // member owes money to flat
      }

      list.add(MemberBalance(
        memberId: member.id,
        name: member.name,
        totalPaid: Money.fromPaisa(paid).toJsonString(),
        shareOwed: Money.fromPaisa(owed).toJsonString(),
        settlementsReceived: Money.fromPaisa(rec).toJsonString(),
        settlementsSent: Money.fromPaisa(sent).toJsonString(),
        netBalance: Money.fromPaisa(net.abs()).toJsonString(),
        netBalancePaisa: net,
        status: status,
      ));
    }

    return BalancesResponse(
      balances: list,
      sum: Money.fromPaisa(totalNetPaisa).toJsonString(),
      sumPaisa: totalNetPaisa,
    );
  }

  @override
  Future<SettlementResult> recordSettlement(
    SettlementRequestDto dto, {
    required String idempotencyKey,
  }) async {
    await _checkPreconditions();

    final replayed = _checkIdempotency<SettlementResult>(idempotencyKey, dto.toJson());
    if (replayed != null) return replayed;

    // STRICT VALIDATION ORDER EVERYWHERE (Rule 6):
    // 1. amount > 0
    final money = Money.parse(dto.amount);
    final settlePaisa = money.paisa;
    if (settlePaisa <= 0) {
      throw const AppFailure(
        code: 'INVALID_AMOUNT',
        message: 'Settlement amount must be positive.',
        fields: [FieldViolation(field: 'amount', issue: 'Must be > 0')],
      );
    }

    // 2. sender != recipient
    if (dto.senderId == dto.recipientId) {
      throw const AppFailure(
        code: 'SELF_SETTLEMENT',
        message: 'Sender and recipient cannot be the same member.',
        fields: [FieldViolation(field: 'recipient_id', issue: 'Self-settlement forbidden')],
      );
    }

    final sender = _members.firstWhere(
      (m) => m.id == dto.senderId,
      orElse: () => throw const AppFailure(code: 'INVALID_SENDER', message: 'Sender not found'),
    );
    final recipient = _members.firstWhere(
      (m) => m.id == dto.recipientId,
      orElse: () => throw const AppFailure(code: 'INVALID_RECIPIENT', message: 'Recipient not found'),
    );

    final currentBalances = _computeBalancesResponse();
    final senderBalance = currentBalances.balances.firstWhere((b) => b.memberId == sender.id);
    final recipientBalance = currentBalances.balances.firstWhere((b) => b.memberId == recipient.id);

    // Sender must owe money (netBalancePaisa < 0)
    final senderDebtPaisa = senderBalance.netBalancePaisa < 0 ? senderBalance.netBalancePaisa.abs() : 0;
    // Recipient must be owed money (netBalancePaisa > 0)
    final recipientCreditPaisa = recipientBalance.netBalancePaisa > 0 ? recipientBalance.netBalancePaisa : 0;

    // 3. sender debt (SETTLE_EXCEEDS_DEBT) -> evaluated before credit per Rule 6
    if (settlePaisa > senderDebtPaisa) {
      throw AppFailure(
        code: 'SETTLE_EXCEEDS_DEBT',
        message: 'Settlement amount of ${money.format()} exceeds sender debt of ${Money.fromPaisa(senderDebtPaisa).format()}.',
        fields: const [FieldViolation(field: 'amount', issue: 'Exceeds debtor balance')],
      );
    }

    // 4. recipient credit (SETTLE_EXCEEDS_CREDIT)
    if (settlePaisa > recipientCreditPaisa) {
      throw AppFailure(
        code: 'SETTLE_EXCEEDS_CREDIT',
        message: 'Settlement amount of ${money.format()} exceeds recipient credit of ${Money.fromPaisa(recipientCreditPaisa).format()}.',
        fields: const [FieldViolation(field: 'amount', issue: 'Exceeds creditor receivable')],
      );
    }

    // MUTATION: Apply settlement
    // Settlements transfer money directly without altering total household spending!
    _memberSettlementsSentPaisa[dto.senderId] =
        (_memberSettlementsSentPaisa[dto.senderId] ?? 0) + settlePaisa;
    _memberSettlementsReceivedPaisa[dto.recipientId] =
        (_memberSettlementsReceivedPaisa[dto.recipientId] ?? 0) + settlePaisa;

    final updatedBalances = _computeBalancesResponse();
    final settlementRecord = {
      'sender_id': dto.senderId,
      'recipient_id': dto.recipientId,
      'amount': money.toJsonString(),
      'amount_paisa': settlePaisa,
      'date': DateTime.now().toIso8601String().substring(0, 10),
    };

    final result = SettlementResult(
      settlement: settlementRecord,
      balances: updatedBalances,
    );

    _storeIdempotency(idempotencyKey, dto.toJson(), result);
    return result;
  }

  @override
  Future<BudgetSummary> getBudgetSummary() async {
    await _checkPreconditions();

    // Spending is scoped strictly to current month expenses (settlements NEVER alter spending)
    int spentPaisa = 0;
    for (final exp in _expenses) {
      spentPaisa += exp.amountPaisa;
    }

    final limitPaisa = AppConstants.defaultMonthlyBudgetPaisa; // 500,000 paisa (PKR 5,000.00)
    final remainingPaisa = limitPaisa - spentPaisa;
    final percent = ((spentPaisa / limitPaisa) * 100).round();

    String status = 'on_track';
    if (percent >= 100) {
      status = 'over_budget';
    } else if (percent >= 80) {
      status = 'near_limit';
    }

    return BudgetSummary(
      month: 'November 2026',
      spent: Money.fromPaisa(spentPaisa).toJsonString(),
      spentPaisa: spentPaisa,
      limit: Money.fromPaisa(limitPaisa).toJsonString(),
      limitPaisa: limitPaisa,
      remaining: Money.fromPaisa(remainingPaisa < 0 ? 0 : remainingPaisa).toJsonString(),
      remainingPaisa: remainingPaisa < 0 ? 0 : remainingPaisa,
      percent: percent,
      status: status,
    );
  }

  @override
  Future<DashboardResponse> getDashboard({required String memberId}) async {
    await _checkPreconditions();

    final budget = await getBudgetSummary();
    final balances = _computeBalancesResponse();

    final memberBalance = balances.balances.firstWhere(
      (b) => b.memberId == memberId,
      orElse: () => throw AppFailure(
        code: 'MEMBER_NOT_FOUND',
        message: 'Member $memberId not found',
      ),
    );

    // Exact dashboard message formatting per specification:
    // "You are owed PKR 250.00", "You owe PKR 450.00", "You are all settled up"
    String message;
    if (memberBalance.netBalancePaisa > 0) {
      message = 'You are owed ${Money.fromPaisa(memberBalance.netBalancePaisa).format()}';
    } else if (memberBalance.netBalancePaisa < 0) {
      message = 'You owe ${Money.fromPaisa(memberBalance.netBalancePaisa.abs()).format()}';
    } else {
      message = 'You are all settled up';
    }

    final pendingCount = _shoppingItems.where((i) => i.status == 'pending').length;

    return DashboardResponse(
      month: budget.month,
      spent: budget.spent,
      spentPaisa: budget.spentPaisa,
      limit: budget.limit,
      limitPaisa: budget.limitPaisa,
      remaining: budget.remaining,
      remainingPaisa: budget.remainingPaisa,
      percent: budget.percent,
      status: budget.status,
      member: DashboardMemberSummary(
        id: memberBalance.memberId,
        name: memberBalance.name,
        netBalancePaisa: memberBalance.netBalancePaisa,
        message: message,
      ),
      pendingItemsCount: pendingCount,
    );
  }
}
