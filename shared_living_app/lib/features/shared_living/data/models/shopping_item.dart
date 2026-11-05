import 'package:equatable/equatable.dart';

class ShoppingItem extends Equatable {
  final int id; // int ID
  final String title;
  final String unit; // 'pack', 'dozen', 'bottle', 'bag'
  final int requestedQty;
  final String status; // 'pending' | 'bought'

  const ShoppingItem({
    required this.id,
    required this.title,
    required this.unit,
    required this.requestedQty,
    required this.status,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as int,
      title: json['title'] as String,
      unit: json['unit'] as String,
      requestedQty: json['requested_qty'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'unit': unit,
        'requested_qty': requestedQty,
        'status': status,
      };

  ShoppingItem copyWith({
    int? id,
    String? title,
    String? unit,
    int? requestedQty,
    String? status,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      unit: unit ?? this.unit,
      requestedQty: requestedQty ?? this.requestedQty,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, title, unit, requestedQty, status];
}

class CreateShoppingItemDto extends Equatable {
  final String title;
  final String unit;
  final int requestedQty;

  const CreateShoppingItemDto({
    required this.title,
    required this.unit,
    required this.requestedQty,
  });

  factory CreateShoppingItemDto.fromJson(Map<String, dynamic> json) {
    return CreateShoppingItemDto(
      title: json['title'] as String,
      unit: json['unit'] as String,
      requestedQty: json['requested_qty'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'unit': unit,
        'requested_qty': requestedQty,
      };

  @override
  List<Object?> get props => [title, unit, requestedQty];
}
