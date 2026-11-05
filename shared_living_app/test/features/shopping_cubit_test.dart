import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/shared_living/data/models/checkout_request_dto.dart';
import 'package:shared_living_app/features/shared_living/data/models/shopping_item.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';
import 'package:shared_living_app/features/shopping/presentation/cubit/shopping_cubit.dart';
import 'package:shared_living_app/features/shopping/presentation/cubit/shopping_state.dart';

void main() {
  late MockSharedLivingRepository repository;

  setUp(() {
    repository = MockSharedLivingRepository(latency: Duration.zero);
  });

  group('ShoppingCubit Tests', () {
    test('Loads shopping items and filters pending vs bought', () async {
      final cubit = ShoppingCubit(repository: repository);

      await cubit.loadShopping();
      final state = cubit.state as ShoppingLoaded;

      expect(state.pendingItems.length, 3);
      expect(state.boughtItems.length, 1);
      cubit.close();
    });

    test('Toggling item selection modifies selectedItemIds', () async {
      final cubit = ShoppingCubit(repository: repository);
      await cubit.loadShopping();

      cubit.toggleItemSelection(1);
      expect((cubit.state as ShoppingLoaded).selectedItemIds, {1});

      cubit.toggleItemSelection(2);
      expect((cubit.state as ShoppingLoaded).selectedItemIds, {1, 2});

      cubit.toggleItemSelection(1);
      expect((cubit.state as ShoppingLoaded).selectedItemIds, {2});

      cubit.clearSelection();
      expect((cubit.state as ShoppingLoaded).selectedItemIds, isEmpty);
      cubit.close();
    });

    test('AddItem inserts new shopping item', () async {
      final cubit = ShoppingCubit(repository: repository);
      await cubit.loadShopping();

      const dto = CreateShoppingItemDto(
        title: 'Fresh Bread',
        unit: 'pack',
        requestedQty: 1,
      );

      final success = await cubit.addItem(dto, idempotencyKey: 'key_add_item_1');
      expect(success, true);

      final state = cubit.state as ShoppingLoaded;
      expect(state.items.first.title, 'Fresh Bread');
      expect(state.actionSuccessMessage, isNotNull);
      cubit.close();
    });

    test('Checkout converts selected items into shared expense and clears selection', () async {
      final cubit = ShoppingCubit(repository: repository);
      await cubit.loadShopping();

      cubit.toggleItemSelection(1);
      cubit.toggleItemSelection(2);

      const dto = CheckoutRequestDto(
        itemIds: [1, 2],
        totalPaid: '780.00',
        payerId: 'M01',
        splitMembers: ['M01', 'M02', 'M03'],
      );

      final success = await cubit.checkout(dto, idempotencyKey: 'key_checkout_1');
      expect(success, true);

      final state = cubit.state as ShoppingLoaded;
      expect(state.selectedItemIds, isEmpty);
      expect(state.pendingItems.any((i) => i.id == 1), false); // Item 1 is now bought!
      cubit.close();
    });
  });
}
