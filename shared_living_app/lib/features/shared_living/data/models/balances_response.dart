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
    final rawPaid = json['total_paid'] ?? json['paid'];
    final paidStr = (rawPaid is num)
        ? rawPaid.toStringAsFixed(2)
        : (rawPaid?.toString() ?? '0.00');

    final rawOwed = json['share_owed'] ?? json['owed'];
    final owedStr = (rawOwed is num)
        ? rawOwed.toStringAsFixed(2)
        : (rawOwed?.toString() ?? '0.00');

    final rawRecv = json['settlements_received'] ?? '0.00';
    final recvStr = (rawRecv is num)
        ? rawRecv.toStringAsFixed(2)
        : (rawRecv?.toString() ?? '0.00');

    final rawSent = json['settlements_sent'] ?? '0.00';
    final sentStr = (rawSent is num)
        ? rawSent.toStringAsFixed(2)
        : (rawSent?.toString() ?? '0.00');

    final rawNet = json['net_balance'];
    final netStr = (rawNet is num)
        ? (rawNet > 0 ? '+${rawNet.toStringAsFixed(2)}' : rawNet.toStringAsFixed(2))
        : (rawNet?.toString() ?? '0.00');

    final rawNetPaisa = json['net_balance_paisa'];
    final netPaisa = (rawNetPaisa is num)
        ? rawNetPaisa.toInt()
        : (double.tryParse(netStr.replaceAll('+', '')) != null
            ? (double.parse(netStr.replaceAll('+', '')) * 100).round()
            : 0);

    return MemberBalance(
      memberId: (json['member_id'] ?? json['memberId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      totalPaid: paidStr,
      shareOwed: owedStr,
      settlementsReceived: recvStr,
      settlementsSent: sentStr,
      netBalance: netStr,
      netBalancePaisa: netPaisa,
      status: (json['status'] ?? 'settled').toString(),
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
    final list = (json['balances'] ?? json['members'] ?? []) as List<dynamic>;
    final sumPaisa = json['sum_paisa'];
    final sumStr = json['sum']?.toString() ?? '0.00';
    return BalancesResponse(
      balances: list
          .map((e) => MemberBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      sum: sumStr,
      sumPaisa: sumPaisa is num ? sumPaisa.toInt() : 0,
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
