import 'package:equatable/equatable.dart';
import '../../../shared_living/data/models/shopping_item.dart';

abstract class ShoppingState extends Equatable {
  const ShoppingState();

  @override
  List<Object?> get props => [];
}

class ShoppingInitial extends ShoppingState {
  const ShoppingInitial();
}

class ShoppingLoading extends ShoppingState {
  const ShoppingLoading();
}

class ShoppingLoaded extends ShoppingState {
  final List<ShoppingItem> items;
  final Set<int> selectedItemIds;
  final bool isSubmitting;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;

  const ShoppingLoaded({
    required this.items,
    this.selectedItemIds = const {},
    this.isSubmitting = false,
    this.actionSuccessMessage,
    this.actionErrorMessage,
  });

  List<ShoppingItem> get pendingItems =>
      items.where((i) => i.status == 'pending').toList();

  List<ShoppingItem> get boughtItems =>
      items.where((i) => i.status == 'bought').toList();

  List<ShoppingItem> get selectedItems =>
      items.where((i) => selectedItemIds.contains(i.id)).toList();

  ShoppingLoaded copyWith({
    List<ShoppingItem>? items,
    Set<int>? selectedItemIds,
    bool? isSubmitting,
    String? actionSuccessMessage,
    String? actionErrorMessage,
    bool clearMessages = false,
  }) {
    return ShoppingLoaded(
      items: items ?? this.items,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionSuccessMessage:
          clearMessages ? null : (actionSuccessMessage ?? this.actionSuccessMessage),
      actionErrorMessage:
          clearMessages ? null : (actionErrorMessage ?? this.actionErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        items,
        selectedItemIds,
        isSubmitting,
        actionSuccessMessage,
        actionErrorMessage,
      ];
}

class ShoppingError extends ShoppingState {
  final String message;

  const ShoppingError({required this.message});

  @override
  List<Object?> get props => [message];
}
