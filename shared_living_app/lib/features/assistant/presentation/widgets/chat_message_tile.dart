import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';
import '../../data/models/assistant_dtos.dart';
import '../../data/models/chat_message.dart';
import 'assistant_avatar.dart';
import 'cards/action_error_card.dart';
import 'cards/action_success_card.dart';
import 'cards/balance_summary_card.dart';
import 'cards/budget_summary_card.dart';
import 'cards/confirmation_card.dart';
import 'cards/expense_summary_card.dart';
import 'cards/settlement_suggestions_card.dart';
import 'cards/shopping_list_card.dart';

class ChatMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isConfirming;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final ValueChanged<SettlementSuggestionItem>? onInitiateSettlement;
  final VoidCallback? onRetry;

  const ChatMessageTile({
    super.key,
    required this.message,
    this.isConfirming = false,
    this.onConfirm,
    this.onCancel,
    this.onInitiateSettlement,
    this.onRetry,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;

    if (isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildAssistantBubble(context);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    final timeStr = _formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.jade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.jade900.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      if (message.isPending) ...[
                        const SizedBox(width: 4),
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    final timeStr = _formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 28, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HisabAssistantAvatar(size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.content.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.jade900.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                        height: 1.35,
                      ),
                    ),
                  ),

                _buildStructuredCard(),

                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.faint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructuredCard() {
    final data = message.data;
    if (data == null) return const SizedBox.shrink();

    switch (message.type) {
      case ChatMessageType.expenseSummary:
        return ExpenseSummaryCard(data: ExpenseSummaryData.fromJson(data));

      case ChatMessageType.balanceSummary:
        return BalanceSummaryCard(data: BalanceSummaryData.fromJson(data));

      case ChatMessageType.shoppingList:
        return ShoppingListCard(data: ShoppingListData.fromJson(data));

      case ChatMessageType.budgetSummary:
        return BudgetSummaryCard(data: BudgetSummaryData.fromJson(data));

      case ChatMessageType.settlementSuggestions:
        return SettlementSuggestionsCard(
          data: SettlementSuggestionsData.fromJson(data),
          onInitiateSettlement: onInitiateSettlement,
        );

      case ChatMessageType.confirmationRequired:
        return ConfirmationCard(
          data: ConfirmationRequiredData.fromJson(data),
          isConfirming: isConfirming,
          isConfirmed: message.isConfirmed,
          isCancelled: message.isCancelled,
          onConfirm: onConfirm ?? () {},
          onCancel: onCancel ?? () {},
        );

      case ChatMessageType.actionSuccess:
        return ActionSuccessCard(data: ActionSuccessData.fromJson(data));

      case ChatMessageType.actionError:
        return ActionErrorCard(
          data: ActionErrorData.fromJson(data),
          onRetry: onRetry,
        );

      case ChatMessageType.text:
        return const SizedBox.shrink();
    }
  }
}
