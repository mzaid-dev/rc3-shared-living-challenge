import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/assistant/data/repositories/mock_assistant_repository.dart';
import 'package:shared_living_app/features/assistant/presentation/cubit/assistant_cubit.dart';
import 'package:shared_living_app/features/assistant/presentation/screens/assistant_chat_screen.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:shared_living_app/features/expenses/presentation/cubit/expenses_cubit.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';
import 'package:shared_living_app/features/shopping/presentation/cubit/shopping_cubit.dart';

void main() {
  testWidgets('AssistantChatScreen renders app bar, welcome message, and prompts',
      (WidgetTester tester) async {
    final mockSharedRepo = MockSharedLivingRepository();
    final mockAssistantRepo = MockAssistantRepository();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<DashboardCubit>(
            create: (_) => DashboardCubit(repository: mockSharedRepo),
          ),
          BlocProvider<ExpensesCubit>(
            create: (_) => ExpensesCubit(repository: mockSharedRepo),
          ),
          BlocProvider<ShoppingCubit>(
            create: (_) => ShoppingCubit(repository: mockSharedRepo),
          ),
          BlocProvider<AssistantCubit>(
            create: (_) => AssistantCubit(repository: mockAssistantRepo),
          ),
        ],
        child: const MaterialApp(
          home: AssistantChatScreen(activeMemberId: 'M01'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Header Elements
    expect(find.text('Hisab Assistant'), findsOneWidget);
    expect(find.text('Active Copilot'), findsOneWidget);

    // Verify Initial Welcome Message
    expect(find.textContaining('Assalam-o-Alaikum! I am your Hisab Assistant'), findsOneWidget);

    // Verify Suggested Prompts
    expect(find.text('How much did our household spend this month?'), findsOneWidget);
    expect(find.text('Show my balance'), findsOneWidget);

    // Tap a suggested prompt
    await tester.tap(find.text('Show my balance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify that Balance summary card rendered
    expect(find.text('Household Balance Ledger'), findsOneWidget);
  });
}
