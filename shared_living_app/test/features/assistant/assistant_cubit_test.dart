import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/assistant/data/models/chat_message.dart';
import 'package:shared_living_app/features/assistant/data/repositories/mock_assistant_repository.dart';
import 'package:shared_living_app/features/assistant/presentation/cubit/assistant_cubit.dart';

void main() {
  group('AssistantCubit State Transition & Workflow Tests', () {
    late MockAssistantRepository mockRepo;
    late AssistantCubit cubit;

  setUp(() {
    mockRepo = MockAssistantRepository();
    cubit = AssistantCubit(repository: mockRepo);
  });

  tearDown(() {
    cubit.close();
  });

  test('Initial state contains welcome message and default prompts', () {
    expect(cubit.state.messages.length, 1);
    expect(cubit.state.messages.first.role, ChatMessageRole.assistant);
    expect(cubit.state.suggestedPrompts.isNotEmpty, true);
    expect(cubit.state.isTyping, false);
    expect(cubit.state.isOnline, true);
  });

  test('sendMessage appends user message and resolves assistant response', () async {
    await cubit.sendMessage('How much did our household spend this month?');

    expect(cubit.state.messages.length, 3); // initial + user + assistant
    expect(cubit.state.messages[1].role, ChatMessageRole.user);
    expect(cubit.state.messages[1].content, 'How much did our household spend this month?');
    expect(cubit.state.messages[2].role, ChatMessageRole.assistant);
    expect(cubit.state.messages[2].type, ChatMessageType.budgetSummary);
    expect(cubit.state.isTyping, false);
  });

  test('sendMessage for expense triggers confirmation_required card', () async {
    await cubit.sendMessage('Add 1500 PKR groceries paid by Ali');

    final lastMsg = cubit.state.messages.last;
    expect(lastMsg.role, ChatMessageRole.assistant);
    expect(lastMsg.type, ChatMessageType.confirmationRequired);
    expect(lastMsg.data?['action'], 'create_expense');
    expect(lastMsg.data?['confirmation_id'], isNotNull);
  });

  test('confirmAction executes financial mutation and emits action_success receipt', () async {
    await cubit.sendMessage('Add 1500 PKR groceries paid by Ali');
    final confMsg = cubit.state.messages.last;
    final confId = confMsg.data!['confirmation_id'] as String;

    bool callbackFired = false;
    final success = await cubit.confirmAction(
      confirmationId: confId,
      action: 'create_expense',
      payload: {'title': 'Groceries', 'amount': '1500.00'},
      confirmed: true,
      onMutationSuccess: () => callbackFired = true,
    );

    expect(success, true);
    expect(callbackFired, true);

    // Verified that action_success message was appended
    final finalMsg = cubit.state.messages.last;
    expect(finalMsg.type, ChatMessageType.actionSuccess);
    expect(finalMsg.content.contains('Groceries'), true);

    // Verified that original confirmation card is marked as confirmed
    final updatedConfMsg = cubit.state.messages.firstWhere(
      (m) => m.type == ChatMessageType.confirmationRequired,
    );
    expect(updatedConfMsg.isConfirmed, true);
  });

  test('confirmAction prevents double execution on repeated invocation', () async {
    await cubit.sendMessage('Add 1500 PKR groceries paid by Ali');
    final confMsg = cubit.state.messages.last;
    final confId = confMsg.data!['confirmation_id'] as String;

    // First execution
    final firstSuccess = await cubit.confirmAction(
      confirmationId: confId,
      action: 'create_expense',
      payload: {'title': 'Groceries', 'amount': '1500.00'},
      confirmed: true,
    );
    expect(firstSuccess, true);

    // Repeated execution of the same confirmed action
    final secondSuccess = await cubit.confirmAction(
      confirmationId: confId,
      action: 'create_expense',
      payload: {'title': 'Groceries', 'amount': '1500.00'},
      confirmed: true,
    );
    expect(secondSuccess, false); // Guarded!
  });

  test('clearConversation resets history to initial clean state', () async {
    await cubit.sendMessage('Show my balance');
    expect(cubit.state.messages.length, 3);

    await cubit.clearConversation();
    expect(cubit.state.messages.length, 1);
    expect(cubit.state.messages.first.content.contains('Assalam-o-Alaikum'), true);
  });
  });
}
