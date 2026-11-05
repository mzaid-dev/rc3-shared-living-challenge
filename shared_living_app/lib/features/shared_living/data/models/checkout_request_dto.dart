import 'package:equatable/equatable.dart';

class CheckoutRequestDto extends Equatable {
  final List<int> itemIds;
  final String totalPaid; // 2-decimal string (e.g. "780.00")
  final String payerId; // "M01"
  final List<String> splitMembers; // ["M01", "M02", "M03"]

  const CheckoutRequestDto({
    required this.itemIds,
    required this.totalPaid,
    required this.payerId,
    required this.splitMembers,
  });

  factory CheckoutRequestDto.fromJson(Map<String, dynamic> json) {
    return CheckoutRequestDto(
      itemIds: (json['item_ids'] as List<dynamic>).map((e) => e as int).toList(),
      totalPaid: json['total_paid'] as String,
      payerId: json['payer_id'] as String,
      splitMembers: (json['split_members'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_ids': itemIds,
        'total_paid': totalPaid,
        'payer_id': payerId,
        'split_members': splitMembers,
      };

  @override
  List<Object?> get props => [itemIds, totalPaid, payerId, splitMembers];
}
