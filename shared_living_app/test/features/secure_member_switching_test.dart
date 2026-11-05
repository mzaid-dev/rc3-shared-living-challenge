import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/auth/domain/models/auth_user.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:shared_living_app/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:shared_living_app/features/shared_living/data/models/balances_response.dart';
import 'package:shared_living_app/features/shared_living/data/models/budget_and_dashboard.dart';
import 'package:shared_living_app/features/shared_living/data/models/member.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';

void main() {
  group('Secure Member Switching Tests', () {
    late MockSharedLivingRepository mockRepo;
    late DashboardCubit dashboardCubit;

    setUp(() {
      mockRepo = MockSharedLivingRepository(latency: Duration.zero);
      dashboardCubit = DashboardCubit(repository: mockRepo);
    });

    tearDown(() {
      dashboardCubit.close();
    });

    test('DashboardCubit switches active member perspective independently', () async {
      // 1. Initial load
      await dashboardCubit.loadDashboard(memberId: 'M01');
      expect(dashboardCubit.state, isA<DashboardLoaded>());
      var loaded = dashboardCubit.state as DashboardLoaded;
      expect(loaded.activeMemberId, 'M01');
      expect(loaded.dashboardData.member.id, 'M01');

      // 2. Switch to Ayesha (M02)
      await dashboardCubit.switchMember('M02');
      loaded = dashboardCubit.state as DashboardLoaded;
      expect(loaded.activeMemberId, 'M02');
      expect(loaded.dashboardData.member.id, 'M02');

      // 3. Switch to Bilal (M03)
      await dashboardCubit.switchMember('M03');
      loaded = dashboardCubit.state as DashboardLoaded;
      expect(loaded.activeMemberId, 'M03');
      expect(loaded.dashboardData.member.id, 'M03');
    });

    test('DashboardCubit.reset clears active member and cached data on logout', () async {
      await dashboardCubit.loadDashboard(memberId: 'M02');
      expect(dashboardCubit.state, isA<DashboardLoaded>());

      dashboardCubit.reset();
      expect(dashboardCubit.state, isA<DashboardInitial>());
    });

    testWidgets('HomeDashboardScreen displays (You) tag and perspective indicator', (tester) async {
      const authUser = AuthUser(id: 'M01', name: 'Ali', email: 'ali@demo.pk');

      const mockMembers = [
        Member(id: 'M01', name: 'Ali'),
        Member(id: 'M02', name: 'Ayesha'),
        Member(id: 'M03', name: 'Bilal'),
      ];

      const mockBalances = BalancesResponse(
        balances: [
          MemberBalance(
            memberId: 'M01',
            name: 'Ali',
            totalPaid: '4,200.00',
            shareOwed: '3,950.00',
            settlementsReceived: '0.00',
            settlementsSent: '0.00',
            netBalance: '+250.00',
            netBalancePaisa: 25000,
            status: 'owed',
          ),
          MemberBalance(
            memberId: 'M02',
            name: 'Ayesha',
            totalPaid: '900.00',
            shareOwed: '1,350.00',
            settlementsReceived: '0.00',
            settlementsSent: '0.00',
            netBalance: '-450.00',
            netBalancePaisa: -45000,
            status: 'owes',
          ),
        ],
        sum: '0.00',
        sumPaisa: 0,
      );

      const mockDashboard = DashboardResponse(
        month: 'November',
        spent: '4200.00',
        spentPaisa: 420000,
        limit: '5000.00',
        limitPaisa: 500000,
        remaining: '800.00',
        remainingPaisa: 80000,
        percent: 84,
        status: 'near_limit',
        member: DashboardMemberSummary(
          id: 'M02',
          name: 'Ayesha',
          netBalancePaisa: -45000,
          message: 'You owe PKR 450.00',
        ),
        pendingItemsCount: 3,
      );

      Widget createTestWidget() {
        return MaterialApp(
          home: Scaffold(
            body: BlocProvider<DashboardCubit>.value(
              value: dashboardCubit,
              child: const HomeDashboardScreen(
                authUser: authUser,
                onNavigateToShopping: _dummy,
                onNavigateToExpenses: _dummy,
              ),
            ),
          ),
        );
      }

      // Pre-seed DashboardCubit with Ayesha's perspective while Ali is authenticated
      dashboardCubit.emit(const DashboardLoaded(
        activeMemberId: 'M02',
        members: mockMembers,
        dashboardData: mockDashboard,
        balances: mockBalances,
        recentExpenses: [],
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Authenticated greeting must address Ali
      expect(find.text('Assalam-o-Alaikum, Ali'), findsOneWidget);

      // Must clearly display VIEWING PERSPECTIVE badge
      expect(find.text('VIEWING PERSPECTIVE'), findsOneWidget);
      expect(find.text("Viewing Ayesha's ledger perspective"), findsOneWidget);

      // Roommate selector must mark Ali as (You)
      expect(find.text('Ali (You)'), findsOneWidget);
      expect(find.text('Ayesha'), findsOneWidget);
    });
  });
}

void _dummy() {}

