import 'package:equatable/equatable.dart';

class BudgetSummary extends Equatable {
  final String month;
  final String spent;
  final int spentPaisa;
  final String limit;
  final int limitPaisa;
  final String remaining;
  final int remainingPaisa;
  final int percent;
  final String status; // "on_track" | "near_limit" | "over_budget"

  const BudgetSummary({
    required this.month,
    required this.spent,
    required this.spentPaisa,
    required this.limit,
    required this.limitPaisa,
    required this.remaining,
    required this.remainingPaisa,
    required this.percent,
    required this.status,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      month: json['month'] as String,
      spent: json['spent'] as String,
      spentPaisa: json['spent_paisa'] as int,
      limit: json['limit'] as String,
      limitPaisa: json['limit_paisa'] as int,
      remaining: json['remaining'] as String,
      remainingPaisa: json['remaining_paisa'] as int,
      percent: (json['percent'] as num).toInt(),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'spent': spent,
        'spent_paisa': spentPaisa,
        'limit': limit,
        'limit_paisa': limitPaisa,
        'remaining': remaining,
        'remaining_paisa': remainingPaisa,
        'percent': percent,
        'status': status,
      };

  @override
  List<Object?> get props => [
        month,
        spent,
        spentPaisa,
        limit,
        limitPaisa,
        remaining,
        remainingPaisa,
        percent,
        status,
      ];
}

class DashboardMemberSummary extends Equatable {
  final String id;
  final String name;
  final int netBalancePaisa;
  final String message; // "You are owed PKR 250.00" or "You owe PKR 450.00"

  const DashboardMemberSummary({
    required this.id,
    required this.name,
    required this.netBalancePaisa,
    required this.message,
  });

  factory DashboardMemberSummary.fromJson(Map<String, dynamic> json) {
    return DashboardMemberSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      netBalancePaisa: json['net_balance_paisa'] as int,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'net_balance_paisa': netBalancePaisa,
        'message': message,
      };

  @override
  List<Object?> get props => [id, name, netBalancePaisa, message];
}

class DashboardResponse extends Equatable {
  final String month;
  final String spent;
  final int spentPaisa;
  final String limit;
  final int limitPaisa;
  final String remaining;
  final int remainingPaisa;
  final int percent;
  final String status;
  final DashboardMemberSummary member;
  final int pendingItemsCount;

  const DashboardResponse({
    required this.month,
    required this.spent,
    required this.spentPaisa,
    required this.limit,
    required this.limitPaisa,
    required this.remaining,
    required this.remainingPaisa,
    required this.percent,
    required this.status,
    required this.member,
    required this.pendingItemsCount,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      month: json['month'] as String,
      spent: json['spent'] as String,
      spentPaisa: json['spent_paisa'] as int,
      limit: json['limit'] as String,
      limitPaisa: json['limit_paisa'] as int,
      remaining: json['remaining'] as String,
      remainingPaisa: json['remaining_paisa'] as int,
      percent: (json['percent'] as num).toInt(),
      status: json['status'] as String,
      member: DashboardMemberSummary.fromJson(json['member'] as Map<String, dynamic>),
      pendingItemsCount: json['pending_items_count'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'spent': spent,
        'spent_paisa': spentPaisa,
        'limit': limit,
        'limit_paisa': limitPaisa,
        'remaining': remaining,
        'remaining_paisa': remainingPaisa,
        'percent': percent,
        'status': status,
        'member': member.toJson(),
        'pending_items_count': pendingItemsCount,
      };

  @override
  List<Object?> get props => [
        month,
        spent,
        spentPaisa,
        limit,
        limitPaisa,
        remaining,
        remainingPaisa,
        percent,
        status,
        member,
        pendingItemsCount,
      ];
}
