import 'package:equatable/equatable.dart';

class MemberBalance extends Equatable {
  final String memberId;
  final String name;
  final String totalPaid; // 2-decimal string
  final String shareOwed;
  final String settlementsReceived;
  final String settlementsSent;
  final String netBalance;
  final int netBalancePaisa; // positive: owed (receivable); negative: owes (debt)
  final String status; // "owed" | "owes" | "settled"

  const MemberBalance({
    required this.memberId,
    required this.name,
    required this.totalPaid,
    required this.shareOwed,
    required this.settlementsReceived,
    required this.settlementsSent,
    required this.netBalance,
    required this.netBalancePaisa,
    required this.status,
  });

  factory MemberBalance.fromJson(Map<String, dynamic> json) {
    return MemberBalance(
      memberId: json['member_id'] as String,
      name: json['name'] as String,
      totalPaid: json['total_paid'] as String,
      shareOwed: json['share_owed'] as String,
      settlementsReceived: json['settlements_received'] as String? ?? '0.00',
      settlementsSent: json['settlements_sent'] as String? ?? '0.00',
      netBalance: json['net_balance'] as String,
      netBalancePaisa: json['net_balance_paisa'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'member_id': memberId,
        'name': name,
        'total_paid': totalPaid,
        'share_owed': shareOwed,
        'settlements_received': settlementsReceived,
        'settlements_sent': settlementsSent,
        'net_balance': netBalance,
        'net_balance_paisa': netBalancePaisa,
        'status': status,
      };

  @override
  List<Object?> get props => [
        memberId,
        name,
        totalPaid,
        shareOwed,
        settlementsReceived,
        settlementsSent,
        netBalance,
        netBalancePaisa,
        status,
      ];
}

class BalancesResponse extends Equatable {
  final List<MemberBalance> balances;
  final String sum; // "0.00"
  final int sumPaisa; // 0

  const BalancesResponse({
    required this.balances,
    required this.sum,
    required this.sumPaisa,
  });

  factory BalancesResponse.fromJson(Map<String, dynamic> json) {
    return BalancesResponse(
      balances: (json['balances'] as List<dynamic>)
          .map((e) => MemberBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      sum: json['sum'] as String,
      sumPaisa: json['sum_paisa'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'balances': balances.map((b) => b.toJson()).toList(),
        'sum': sum,
        'sum_paisa': sumPaisa,
      };

  @override
  List<Object?> get props => [balances, sum, sumPaisa];
}

class SettlementRequestDto extends Equatable {
  final String senderId; // "M02"
  final String recipientId; // "M01"
  final String amount; // "250.00"

  const SettlementRequestDto({
    required this.senderId,
    required this.recipientId,
    required this.amount,
  });

  factory SettlementRequestDto.fromJson(Map<String, dynamic> json) {
    return SettlementRequestDto(
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      amount: json['amount'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'sender_id': senderId,
        'recipient_id': recipientId,
        'amount': amount,
      };

  @override
  List<Object?> get props => [senderId, recipientId, amount];
}

class SettlementResult extends Equatable {
  final Map<String, dynamic> settlement;
  final BalancesResponse balances;

  const SettlementResult({
    required this.settlement,
    required this.balances,
  });

  factory SettlementResult.fromJson(Map<String, dynamic> json) {
    return SettlementResult(
      settlement: json['settlement'] as Map<String, dynamic>,
      balances: BalancesResponse.fromJson(json['balances'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'settlement': settlement,
        'balances': balances.toJson(),
      };

  @override
  List<Object?> get props => [settlement, balances];
}
