import 'package:dio/dio.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/repositories/shared_living_repository.dart';
import '../models/balances_response.dart';
import '../models/budget_and_dashboard.dart';
import '../models/checkout_request_dto.dart';
import '../models/expense.dart';
import '../models/member.dart';
import '../models/shopping_item.dart';

class ApiSharedLivingRepository implements SharedLivingRepository {
  final Dio dio;

  ApiSharedLivingRepository({required this.dio});

  Future<void> _autoJoinHouseholdIfOrphaned() async {
    try {
      await dio.post(
        '/api/households/join',
        data: {'invite_code': 'LAHORE2026'},
      );
    } catch (_) {
      try {
        await dio.post(
          '/api/households',
          data: {'name': 'Gulberg 4B Apartment'},
        );
      } catch (_) {}
    }
  }

  bool _isMissingHousehold(DioException e) {
    if (e.response?.statusCode == 404 && e.response?.data is Map) {
      final detail = e.response!.data['detail']?.toString().toLowerCase() ?? '';
      return detail.contains('household');
    }
    return false;
  }

  @override
  Future<List<Member>> getMembers() async {
    try {
      final response = await dio.get('/api/members');
      final list = response.data as List<dynamic>;
      return list.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isMissingHousehold(e)) {
        await _autoJoinHouseholdIfOrphaned();
        try {
          final retry = await dio.get('/api/members');
          final list = retry.data as List<dynamic>;
          return list.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'FETCH_MEMBERS_FAILED', message: e.toString());
    }
  }

  @override
  Future<List<ShoppingItem>> getShopping() async {
    try {
      final response = await dio.get('/api/shopping');
      final list = response.data as List<dynamic>;
      return list.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      if (_isMissingHousehold(e)) {
        await _autoJoinHouseholdIfOrphaned();
        try {
          final retry = await dio.get('/api/shopping');
          final list = retry.data as List<dynamic>;
          return list.map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'FETCH_SHOPPING_FAILED', message: e.toString());
    }
  }

  @override
  Future<ShoppingItem> addShoppingItem(
    CreateShoppingItemDto dto, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await dio.post(
        '/api/shopping',
        data: dto.toJson(),
        options: Options(
          headers: {
            if (idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      return ShoppingItem.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'ADD_SHOPPING_ITEM_FAILED', message: e.toString());
    }
  }

  @override
  Future<Expense> checkoutShopping(
    CheckoutRequestDto dto, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await dio.post(
        '/api/shopping/checkout',
        data: dto.toJson(),
        options: Options(
          headers: {
            if (idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      return Expense.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'CHECKOUT_FAILED', message: e.toString());
    }
  }

  @override
  Future<List<Expense>> getExpenses() async {
    try {
      final response = await dio.get('/api/expenses');
      final list = response.data as List<dynamic>;
      return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'FETCH_EXPENSES_FAILED', message: e.toString());
    }
  }

  @override
  Future<Expense> addExpense(
    CreateExpenseDto dto, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await dio.post(
        '/api/expenses',
        data: dto.toJson(),
        options: Options(
          headers: {
            if (idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      return Expense.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'ADD_EXPENSE_FAILED', message: e.toString());
    }
  }

  @override
  Future<BalancesResponse> getBalances() async {
    try {
      final response = await dio.get('/api/balances');
      return BalancesResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (_isMissingHousehold(e)) {
        await _autoJoinHouseholdIfOrphaned();
        try {
          final retry = await dio.get('/api/balances');
          return BalancesResponse.fromJson(retry.data as Map<String, dynamic>);
        } catch (_) {}
      }
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'FETCH_BALANCES_FAILED', message: e.toString());
    }
  }

  @override
  Future<SettlementResult> recordSettlement(
    SettlementRequestDto dto, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await dio.post(
        '/api/settle',
        data: dto.toJson(),
        options: Options(
          headers: {
            if (idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
          },
        ),
      );

      final updatedBalances = await getBalances();
      return SettlementResult(
        settlement: response.data as Map<String, dynamic>,
        balances: updatedBalances,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'SETTLEMENT_FAILED', message: e.toString());
    }
  }

  @override
  Future<BudgetSummary> getBudgetSummary() async {
    try {
      final response = await dio.get('/api/budget/summary');
      return BudgetSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'FETCH_BUDGET_FAILED', message: e.toString());
    }
  }

  @override
  Future<DashboardResponse> getDashboard({required String memberId}) async {
    try {
      final response = await dio.get(
        '/api/dashboard',
        queryParameters: {'member_id': memberId},
      );
      return DashboardResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (_isMissingHousehold(e)) {
        await _autoJoinHouseholdIfOrphaned();
        try {
          final retry = await dio.get(
            '/api/dashboard',
            queryParameters: {'member_id': memberId},
          );
          return DashboardResponse.fromJson(retry.data as Map<String, dynamic>);
        } catch (_) {}
      }
      _handleDioError(e);
    } catch (e) {
      throw AppFailure(code: 'FETCH_DASHBOARD_FAILED', message: e.toString());
    }
  }

  Never _handleDioError(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      throw AppFailure.fromJson(e.response!.data as Map<String, dynamic>);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw const AppFailure(
        code: 'NETWORK_TIMEOUT',
        message: 'Connection timed out. Please check your internet connection.',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      throw const AppFailure(
        code: 'NETWORK_UNREACHABLE',
        message: 'Unable to connect to the Hisab server. Please verify the server is running.',
      );
    }

    throw AppFailure(
      code: 'HTTP_ERROR_${e.response?.statusCode ?? 500}',
      message: e.message ?? 'An unexpected network error occurred.',
    );
  }
}

