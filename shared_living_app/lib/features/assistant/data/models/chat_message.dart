import 'package:equatable/equatable.dart';

enum ChatMessageRole {
  user,
  assistant,
  system;

  static ChatMessageRole fromString(String val) {
    switch (val.toLowerCase()) {
      case 'user':
        return ChatMessageRole.user;
      case 'system':
        return ChatMessageRole.system;
      case 'assistant':
      default:
        return ChatMessageRole.assistant;
    }
  }

  String toRoleString() => name;
}

enum ChatMessageType {
  text,
  expenseSummary,
  balanceSummary,
  shoppingList,
  budgetSummary,
  settlementSuggestions,
  confirmationRequired,
  actionSuccess,
  actionError;

  static ChatMessageType fromString(String? val) {
    switch (val) {
      case 'expense_summary':
        return ChatMessageType.expenseSummary;
      case 'balance_summary':
        return ChatMessageType.balanceSummary;
      case 'shopping_list':
        return ChatMessageType.shoppingList;
      case 'budget_summary':
        return ChatMessageType.budgetSummary;
      case 'settlement_suggestions':
        return ChatMessageType.settlementSuggestions;
      case 'confirmation_required':
        return ChatMessageType.confirmationRequired;
      case 'action_success':
        return ChatMessageType.actionSuccess;
      case 'action_error':
      case 'action_rejected':
        return ChatMessageType.actionError;
      case 'text':
      default:
        return ChatMessageType.text;
    }
  }

  String toTypeString() {
    switch (this) {
      case ChatMessageType.expenseSummary:
        return 'expense_summary';
      case ChatMessageType.balanceSummary:
        return 'balance_summary';
      case ChatMessageType.shoppingList:
        return 'shopping_list';
      case ChatMessageType.budgetSummary:
        return 'budget_summary';
      case ChatMessageType.settlementSuggestions:
        return 'settlement_suggestions';
      case ChatMessageType.confirmationRequired:
        return 'confirmation_required';
      case ChatMessageType.actionSuccess:
        return 'action_success';
      case ChatMessageType.actionError:
        return 'action_error';
      case ChatMessageType.text:
        return 'text';
    }
  }
}

class ChatMessage extends Equatable {
  final String id;
  final ChatMessageRole role;
  final ChatMessageType type;
  final String content;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final bool isPending;
  final bool hasError;
  final bool isConfirmed;
  final bool isCancelled;

  const ChatMessage({
    required this.id,
    required this.role,
    this.type = ChatMessageType.text,
    required this.content,
    this.data,
    required this.createdAt,
    this.isPending = false,
    this.hasError = false,
    this.isConfirmed = false,
    this.isCancelled = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      role: ChatMessageRole.fromString(json['role'] as String? ?? 'assistant'),
      type: ChatMessageType.fromString(json['type'] as String?),
      content: (json['content'] ?? json['message'] ?? '').toString(),
      data: json['data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isPending: json['is_pending'] as bool? ?? false,
      hasError: json['has_error'] as bool? ?? false,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
      isCancelled: json['is_cancelled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.toRoleString(),
        'type': type.toTypeString(),
        'content': content,
        if (data != null) 'data': data,
        'created_at': createdAt.toIso8601String(),
        'is_pending': isPending,
        'has_error': hasError,
        'is_confirmed': isConfirmed,
        'is_cancelled': isCancelled,
      };

  ChatMessage copyWith({
    String? id,
    ChatMessageRole? role,
    ChatMessageType? type,
    String? content,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isPending,
    bool? hasError,
    bool? isConfirmed,
    bool? isCancelled,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      type: type ?? this.type,
      content: content ?? this.content,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      hasError: hasError ?? this.hasError,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        type,
        content,
        data,
        createdAt,
        isPending,
        hasError,
        isConfirmed,
        isCancelled,
      ];
}
