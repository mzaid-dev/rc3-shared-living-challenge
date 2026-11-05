import 'package:equatable/equatable.dart';
import '../../data/models/chat_message.dart';

class AssistantState extends Equatable {
  final List<ChatMessage> messages;
  final bool isTyping;
  final bool isConfirming;
  final String? activeConfirmationId;
  final String conversationId;
  final List<String> suggestedPrompts;
  final String? errorMessage;
  final bool isOnline;

  const AssistantState({
    required this.messages,
    this.isTyping = false,
    this.isConfirming = false,
    this.activeConfirmationId,
    required this.conversationId,
    required this.suggestedPrompts,
    this.errorMessage,
    this.isOnline = true,
  });

  factory AssistantState.initial({String? initialConversationId}) {
    return AssistantState(
      messages: [
        ChatMessage(
          id: 'welcome-0',
          role: ChatMessageRole.assistant,
          type: ChatMessageType.text,
          content:
              'Assalam-o-Alaikum! I am your Hisab Assistant. I can help you record expenses, check member balances, manage your shopping list, and review monthly budgets.',
          createdAt: DateTime.now(),
        ),
      ],
      conversationId: initialConversationId ?? 'conv-${DateTime.now().millisecondsSinceEpoch}',
      suggestedPrompts: const [
        'How much did our household spend this month?',
        'Show my balance',
        'Who owes money?',
        'Show our shopping list',
        'Add a household expense',
        'How much budget is remaining?',
      ],
      isOnline: true,
    );
  }

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    bool? isConfirming,
    String? activeConfirmationId,
    String? conversationId,
    List<String>? suggestedPrompts,
    String? errorMessage,
    bool? isOnline,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isConfirming: isConfirming ?? this.isConfirming,
      activeConfirmationId: activeConfirmationId,
      conversationId: conversationId ?? this.conversationId,
      suggestedPrompts: suggestedPrompts ?? this.suggestedPrompts,
      errorMessage: errorMessage,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isTyping,
        isConfirming,
        activeConfirmationId,
        conversationId,
        suggestedPrompts,
        errorMessage,
        isOnline,
      ];
}
