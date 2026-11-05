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
    final rawSpent = json['spent'];
    final spentStr = (rawSpent is num)
        ? rawSpent.toStringAsFixed(2)
        : (rawSpent?.toString() ?? '0.00');

    final rawLimit = json['limit'];
    final limitStr = (rawLimit is num)
        ? rawLimit.toStringAsFixed(2)
        : (rawLimit?.toString() ?? '0.00');

    final rawRem = json['remaining'];
    final remStr = (rawRem is num)
        ? rawRem.toStringAsFixed(2)
        : (rawRem?.toString() ?? '0.00');

    return BudgetSummary(
      month: (json['month'] ?? '').toString(),
      spent: spentStr,
      spentPaisa: (json['spent_paisa'] as num?)?.toInt() ?? 0,
      limit: limitStr,
      limitPaisa: (json['limit_paisa'] as num?)?.toInt() ?? 0,
      remaining: remStr,
      remainingPaisa: (json['remaining_paisa'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'on_track').toString(),
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
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      netBalancePaisa: (json['net_balance_paisa'] as num?)?.toInt() ?? 0,
      message: (json['message'] ?? '').toString(),
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
    final rawSpent = json['spent'];
    final spentStr = (rawSpent is num)
        ? rawSpent.toStringAsFixed(2)
        : (rawSpent?.toString() ?? '0.00');

    final rawLimit = json['limit'];
    final limitStr = (rawLimit is num)
        ? rawLimit.toStringAsFixed(2)
        : (rawLimit?.toString() ?? '0.00');

    final rawRem = json['remaining'];
    final remStr = (rawRem is num)
        ? rawRem.toStringAsFixed(2)
        : (rawRem?.toString() ?? '0.00');

    return DashboardResponse(
      month: (json['month'] ?? '').toString(),
      spent: spentStr,
      spentPaisa: (json['spent_paisa'] as num?)?.toInt() ?? 0,
      limit: limitStr,
      limitPaisa: (json['limit_paisa'] as num?)?.toInt() ?? 0,
      remaining: remStr,
      remainingPaisa: (json['remaining_paisa'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'on_track').toString(),
      member: DashboardMemberSummary.fromJson(json['member'] as Map<String, dynamic>),
      pendingItemsCount: (json['pending_items_count'] ?? json['pending_shopping_count'] ?? 0) as int,
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
