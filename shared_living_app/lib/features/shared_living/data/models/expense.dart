import 'package:equatable/equatable.dart';
import 'checkout_item_ref.dart';

class ExpenseSplitShare extends Equatable {
  final String memberId;
  final String share; // 2-decimal string (e.g. "260.00")
  final int sharePaisa; // 26000

  const ExpenseSplitShare({
    required this.memberId,
    required this.share,
    required this.sharePaisa,
  });

  factory ExpenseSplitShare.fromJson(Map<String, dynamic> json) {
    return ExpenseSplitShare(
      memberId: json['member_id'] as String,
      share: json['share'] as String,
      sharePaisa: json['share_paisa'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'member_id': memberId,
        'share': share,
        'share_paisa': sharePaisa,
      };

  @override
  List<Object?> get props => [memberId, share, sharePaisa];
}

class Expense extends Equatable {
  final int id;
  final String title;
  final String category;
  final String amount; // "780.00"
  final int amountPaisa; // 78000
  final String payerId;
  final String splitType; // "equal" | "custom"
  final String date;
  final String source; // "checkout" | "manual"
  final List<ExpenseSplitShare> splits;
  final List<CheckoutItemRef> items;

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.amountPaisa,
    required this.payerId,
    required this.splitType,
    required this.date,
    required this.source,
    required this.splits,
    this.items = const [],
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: json['amount'] as String,
      amountPaisa: json['amount_paisa'] as int,
      payerId: json['payer_id'] as String,
      splitType: json['split_type'] as String,
      date: json['date'] as String,
      source: json['source'] as String? ?? 'manual',
      splits: (json['splits'] as List<dynamic>?)
              ?.map((e) => ExpenseSplitShare.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CheckoutItemRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'amount_paisa': amountPaisa,
        'payer_id': payerId,
        'split_type': splitType,
        'date': date,
        'source': source,
        'splits': splits.map((s) => s.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        amount,
        amountPaisa,
        payerId,
        splitType,
        date,
        source,
        splits,
        items,
      ];
}

class CustomSplitItemDto extends Equatable {
  final String memberId;
  final String amount; // 2-decimal string

  const CustomSplitItemDto({required this.memberId, required this.amount});

  factory CustomSplitItemDto.fromJson(Map<String, dynamic> json) {
    return CustomSplitItemDto(
      memberId: json['member_id'] as String,
      amount: json['amount'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'member_id': memberId,
        'amount': amount,
      };

  @override
  List<Object?> get props => [memberId, amount];
}

class CreateExpenseDto extends Equatable {
  final String title;
  final String category;
  final String amount; // 2-decimal string (e.g. "1500.00")
  final String payerId;
  final String splitType; // "equal" | "custom"
  final List<String>? equalMemberIds; // optional list of member IDs for equal
  final List<CustomSplitItemDto>? customSplits; // list of [{member_id, amount}] for custom
  final String? date;

  const CreateExpenseDto({
    required this.title,
    required this.category,
    required this.amount,
    required this.payerId,
    required this.splitType,
    this.equalMemberIds,
    this.customSplits,
    this.date,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'category': category,
      'amount': amount,
      'payer_id': payerId,
      'split_type': splitType,
    };
    if (splitType == 'equal') {
      if (equalMemberIds != null) {
        map['splits'] = equalMemberIds;
      }
    } else {
      if (customSplits != null) {
        map['splits'] = customSplits!.map((s) => s.toJson()).toList();
      }
    }
    if (date != null) {
      map['date'] = date;
    }
    return map;
  }

  @override
  List<Object?> get props => [
        title,
        category,
        amount,
        payerId,
        splitType,
        equalMemberIds,
        customSplits,
        date,
      ];
}
