import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/dashboard/presentation/widgets/budget_progress_card.dart';
import 'package:shared_living_app/features/dashboard/presentation/widgets/hero_financial_carousel.dart';
import 'package:shared_living_app/features/dashboard/presentation/widgets/net_balance_hero_card.dart';
import 'package:shared_living_app/features/shared_living/data/models/balances_response.dart';
import 'package:shared_living_app/features/shared_living/data/models/budget_and_dashboard.dart';

void main() {
  group('HeroFinancialCarousel Tests', () {
    const mockMemberSummary = DashboardMemberSummary(
      id: 'M01',
      name: 'Ali',
      netBalancePaisa: 25000,
      message: 'You are owed PKR 250.00',
    );

    const mockBalanceDetail = MemberBalance(
      memberId: 'M01',
      name: 'Ali',
      totalPaid: '4,200.00',
      shareOwed: '3,950.00',
      settlementsReceived: '0.00',
      settlementsSent: '0.00',
      netBalance: '+250.00',
      netBalancePaisa: 25000,
      status: 'owed',
    );

    const mockDashboardData = DashboardResponse(
      month: 'November',
      spent: '4200.00',
      spentPaisa: 420000,
      limit: '5000.00',
      limitPaisa: 500000,
      remaining: '800.00',
      remainingPaisa: 80000,
      percent: 84,
      status: 'near_limit',
      member: mockMemberSummary,
      pendingItemsCount: 3,
    );

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroFinancialCarousel(
              memberSummary: mockMemberSummary,
              balanceDetail: mockBalanceDetail,
              dashboardData: mockDashboardData,
              onQuickSettleTapped: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('Renders primary Net Balance hero card without tab bars', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // No tab buttons exist
      expect(find.text('Your Balance'), findsNothing);

      // Primary hero card is displayed
      expect(find.byType(NetBalanceHeroCard), findsOneWidget);
      expect(find.text('YOUR NET BALANCE'), findsOneWidget);
    });

    testWidgets('Flinging carousel reveals budget progress card', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Fling left on the PageView
      await tester.fling(find.byType(PageView), const Offset(-500.0, 0.0), 1000.0);
      await tester.pumpAndSettle();

      expect(find.byType(BudgetProgressCard), findsOneWidget);
      expect(find.text('November budget'), findsOneWidget);
    });
  });
}
