import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/assistant_repository.dart';
import '../models/assistant_dtos.dart';
import '../models/chat_message.dart';

class MockAssistantRepository implements AssistantRepository {
  static const Uuid _uuid = Uuid();

  @override
  Future<AssistantChatResponse> sendMessage(
    AssistantChatRequest request, {
    String? idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final prompt = request.message.toLowerCase();
    final conversationId = request.conversationId ?? _uuid.v4();
    final msgId = _uuid.v4();

    // 1. Budget & Spending queries
    if (prompt.contains('spend') || prompt.contains('spending') || prompt.contains('spent')) {
      return AssistantChatResponse(
        conversationId: conversationId,
        message: ChatMessage(
          id: msgId,
          role: ChatMessageRole.assistant,
          type: ChatMessageType.budgetSummary,
          content: 'Here is the current household spending overview for November 2026:',
          data: const {
            'month': '2026-11',
            'limit': '5000.00',
            'spent': '4200.00',
            'remaining': '800.00',
            'percent': 84,
            'status': 'near_limit',
          },
          createdAt: DateTime.now(),
        ),
        suggestions: const [
          'Who owes money?',
          'Show our shopping list',
          'Add a household expense',
        ],
      );
    }

    // 2. Remaining Budget queries
    if (prompt.contains('budget') || prompt.contains('remaining')) {
      return AssistantChatResponse(
        conversationId: conversationId,
        message: ChatMessage(
          id: msgId,
          role: ChatMessageRole.assistant,
          type: ChatMessageType.budgetSummary,
          content: 'You have PKR 800.00 remaining out of the PKR 5,000.00 monthly household budget (84% utilized).',
          data: const {
            'month': '2026-11',
            'limit': '5000.00',
            'spent': '4200.00',
            'remaining': '800.00',
            'percent': 84,
            'status': 'near_limit',
          },
          createdAt: DateTime.now(),
        ),
        suggestions: const [
          'How much did our household spend this month?',
          'Show my balance',
          'Who owes money?',
        ],
      );
    }

    // 3. Balance & "Who owes money" queries
    if (prompt.contains('balance') || prompt.contains('owe') || prompt.contains('owes') || prompt.contains('debt')) {
      return AssistantChatResponse(
        conversationId: conversationId,
        message: ChatMessage(
          id: msgId,
          role: ChatMessageRole.assistant,
          type: ChatMessageType.balanceSummary,
          content: 'Here is the breakdown of current household member balances and debts:',
          data: const {
            'members': [
              {
                'member_id': 'M01',
                'name': 'Ali',
                'net_balance': '+250.00',
                'net_balance_paisa': 25000,
                'status': 'owed',
                'message': 'You are owed PKR 250.00',
              },
              {
                'member_id': 'M02',
                'name': 'Ayesha',
                'net_balance': '+200.00',
                'net_balance_paisa': 20000,
                'status': 'owed',
                'message': 'Ayesha is owed PKR 200.00',
              },
              {
                'member_id': 'M03',
                'name': 'Bilal',
                'net_balance': '-450.00',
                'net_balance_paisa': -45000,
                'status': 'owes',
                'message': 'Bilal owes PKR 450.00',
              },
            ],
            'household_total_spent': '4200.00',
          },
          createdAt: DateTime.now(),
        ),
        suggestions: const [
          'Show settlement suggestions',
          'Show our shopping list',
          'Add a household expense',
        ],
      );
    }

    // 4. Shopping list queries
    if (prompt.contains('shopping') || prompt.contains('grocery list') || prompt.contains('buy')) {
      return AssistantChatResponse(
        conversationId: conversationId,
        message: ChatMessage(
          id: msgId,
          role: ChatMessageRole.assistant,
          type: ChatMessageType.shoppingList,
          content: 'Here are the current pending items in your household shopping list:',
          data: const {
            'items': [
              {'id': 1, 'title': 'Eggs Farm Fresh', 'quantity': 2, 'unit': 'dozen', 'status': 'pending'},
              {'id': 2, 'title': 'Full Cream Milk', 'quantity': 3, 'unit': 'liters', 'status': 'pending'},
              {'id': 3, 'title': 'Dishwashing Liquid', 'quantity': 1, 'unit': 'bottle', 'status': 'pending'},
              {'id': 4, 'title': 'Whole Wheat Bread', 'quantity': 1, 'unit': 'pack', 'status': 'bought'},
            ],
            'pending_count': 3,
          },
          createdAt: DateTime.now(),
        ),
        suggestions: const [
          'Add shopping item: Laundry detergent',
          'Check household spending',
          'Who owes money?',
        ],
      );
    }

    // 5. Settlement suggestions query
    if (prompt.contains('settle') || prompt.contains('settlement') || prompt.contains('transfer')) {
      return AssistantChatResponse(
        conversationId: conversationId,
        message: ChatMessage(
          id: msgId,
          role: ChatMessageRole.assistant,
          type: ChatMessageType.settlementSuggestions,
          content: 'Here are the smart settlement suggestions to balance all household accounts with minimal transactions:',
          data: const {
            'suggestions': [
              {
                'sender_id': 'M03',
                'sender_name': 'Bilal',
                'recipient_id': 'M01',
                'recipient_name': 'Ali',
                'amount': '250.00',
                'suggested_transfer': 'Bilal pays Ali PKR 250.00',
              },
              {
                'sender_id': 'M03',
                'sender_name': 'Bilal',
                'recipient_id': 'M02',
                'recipient_name': 'Ayesha',
                'amount': '200.00',
                'suggested_transfer': 'Bilal pays Ayesha PKR 200.00',
              },
            ],
          },
          createdAt: DateTime.now(),
        ),
        suggestions: const [
          'Show my balance',
          'Add a household expense',
          'Show our shopping list',
        ],
      );
    }

    // 6. Expense creation with confirmation requirement
    if (prompt.contains('expense') || prompt.contains('groceries') || prompt.contains('bill') || prompt.contains('paid')) {
      final confId = _uuid.v4();
      return AssistantChatResponse(
        conversationId: conversationId,
        message: ChatMessage(
          id: msgId,
          role: ChatMessageRole.assistant,
          type: ChatMessageType.confirmationRequired,
          content: 'I understood your expense request. Please review the details below before recording it to the household ledger:',
          data: {
            'confirmation_id': confId,
            'action': 'create_expense',
            'summary': 'Add PKR 1,500.00 Groceries paid by Ali, split equally among 3 members.',
            'payload': {
              'title': 'Groceries',
              'amount': '1500.00',
              'amount_paisa': 150000,
              'category': 'Groceries',
              'payer_id': 'M01',
              'payer_name': 'Ali',
              'split_type': 'equal',
              'splits': [
                {'member_id': 'M01', 'name': 'Ali', 'share': '500.00', 'share_paisa': 50000},
                {'member_id': 'M02', 'name': 'Ayesha', 'share': '500.00', 'share_paisa': 50000},
                {'member_id': 'M03', 'name': 'Bilal', 'share': '500.00', 'share_paisa': 50000},
              ],
            },
          },
          createdAt: DateTime.now(),
        ),
        suggestions: const [
          'Cancel transaction',
          'Show our shopping list',
          'How much budget is remaining?',
        ],
      );
    }

    return AssistantChatResponse(
      conversationId: conversationId,
      message: ChatMessage(
        id: msgId,
        role: ChatMessageRole.assistant,
        type: ChatMessageType.text,
        content: 'I am your Hisab household financial assistant. You can ask me about shared expenses, balances, shopping items, or monthly budget.',
        createdAt: DateTime.now(),
      ),
      suggestions: const [
        'How much did our household spend this month?',
        'Show my balance',
        'Who owes money?',
        'Show our shopping list',
        'Add a household expense',
        'How much budget is remaining?',
      ],
    );
  }

  @override
  Future<AssistantConfirmationResponse> confirmAction(
    AssistantConfirmationRequest request, {
    String? idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));

    if (!request.confirmed) {
      return AssistantConfirmationResponse(
        status: 'cancelled',
        action: request.action,
        message: 'Action was cancelled by user.',
      );
    }

    if (request.action == 'create_expense' || request.action == 'add_expense') {
      final title = request.payload['title'] ?? 'Expense';
      final amount = request.payload['amount'] ?? '0.00';
      return AssistantConfirmationResponse(
        status: 'success',
        action: request.action,
        message: 'Expense "$title" of PKR $amount successfully recorded in the household ledger.',
        result: {
          'id': 105,
          'title': title,
          'amount': amount,
          'status': 'recorded',
        },
      );
    }

    if (request.action == 'settle_debt' || request.action == 'record_settlement') {
      final amount = request.payload['amount'] ?? '0.00';
      return AssistantConfirmationResponse(
        status: 'success',
        action: request.action,
        message: 'Settlement transfer of PKR $amount successfully recorded.',
        result: {
          'id': 42,
          'amount': amount,
          'status': 'settled',
        },
      );
    }

    if (request.action == 'add_shopping_item') {
      final title = request.payload['title'] ?? 'Item';
      return AssistantConfirmationResponse(
        status: 'success',
        action: request.action,
        message: 'Shopping item "$title" added to household list.',
        result: {
          'id': 88,
          'title': title,
          'status': 'pending',
        },
      );
    }

    return AssistantConfirmationResponse(
      status: 'success',
      action: request.action,
      message: 'Action completed successfully.',
    );
  }

  @override
  Future<void> clearConversation({String? conversationId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
