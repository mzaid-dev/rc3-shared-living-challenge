import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/assistant/data/models/assistant_dtos.dart';
import 'package:shared_living_app/features/assistant/data/models/chat_message.dart';

void main() {
  group('Assistant Models & Structured Payload Tests', () {
    test('ChatMessage parses standard text role and content', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg-1',
        'role': 'assistant',
        'type': 'text',
        'content': 'Assalam-o-Alaikum! How can I assist you?',
      });

      expect(msg.role, ChatMessageRole.assistant);
      expect(msg.type, ChatMessageType.text);
      expect(msg.content, 'Assalam-o-Alaikum! How can I assist you?');
      expect(msg.hasError, false);
    });

    test('AssistantChatResponse parses backend agent response envelope', () {
      final backendJson = {
        'success': true,
        'conversation_id': 'conv-100',
        'requires_confirmation': true,
        'response': {
          'type': 'confirmation_required',
          'message': 'Please confirm adding groceries expense.',
          'action': {
            'action_id': 'act-99',
            'action_type': 'create_expense',
            'title': 'Weekly Groceries',
            'amount': '1500.00',
            'currency': 'PKR',
            'payer': 'Ali',
            'participants': ['Ali', 'Ayesha', 'Bilal'],
            'confirmation_required': true,
          },
        },
        'suggestions': ['Confirm expense', 'Cancel'],
      };

      final response = AssistantChatResponse.fromJson(backendJson);
      expect(response.conversationId, 'conv-100');
      expect(response.message.type, ChatMessageType.confirmationRequired);
      expect(response.message.content, 'Please confirm adding groceries expense.');
      expect(response.message.data?['action_id'], 'act-99');
      expect(response.message.data?['amount'], '1500.00');
      expect(response.suggestions.length, 2);
    });

    test('ExpenseSummaryData correctly serializes and deserializes', () {
      final data = ExpenseSummaryData.fromJson({
        'title': 'Internet Bill',
        'amount': '3000.00',
        'category': 'Utilities',
        'payer_name': 'Ayesha',
        'split_type': 'equal',
        'participants': [
          {'name': 'Ali', 'share': '1000.00'},
          {'name': 'Ayesha', 'share': '1000.00'},
          {'name': 'Bilal', 'share': '1000.00'},
        ],
      });

      expect(data.title, 'Internet Bill');
      expect(data.amount, '3000.00');
      expect(data.category, 'Utilities');
      expect(data.payerName, 'Ayesha');
      expect(data.participants.length, 3);
    });

    test('BalanceSummaryData parses positive and negative member balances', () {
      final data = BalanceSummaryData.fromJson({
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
            'member_id': 'M03',
            'name': 'Bilal',
            'net_balance': '-450.00',
            'net_balance_paisa': -45000,
            'status': 'owes',
            'message': 'Bilal owes PKR 450.00',
          },
        ],
      });

      expect(data.members.length, 2);
      expect(data.members[0].isReceivable, true);
      expect(data.members[0].isDebt, false);
      expect(data.members[1].isReceivable, false);
      expect(data.members[1].isDebt, true);
    });

    test('BudgetSummaryData parses budget limit, spent and status', () {
      final data = BudgetSummaryData.fromJson({
        'month': '2026-11',
        'limit': '5000.00',
        'spent': '4200.00',
        'remaining': '800.00',
        'percent': 84,
        'status': 'near_limit',
      });

      expect(data.month, '2026-11');
      expect(data.spent, '4200.00');
      expect(data.percent, 84);
      expect(data.status, 'near_limit');
    });

    test('ShoppingListData parses pending items and count', () {
      final data = ShoppingListData.fromJson({
        'items': [
          {'id': 1, 'title': 'Eggs', 'quantity': 2, 'unit': 'dozen', 'status': 'pending'},
          {'id': 2, 'title': 'Milk', 'quantity': 1, 'unit': 'pack', 'status': 'bought'},
        ],
        'pending_count': 1,
      });

      expect(data.items.length, 2);
      expect(data.pendingCount, 1);
      expect(data.items[0].isPending, true);
      expect(data.items[1].isBought, true);
    });

    test('SettlementSuggestionsData parses transfer recommendations', () {
      final data = SettlementSuggestionsData.fromJson({
        'suggestions': [
          {
            'sender_id': 'M03',
            'sender_name': 'Bilal',
            'recipient_id': 'M01',
            'recipient_name': 'Ali',
            'amount': '250.00',
            'suggested_transfer': 'Bilal pays Ali PKR 250.00',
          },
        ],
      });

      expect(data.suggestions.length, 1);
      expect(data.suggestions.first.senderName, 'Bilal');
      expect(data.suggestions.first.recipientName, 'Ali');
      expect(data.suggestions.first.amount, '250.00');
    });
  });
}
