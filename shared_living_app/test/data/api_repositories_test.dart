import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/errors/app_failure.dart';
import 'package:shared_living_app/features/auth/data/api_auth_repository.dart';
import 'package:shared_living_app/features/auth/data/token_storage.dart';
import 'package:shared_living_app/features/shared_living/data/models/checkout_request_dto.dart';
import 'package:shared_living_app/features/shared_living/data/models/shopping_item.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/api_shared_living_repository.dart';

class _MockAdapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiAuthRepository & ApiSharedLivingRepository Tests', () {
    late Dio mainDio;
    late Dio refreshDio;
    late _MockAdapter adapter;
    late TokenStorage tokenStorage;
    late ApiAuthRepository authRepo;
    late ApiSharedLivingRepository sharedRepo;

    setUp(() {
      mainDio = Dio(BaseOptions(baseUrl: 'http://test'));
      refreshDio = Dio(BaseOptions(baseUrl: 'http://test'));
      adapter = _MockAdapter();
      mainDio.httpClientAdapter = adapter;
      refreshDio.httpClientAdapter = adapter;
      tokenStorage = TokenStorage(inMemoryOnly: true);

      authRepo = ApiAuthRepository(
        dio: mainDio,
        refreshDio: refreshDio,
        tokenStorage: tokenStorage,
      );
      sharedRepo = ApiSharedLivingRepository(dio: mainDio);
    });

    test('ApiAuthRepository.login stores tokens and returns them', () async {
      adapter.handler = (options) {
        if (options.path == '/api/auth/login') {
          return ResponseBody.fromString(
            jsonEncode({
              'access_token': 'mock_access',
              'refresh_token': 'mock_refresh',
              'token_type': 'bearer',
              'expires_in': 900,
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            },
          );
        } else if (options.path == '/api/auth/me') {
          return ResponseBody.fromString(
            jsonEncode({
              'user': {'id': 'U1', 'email': 'ali@demo.pk', 'display_name': 'Ali'},
              'member': {'id': 'M01', 'name': 'Ali', 'role': 'owner'},
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            },
          );
        }
        return ResponseBody.fromString('Not Found', 404);
      };

      final tokens = await authRepo.login('ali@demo.pk', 'password123');
      expect(tokens.accessToken, 'mock_access');
      expect(tokens.refreshToken, 'mock_refresh');

      final savedToken = await tokenStorage.getAccessToken();
      expect(savedToken, 'mock_access');
    });

    test('ApiAuthRepository.login handles 401 INVALID_CREDENTIALS', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Invalid credentials.'}
          }),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      };

      expect(
        () => authRepo.login('ali@demo.pk', 'wrongpass'),
        throwsA(isA<AppFailure>().having((f) => f.code, 'code', 'INVALID_CREDENTIALS')),
      );
    });

    test('ApiSharedLivingRepository.getMembers returns members list', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode([
            {'id': 'M01', 'name': 'Ali'},
            {'id': 'M02', 'name': 'Ayesha'},
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      };

      final members = await sharedRepo.getMembers();
      expect(members.length, 2);
      expect(members[0].id, 'M01');
      expect(members[0].name, 'Ali');
      expect(members[1].name, 'Ayesha');
    });

    test('ApiSharedLivingRepository.addShoppingItem sends idempotency key', () async {
      String? sentIdempKey;
      adapter.handler = (options) {
        sentIdempKey = options.headers['Idempotency-Key'];
        return ResponseBody.fromString(
          jsonEncode({
            'id': 10,
            'title': 'Milk',
            'unit': 'pack',
            'requested_qty': 2,
            'status': 'pending',
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      };

      final item = await sharedRepo.addShoppingItem(
        const CreateShoppingItemDto(title: 'Milk', unit: 'pack', requestedQty: 2),
        idempotencyKey: 'test-key-123',
      );

      expect(sentIdempKey, 'test-key-123');
      expect(item.id, 10);
      expect(item.title, 'Milk');
    });

    test('ApiSharedLivingRepository.checkoutShopping executes atomic checkout', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'id': 101,
            'title': 'Checkout 2 items',
            'category': 'Groceries',
            'amount': 500.0,
            'amount_paisa': 50000,
            'payer_id': 'M01',
            'split_type': 'equal',
            'expense_date': '2026-11-05',
            'source': 'checkout',
            'splits': [
              {'member_id': 'M01', 'amount': 250.0, 'amount_paisa': 25000},
              {'member_id': 'M02', 'amount': 250.0, 'amount_paisa': 25000},
            ],
            'items': [
              {'id': 1, 'title': 'Milk', 'status': 'bought'},
            ]
          }),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      };

      final expense = await sharedRepo.checkoutShopping(
        const CheckoutRequestDto(
          itemIds: [1],
          totalPaid: '500.00',
          payerId: 'M01',
          splitMembers: ['M01', 'M02'],
        ),
        idempotencyKey: 'idemp-checkout-1',
      );

      expect(expense.id, 101);
      expect(expense.source, 'checkout');
      expect(expense.splits.length, 2);
    });

    test('ApiSharedLivingRepository.getBalances parses members and amounts correctly', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'household_total_spending': 5000.0,
            'household_total_spending_paisa': 500000,
            'members': [
              {
                'member_id': 'M01',
                'name': 'Ali',
                'paid': 3000.0,
                'paid_paisa': 300000,
                'owed': 2500.0,
                'owed_paisa': 250000,
                'net_balance': 500.0,
                'net_balance_paisa': 50000,
                'status': 'owed',
              },
            ],
            'is_balanced': true,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      };

      final balances = await sharedRepo.getBalances();
      expect(balances.balances.length, 1);
      expect(balances.balances[0].name, 'Ali');
      expect(balances.balances[0].netBalancePaisa, 50000);
      expect(balances.balances[0].status, 'owed');
    });

    test('ApiSharedLivingRepository.getDashboard parses complete dashboard payload', () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'month': '2026-11',
            'spent': 4200.0,
            'spent_paisa': 420000,
            'limit': 5000.0,
            'limit_paisa': 500000,
            'remaining': 800.0,
            'remaining_paisa': 80000,
            'percent': 84,
            'status': 'near_limit',
            'member': {
              'id': 'M01',
              'name': 'Ali',
              'net_balance': 250.0,
              'net_balance_paisa': 25000,
              'message': 'You are owed PKR 250.00',
            },
            'pending_items_count': 3,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      };

      final dashboard = await sharedRepo.getDashboard(memberId: 'M01');
      expect(dashboard.month, '2026-11');
      expect(dashboard.percent, 84);
      expect(dashboard.member.message, 'You are owed PKR 250.00');
      expect(dashboard.pendingItemsCount, 3);
    });
  });
}
