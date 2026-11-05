import 'package:equatable/equatable.dart';

/// Lightweight item reference embedded within Expense records.
/// Note: Do not reuse ShoppingItem here per Rule 5.
class CheckoutItemRef extends Equatable {
  final int id;
  final String title;
  final String status;

  const CheckoutItemRef({
    required this.id,
    required this.title,
    required this.status,
  });

  factory CheckoutItemRef.fromJson(Map<String, dynamic> json) {
    return CheckoutItemRef(
      id: json['id'] as int,
      title: json['title'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
      };

  @override
  List<Object?> get props => [id, title, status];
}
