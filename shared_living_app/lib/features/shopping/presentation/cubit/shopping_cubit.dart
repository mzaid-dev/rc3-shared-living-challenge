import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../shared_living/data/models/checkout_request_dto.dart';
import '../../../shared_living/data/models/shopping_item.dart';
import '../../../shared_living/domain/repositories/shared_living_repository.dart';
import 'shopping_state.dart';

class ShoppingCubit extends Cubit<ShoppingState> {
  final SharedLivingRepository repository;

  ShoppingCubit({required this.repository}) : super(const ShoppingInitial());

  Future<void> loadShopping() async {
    emit(const ShoppingLoading());
    try {
      final items = await repository.getShopping();
      emit(ShoppingLoaded(items: items));
    } on AppFailure catch (f) {
      emit(ShoppingError(message: f.message));
    } catch (e) {
      emit(ShoppingError(message: e.toString()));
    }
  }

  void toggleItemSelection(int id) {
    if (state is ShoppingLoaded) {
      final current = state as ShoppingLoaded;
      final newSelected = Set<int>.from(current.selectedItemIds);
      if (newSelected.contains(id)) {
        newSelected.remove(id);
      } else {
        newSelected.add(id);
      }
      emit(current.copyWith(selectedItemIds: newSelected, clearMessages: true));
    }
  }

  void clearSelection() {
    if (state is ShoppingLoaded) {
      emit((state as ShoppingLoaded).copyWith(selectedItemIds: {}, clearMessages: true));
    }
  }

  Future<bool> addItem(
    CreateShoppingItemDto dto, {
    required String idempotencyKey,
  }) async {
    if (state is! ShoppingLoaded) return false;
    final current = state as ShoppingLoaded;
    if (current.isSubmitting) return false;

    emit(current.copyWith(isSubmitting: true, clearMessages: true));
    try {
      final newItem = await repository.addShoppingItem(dto, idempotencyKey: idempotencyKey);
      final updatedList = [newItem, ...current.items];
      emit(current.copyWith(
        items: updatedList,
        isSubmitting: false,
        actionSuccessMessage: 'Added "${newItem.title}" to shopping list.',
      ));
      return true;
    } on AppFailure catch (f) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: f.message));
      return false;
    } catch (e) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: e.toString()));
      return false;
    }
  }

  Future<bool> checkout(
    CheckoutRequestDto dto, {
    required String idempotencyKey,
  }) async {
    if (state is! ShoppingLoaded) return false;
    final current = state as ShoppingLoaded;
    if (current.isSubmitting) return false;

    emit(current.copyWith(isSubmitting: true, clearMessages: true));
    try {
      final expense = await repository.checkoutShopping(dto, idempotencyKey: idempotencyKey);
      final refreshedItems = await repository.getShopping();
      emit(current.copyWith(
        items: refreshedItems,
        selectedItemIds: {},
        isSubmitting: false,
        actionSuccessMessage: 'Checkout complete! Logged "${expense.title}" for PKR ${expense.amount}.',
      ));
      return true;
    } on AppFailure catch (f) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: f.message));
      return false;
    } catch (e) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: e.toString()));
      return false;
    }
  }
}
