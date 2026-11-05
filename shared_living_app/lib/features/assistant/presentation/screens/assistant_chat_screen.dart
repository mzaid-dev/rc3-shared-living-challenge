import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:shared_living_app/core/theme/app_colors.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:shared_living_app/features/expenses/presentation/cubit/expenses_cubit.dart';
import 'package:shared_living_app/features/shopping/presentation/cubit/shopping_cubit.dart';
import '../../data/models/assistant_dtos.dart';
import '../cubit/assistant_cubit.dart';
import '../cubit/assistant_state.dart';
import '../widgets/assistant_app_bar.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_message_tile.dart';
import '../widgets/suggested_prompts_bar.dart';
import '../widgets/typing_indicator.dart';

class AssistantChatScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? activeMemberId;
  final String? householdId;

  const AssistantChatScreen({
    super.key,
    this.initialPrompt,
    this.activeMemberId,
    this.householdId,
  });

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
        context.read<AssistantCubit>().sendMessage(
              widget.initialPrompt!,
              activeMemberId: widget.activeMemberId,
              householdId: widget.householdId,
            );
      }
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
      );
    }
  }

  void _handleMutationSuccess() {
    if (!mounted) return;
    try {
      context.read<DashboardCubit>().refresh();
      context.read<ExpensesCubit>().loadExpensesAndBalances();
      context.read<ShoppingCubit>().loadShopping();
    } catch (_) {}
  }

  void _onConfirmAction(ConfirmationRequiredData confData) {
    context.read<AssistantCubit>().confirmAction(
          confirmationId: confData.confirmationId,
          action: confData.action,
          payload: confData.payload,
          confirmed: true,
          onMutationSuccess: _handleMutationSuccess,
        );
  }

  void _onCancelAction(ConfirmationRequiredData confData) {
    context.read<AssistantCubit>().confirmAction(
          confirmationId: confData.confirmationId,
          action: confData.action,
          payload: confData.payload,
          confirmed: false,
        );
  }

  void _onInitiateSettlement(SettlementSuggestionItem suggestion) {
    final prompt =
        'Record settlement: ${suggestion.senderName} pays PKR ${suggestion.amount} to ${suggestion.recipientName}';
    context.read<AssistantCubit>().sendMessage(
          prompt,
          activeMemberId: widget.activeMemberId,
          householdId: widget.householdId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssistantCubit, AssistantState>(
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AssistantAppBar(
            isOnline: state.isOnline,
            onClearConversation: () => context.read<AssistantCubit>().clearConversation(),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                  itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < state.messages.length) {
                      final message = state.messages[index];
                      final isCardConfirming = state.isConfirming &&
                          (state.activeConfirmationId == message.data?['confirmation_id'] ||
                              state.activeConfirmationId == message.data?['action_id']);

                      return ChatMessageTile(
                        message: message,
                        isConfirming: isCardConfirming,
                        onConfirm: () {
                          if (message.data != null) {
                            _onConfirmAction(
                              ConfirmationRequiredData.fromJson(message.data!),
                            );
                          }
                        },
                        onCancel: () {
                          if (message.data != null) {
                            _onCancelAction(
                              ConfirmationRequiredData.fromJson(message.data!),
                            );
                          }
                        },
                        onInitiateSettlement: _onInitiateSettlement,
                        onRetry: () => context.read<AssistantCubit>().retryLastMessage(
                              activeMemberId: widget.activeMemberId,
                              householdId: widget.householdId,
                            ),
                      );
                    } else {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12, left: 38),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TypingIndicator(),
                        ),
                      );
                    }
                  },
                ),
              ),

              SuggestedPromptsBar(
                prompts: state.suggestedPrompts,
                onSelectPrompt: (prompt) {
                  context.read<AssistantCubit>().sendMessage(
                        prompt,
                        activeMemberId: widget.activeMemberId,
                        householdId: widget.householdId,
                      );
                },
              ),

              ChatComposer(
                isSubmitting: state.isTyping,
                onSubmitted: (text) {
                  context.read<AssistantCubit>().sendMessage(
                        text,
                        activeMemberId: widget.activeMemberId,
                        householdId: widget.householdId,
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
