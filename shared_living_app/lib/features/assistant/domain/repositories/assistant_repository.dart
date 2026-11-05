import '../../data/models/assistant_dtos.dart';

abstract class AssistantRepository {
  /// Send a natural language prompt to the AI assistant
  Future<AssistantChatResponse> sendMessage(
    AssistantChatRequest request, {
    String? idempotencyKey,
  });

  /// Confirm or cancel a staged financial action
  Future<AssistantConfirmationResponse> confirmAction(
    AssistantConfirmationRequest request, {
    String? idempotencyKey,
  });

  /// Clear active conversation session
  Future<void> clearConversation({String? conversationId});
}
