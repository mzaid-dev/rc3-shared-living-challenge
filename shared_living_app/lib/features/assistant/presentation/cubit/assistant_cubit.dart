import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:shared_living_app/core/errors/app_failure.dart';
import 'package:shared_living_app/core/utils/idempotency_manager.dart';
import '../../data/models/assistant_dtos.dart';
import '../../data/models/chat_message.dart';
import '../../domain/repositories/assistant_repository.dart';
import 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  final AssistantRepository repository;
  static const Uuid _uuid = Uuid();
  final IdempotencyContext _idempotency = IdempotencyContext();

  AssistantCubit({required this.repository}) : super(AssistantState.initial());

  Future<void> sendMessage(
    String text, {
    String? activeMemberId,
    String? householdId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isTyping) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatMessageRole.user,
      type: ChatMessageType.text,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, userMsg],
      isTyping: true,
      errorMessage: null,
    ));

    try {
      final request = AssistantChatRequest(
        message: trimmed,
        conversationId: state.conversationId,
        memberId: activeMemberId,
        householdId: householdId,
      );

      final response = await repository.sendMessage(request);

      emit(state.copyWith(
        messages: [...state.messages, response.message],
        isTyping: false,
        conversationId: response.conversationId.isNotEmpty
            ? response.conversationId
            : state.conversationId,
        suggestedPrompts: response.suggestions.isNotEmpty
            ? response.suggestions
            : state.suggestedPrompts,
      ));
    } on AppFailure catch (e) {
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.assistant,
        type: ChatMessageType.actionError,
        content: e.message,
        data: {'error_code': e.code, 'message': e.message},
        createdAt: DateTime.now(),
        hasError: true,
      );

      emit(state.copyWith(
        messages: [...state.messages, errorMsg],
        isTyping: false,
        errorMessage: e.message,
      ));
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.assistant,
        type: ChatMessageType.actionError,
        content: 'Failed to communicate with Hisab Assistant: $e',
        data: {'error_code': 'CLIENT_EXCEPTION', 'message': e.toString()},
        createdAt: DateTime.now(),
        hasError: true,
      );

      emit(state.copyWith(
        messages: [...state.messages, errorMsg],
        isTyping: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<bool> confirmAction({
    required String confirmationId,
    required String action,
    required Map<String, dynamic> payload,
    bool confirmed = true,
    VoidCallback? onMutationSuccess,
  }) async {
    if (state.isConfirming || state.activeConfirmationId == confirmationId) {
      return false;
    }

    final existingIndex = state.messages.indexWhere(
      (m) =>
          m.type == ChatMessageType.confirmationRequired &&
          (m.data?['confirmation_id'] == confirmationId ||
              m.data?['action_id'] == confirmationId),
    );
    if (existingIndex != -1 && state.messages[existingIndex].isConfirmed) {
      return false;
    }

    emit(state.copyWith(
      isConfirming: true,
      activeConfirmationId: confirmationId,
      errorMessage: null,
    ));

    final idempotencyKey = _idempotency.prepareKeyForPayload(
      '$confirmationId:$action:$confirmed:${payload.toString()}',
    );

    try {
      final request = AssistantConfirmationRequest(
        conversationId: state.conversationId,
        confirmationId: confirmationId,
        action: action,
        confirmed: confirmed,
        payload: payload,
      );

      final response = await repository.confirmAction(
        request,
        idempotencyKey: idempotencyKey,
      );

      final updatedMessages = List<ChatMessage>.from(state.messages);
      if (existingIndex != -1) {
        final orig = updatedMessages[existingIndex];
        updatedMessages[existingIndex] = orig.copyWith(
          isConfirmed: confirmed,
          isCancelled: !confirmed,
        );
      }

      if (response.isSuccess) {
        final successMsg = ChatMessage(
          id: _uuid.v4(),
          role: ChatMessageRole.assistant,
          type: ChatMessageType.actionSuccess,
          content: response.message,
          data: {
            'action': response.action,
            'message': response.message,
            'transaction_id': response.result?['id']?.toString(),
            'details': response.result,
          },
          createdAt: DateTime.now(),
        );
        updatedMessages.add(successMsg);

        emit(state.copyWith(
          messages: updatedMessages,
          isConfirming: false,
          activeConfirmationId: null,
        ));

        onMutationSuccess?.call();
        return true;
      } else {
        final errorMsg = ChatMessage(
          id: _uuid.v4(),
          role: ChatMessageRole.assistant,
          type: ChatMessageType.actionError,
          content: response.message,
          data: {
            'error_code': 'CONFIRMATION_REJECTED',
            'message': response.message,
          },
          createdAt: DateTime.now(),
          hasError: true,
        );
        updatedMessages.add(errorMsg);

        emit(state.copyWith(
          messages: updatedMessages,
          isConfirming: false,
          activeConfirmationId: null,
          errorMessage: response.message,
        ));
        return false;
      }
    } on AppFailure catch (e) {
      _idempotency.handleFailure(
        isNetworkOrTimeoutOr5xx: e.code.contains('TIMEOUT') || e.code.contains('NETWORK'),
        payload: '$confirmationId:$action:$confirmed',
      );

      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.assistant,
        type: ChatMessageType.actionError,
        content: e.message,
        data: {'error_code': e.code, 'message': e.message},
        createdAt: DateTime.now(),
        hasError: true,
      );

      emit(state.copyWith(
        messages: [...state.messages, errorMsg],
        isConfirming: false,
        activeConfirmationId: null,
        errorMessage: e.message,
      ));
      return false;
    } catch (e) {
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.assistant,
        type: ChatMessageType.actionError,
        content: 'Execution failed: $e',
        data: {'error_code': 'CLIENT_EXCEPTION', 'message': e.toString()},
        createdAt: DateTime.now(),
        hasError: true,
      );

      emit(state.copyWith(
        messages: [...state.messages, errorMsg],
        isConfirming: false,
        activeConfirmationId: null,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<void> clearConversation() async {
    final oldConvId = state.conversationId;
    emit(AssistantState.initial(
      initialConversationId: 'conv-${DateTime.now().millisecondsSinceEpoch}',
    ));
    await repository.clearConversation(conversationId: oldConvId);
  }

  Future<void> retryLastMessage({String? activeMemberId, String? householdId}) async {
    final userMessages = state.messages.where((m) => m.role == ChatMessageRole.user);
    if (userMessages.isNotEmpty) {
      final lastUserMsg = userMessages.last;
      if (lastUserMsg.content.isNotEmpty) {
        await sendMessage(
          lastUserMsg.content,
          activeMemberId: activeMemberId,
          householdId: householdId,
        );
      }
    }
  }
}
