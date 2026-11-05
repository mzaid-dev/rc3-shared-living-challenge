import 'package:equatable/equatable.dart';
import 'chat_message.dart';

/// Request payload for POST /api/assistant/chat
class AssistantChatRequest extends Equatable {
  final String message;
  final String? conversationId;
  final String? memberId;
  final String? householdId;

  const AssistantChatRequest({
    required this.message,
    this.conversationId,
    this.memberId,
    this.householdId,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (memberId != null) 'active_member_id': memberId,
        if (memberId != null) 'member_id': memberId,
        if (householdId != null) 'household_id': householdId,
      };

  @override
  List<Object?> get props => [message, conversationId, memberId, householdId];
}

/// Response payload from POST /api/assistant/chat
class AssistantChatResponse extends Equatable {
  final String conversationId;
  final ChatMessage message;
  final List<String> suggestions;

  const AssistantChatResponse({
    required this.conversationId,
    required this.message,
    this.suggestions = const [],
  });

  factory AssistantChatResponse.fromJson(Map<String, dynamic> json) {
    final convId = (json['conversation_id'] ?? '').toString();

    // Support backend agent's AssistantResponsePayload structure:
    if (json.containsKey('response') && json['response'] is Map<String, dynamic>) {
      final respObj = json['response'] as Map<String, dynamic>;
      final typeStr = respObj['type'] as String? ?? 'text';
      final contentStr = respObj['message'] as String? ?? '';
      final actionObj = respObj['action'] as Map<String, dynamic>?;
      final rawData = respObj['data'];

      Map<String, dynamic> mergedData = {};
      if (rawData is Map<String, dynamic>) {
        mergedData.addAll(rawData);
      } else if (rawData is List<dynamic>) {
        mergedData['items'] = rawData;
        mergedData['suggestions'] = rawData;
        mergedData['members'] = rawData;
      }

      if (actionObj != null) {
        mergedData['action_id'] = actionObj['action_id'];
        mergedData['confirmation_id'] = actionObj['action_id'];
        mergedData['action'] = actionObj['action_type'];
        mergedData['title'] = actionObj['title'];
        mergedData['amount'] = actionObj['amount'];
        mergedData['currency'] = actionObj['currency'] ?? 'PKR';
        mergedData['payer'] = actionObj['payer'];
        mergedData['payer_name'] = actionObj['payer'];
        mergedData['participants'] = actionObj['participants'];
        mergedData['items'] = actionObj['items'];
        mergedData['summary'] = contentStr;
        if (actionObj['details'] is Map<String, dynamic>) {
          mergedData.addAll(actionObj['details'] as Map<String, dynamic>);
        }
      }

      final chatType = (json['requires_confirmation'] == true || typeStr == 'confirmation_required')
          ? ChatMessageType.confirmationRequired
          : ChatMessageType.fromString(typeStr);

      final msg = ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        role: ChatMessageRole.assistant,
        type: chatType,
        content: contentStr,
        data: mergedData.isNotEmpty ? mergedData : null,
        createdAt: DateTime.now(),
      );

      final suggList = (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];

      return AssistantChatResponse(
        conversationId: convId,
        message: msg,
        suggestions: suggList,
      );
    }

    final msgJson = json['message'] as Map<String, dynamic>? ?? json;
    final suggList = (json['suggestions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return AssistantChatResponse(
      conversationId: convId,
      message: ChatMessage.fromJson(msgJson),
      suggestions: suggList,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'message': message.toJson(),
        'suggestions': suggestions,
      };

  @override
  List<Object?> get props => [conversationId, message, suggestions];
}

/// Request payload for POST /api/assistant/confirm
class AssistantConfirmationRequest extends Equatable {
  final String conversationId;
  final String confirmationId;
  final String action;
  final bool confirmed;
  final Map<String, dynamic> payload;

  const AssistantConfirmationRequest({
    this.conversationId = '',
    required this.confirmationId,
    required this.action,
    required this.confirmed,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'action_id': confirmationId,
        'confirmation_id': confirmationId,
        'action': action,
        'confirmed': confirmed,
        'payload': payload,
      };

  @override
  List<Object?> get props => [conversationId, confirmationId, action, confirmed, payload];
}

/// Response payload from POST /api/assistant/confirm
class AssistantConfirmationResponse extends Equatable {
  final String status;
  final String action;
  final String message;
  final Map<String, dynamic>? result;

  const AssistantConfirmationResponse({
    required this.status,
    required this.action,
    required this.message,
    this.result,
  });

  bool get isSuccess =>
      status.toLowerCase() == 'success' || status.toLowerCase() == 'confirmed';

  factory AssistantConfirmationResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('response') && json['response'] is Map<String, dynamic>) {
      final resp = json['response'] as Map<String, dynamic>;
      final success = json['success'] as bool? ?? true;
      return AssistantConfirmationResponse(
        status: success ? 'success' : 'error',
        action: resp['type']?.toString() ?? 'action',
        message: resp['message']?.toString() ?? 'Action processed',
        result: resp['data'] as Map<String, dynamic>?,
      );
    }

    return AssistantConfirmationResponse(
      status: (json['status'] ?? 'success').toString(),
      action: (json['action'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      result: json['result'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'action': action,
        'message': message,
        if (result != null) 'result': result,
      };

  @override
  List<Object?> get props => [status, action, message, result];
}

// ---------------------------------------------------------------------------
// Typed representations for structured data payloads
// ---------------------------------------------------------------------------

class ExpenseSummaryData extends Equatable {
  final String title;
  final String amount;
  final int? amountPaisa;
  final String category;
  final String payerName;
  final String splitType;
  final String? date;
  final List<ParticipantShare> participants;

  const ExpenseSummaryData({
    required this.title,
    required this.amount,
    this.amountPaisa,
    required this.category,
    required this.payerName,
    this.splitType = 'equal',
    this.date,
    this.participants = const [],
  });

  factory ExpenseSummaryData.fromJson(Map<String, dynamic> json) {
    return ExpenseSummaryData(
      title: (json['title'] ?? json['expense_title'] ?? 'Expense').toString(),
      amount: (json['amount'] ?? '0.00').toString(),
      amountPaisa: json['amount_paisa'] is num ? (json['amount_paisa'] as num).toInt() : null,
      category: (json['category'] ?? 'General').toString(),
      payerName: (json['payer_name'] ?? json['payer'] ?? json['payer_id'] ?? 'Unknown').toString(),
      splitType: (json['split_type'] ?? 'equal').toString(),
      date: json['date']?.toString(),
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) {
                if (e is Map<String, dynamic>) {
                  return ParticipantShare.fromJson(e);
                } else {
                  return ParticipantShare(name: e.toString(), share: '0.00');
                }
              })
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        if (amountPaisa != null) 'amount_paisa': amountPaisa,
        'category': category,
        'payer_name': payerName,
        'split_type': splitType,
        if (date != null) 'date': date,
        'participants': participants.map((p) => p.toJson()).toList(),
      };

  @override
  List<Object?> get props => [title, amount, amountPaisa, category, payerName, splitType, date, participants];
}

class ParticipantShare extends Equatable {
  final String name;
  final String share;

  const ParticipantShare({required this.name, required this.share});

  factory ParticipantShare.fromJson(Map<String, dynamic> json) {
    return ParticipantShare(
      name: (json['name'] ?? json['member_id'] ?? '').toString(),
      share: (json['share'] ?? json['amount'] ?? '0.00').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'share': share};

  @override
  List<Object?> get props => [name, share];
}

class BalanceSummaryData extends Equatable {
  final List<MemberBalanceItem> members;
  final String? householdTotalSpent;

  const BalanceSummaryData({
    required this.members,
    this.householdTotalSpent,
  });

  factory BalanceSummaryData.fromJson(Map<String, dynamic> json) {
    final list = (json['members'] ?? json['balances'] ?? []) as List<dynamic>;
    return BalanceSummaryData(
      members: list
          .map((e) => MemberBalanceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      householdTotalSpent: json['household_total_spent']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'members': members.map((m) => m.toJson()).toList(),
        if (householdTotalSpent != null) 'household_total_spent': householdTotalSpent,
      };

  @override
  List<Object?> get props => [members, householdTotalSpent];
}

class MemberBalanceItem extends Equatable {
  final String memberId;
  final String name;
  final String netBalance;
  final int netBalancePaisa;
  final String status;
  final String? message;

  const MemberBalanceItem({
    required this.memberId,
    required this.name,
    required this.netBalance,
    required this.netBalancePaisa,
    required this.status,
    this.message,
  });

  bool get isReceivable => netBalancePaisa > 0 || status == 'owed';
  bool get isDebt => netBalancePaisa < 0 || status == 'owes';
  bool get isSettled => netBalancePaisa == 0 || status == 'settled';

  factory MemberBalanceItem.fromJson(Map<String, dynamic> json) {
    final rawNet = json['net_balance'];
    final netStr = (rawNet is num)
        ? (rawNet > 0 ? '+${rawNet.toStringAsFixed(2)}' : rawNet.toStringAsFixed(2))
        : (rawNet?.toString() ?? '0.00');

    final rawPaisa = json['net_balance_paisa'];
    final paisa = (rawPaisa is num)
        ? rawPaisa.toInt()
        : (double.tryParse(netStr.replaceAll('+', '')) != null
            ? (double.parse(netStr.replaceAll('+', '')) * 100).round()
            : 0);

    return MemberBalanceItem(
      memberId: (json['member_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Member').toString(),
      netBalance: netStr,
      netBalancePaisa: paisa,
      status: (json['status'] ?? (paisa > 0 ? 'owed' : (paisa < 0 ? 'owes' : 'settled'))).toString(),
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'member_id': memberId,
        'name': name,
        'net_balance': netBalance,
        'net_balance_paisa': netBalancePaisa,
        'status': status,
        if (message != null) 'message': message,
      };

  @override
  List<Object?> get props => [memberId, name, netBalance, netBalancePaisa, status, message];
}

class ShoppingListData extends Equatable {
  final List<ShoppingItemInfo> items;
  final int pendingCount;

  const ShoppingListData({
    required this.items,
    this.pendingCount = 0,
  });

  factory ShoppingListData.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] ?? []) as List<dynamic>;
    final parsedItems = list
        .map((e) => ShoppingItemInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    final count = json['pending_count'] is num
        ? (json['pending_count'] as num).toInt()
        : parsedItems.where((i) => i.isPending).length;

    return ShoppingListData(
      items: parsedItems,
      pendingCount: count,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'pending_count': pendingCount,
      };

  @override
  List<Object?> get props => [items, pendingCount];
}

class ShoppingItemInfo extends Equatable {
  final dynamic id;
  final String title;
  final num quantity;
  final String unit;
  final String status;

  const ShoppingItemInfo({
    required this.id,
    required this.title,
    required this.quantity,
    required this.unit,
    this.status = 'pending',
  });

  bool get isPending => status == 'pending';
  bool get isBought => status == 'bought';

  factory ShoppingItemInfo.fromJson(Map<String, dynamic> json) {
    return ShoppingItemInfo(
      id: json['id'] ?? 0,
      title: (json['title'] ?? json['name'] ?? 'Item').toString(),
      quantity: json['quantity'] is num
          ? (json['quantity'] as num)
          : (num.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      unit: (json['unit'] ?? 'item').toString(),
      status: (json['status'] ?? 'pending').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'quantity': quantity,
        'unit': unit,
        'status': status,
      };

  @override
  List<Object?> get props => [id, title, quantity, unit, status];
}

class BudgetSummaryData extends Equatable {
  final String month;
  final String limit;
  final String spent;
  final String remaining;
  final int percent;
  final String status;

  const BudgetSummaryData({
    required this.month,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.status,
  });

  factory BudgetSummaryData.fromJson(Map<String, dynamic> json) {
    return BudgetSummaryData(
      month: (json['month'] ?? '').toString(),
      limit: (json['limit'] ?? '0.00').toString(),
      spent: (json['spent'] ?? '0.00').toString(),
      remaining: (json['remaining'] ?? '0.00').toString(),
      percent: json['percent'] is num ? (json['percent'] as num).toInt() : 0,
      status: (json['status'] ?? 'on_track').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'limit': limit,
        'spent': spent,
        'remaining': remaining,
        'percent': percent,
        'status': status,
      };

  @override
  List<Object?> get props => [month, limit, spent, remaining, percent, status];
}

class SettlementSuggestionsData extends Equatable {
  final List<SettlementSuggestionItem> suggestions;

  const SettlementSuggestionsData({required this.suggestions});

  factory SettlementSuggestionsData.fromJson(Map<String, dynamic> json) {
    final list = (json['suggestions'] ?? json['settlements'] ?? []) as List<dynamic>;
    return SettlementSuggestionsData(
      suggestions: list
          .map((e) => SettlementSuggestionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
      };

  @override
  List<Object?> get props => [suggestions];
}

class SettlementSuggestionItem extends Equatable {
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String amount;
  final String? suggestedTransfer;

  const SettlementSuggestionItem({
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    this.suggestedTransfer,
  });

  factory SettlementSuggestionItem.fromJson(Map<String, dynamic> json) {
    return SettlementSuggestionItem(
      senderId: (json['sender_id'] ?? '').toString(),
      senderName: (json['sender_name'] ?? json['sender'] ?? 'Sender').toString(),
      recipientId: (json['recipient_id'] ?? '').toString(),
      recipientName: (json['recipient_name'] ?? json['recipient'] ?? 'Recipient').toString(),
      amount: (json['amount'] ?? '0.00').toString(),
      suggestedTransfer: json['suggested_transfer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sender_id': senderId,
        'sender_name': senderName,
        'recipient_id': recipientId,
        'recipient_name': recipientName,
        'amount': amount,
        if (suggestedTransfer != null) 'suggested_transfer': suggestedTransfer,
      };

  @override
  List<Object?> get props => [senderId, senderName, recipientId, recipientName, amount, suggestedTransfer];
}

class ConfirmationRequiredData extends Equatable {
  final String confirmationId;
  final String action;
  final String summary;
  final Map<String, dynamic> payload;

  const ConfirmationRequiredData({
    required this.confirmationId,
    required this.action,
    required this.summary,
    required this.payload,
  });

  factory ConfirmationRequiredData.fromJson(Map<String, dynamic> json) {
    return ConfirmationRequiredData(
      confirmationId: (json['confirmation_id'] ?? json['action_id'] ?? json['id'] ?? '').toString(),
      action: (json['action'] ?? json['action_type'] ?? '').toString(),
      summary: (json['summary'] ?? json['message'] ?? 'Please confirm this action').toString(),
      payload: (json['payload'] as Map<String, dynamic>?) ?? json,
    );
  }

  Map<String, dynamic> toJson() => {
        'confirmation_id': confirmationId,
        'action': action,
        'summary': summary,
        'payload': payload,
      };

  @override
  List<Object?> get props => [confirmationId, action, summary, payload];
}

class ActionSuccessData extends Equatable {
  final String action;
  final String message;
  final String? transactionId;
  final Map<String, dynamic>? details;

  const ActionSuccessData({
    required this.action,
    required this.message,
    this.transactionId,
    this.details,
  });

  factory ActionSuccessData.fromJson(Map<String, dynamic> json) {
    return ActionSuccessData(
      action: (json['action'] ?? '').toString(),
      message: (json['message'] ?? 'Action successfully executed').toString(),
      transactionId: json['transaction_id']?.toString() ?? json['id']?.toString(),
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'message': message,
        if (transactionId != null) 'transaction_id': transactionId,
        if (details != null) 'details': details,
      };

  @override
  List<Object?> get props => [action, message, transactionId, details];
}

class ActionErrorData extends Equatable {
  final String errorCode;
  final String message;
  final bool canRetry;

  const ActionErrorData({
    required this.errorCode,
    required this.message,
    this.canRetry = true,
  });

  factory ActionErrorData.fromJson(Map<String, dynamic> json) {
    return ActionErrorData(
      errorCode: (json['error_code'] ?? json['code'] ?? 'ACTION_FAILED').toString(),
      message: (json['message'] ?? 'Action could not be completed').toString(),
      canRetry: json['can_retry'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'error_code': errorCode,
        'message': message,
        'can_retry': canRetry,
      };

  @override
  List<Object?> get props => [errorCode, message, canRetry];
}
