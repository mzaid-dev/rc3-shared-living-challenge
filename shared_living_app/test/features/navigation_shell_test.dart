import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/auth/domain/models/auth_user.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:shared_living_app/features/expenses/presentation/cubit/expenses_cubit.dart';
import 'package:shared_living_app/features/navigation/presentation/screens/main_navigation_shell.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';
import 'package:shared_living_app/features/shopping/presentation/cubit/shopping_cubit.dart';

void main() {
  testWidgets('MainNavigationShell renders custom Hisab bottom nav bar and switches views', (WidgetTester tester) async {
    final repository = MockSharedLivingRepository(latency: Duration.zero);
    const demoUser = AuthUser(id: 'M01', name: 'Ali', email: 'ali@demo.pk');

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => DashboardCubit(repository: repository)),
          BlocProvider(create: (_) => ShoppingCubit(repository: repository)),
          BlocProvider(create: (_) => ExpensesCubit(repository: repository)),
        ],
        child: const MaterialApp(
          home: MainNavigationShell(user: demoUser),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();

    // Verify navigation bar items exist matching the user spec
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(find.text('Balances'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Home tab content
    expect(find.text('Assalam-o-Alaikum, Ali'), findsOneWidget);
    expect(find.text('YOUR NET BALANCE'), findsOneWidget);

    // Tap Shopping tab
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();

    expect(find.text('Shopping list'), findsOneWidget);
    expect(find.text('All items'), findsOneWidget);

    // Tap Balances tab
    await tester.tap(find.text('Balances'));
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Balances & Settle'), findsOneWidget);

    // Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('HOUSEHOLD APARTMENT'), findsOneWidget);
    expect(find.text('Gulberg 4B, Lahore'), findsOneWidget);
  });
}
