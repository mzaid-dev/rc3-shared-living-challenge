import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:shared_living_app/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';

void main() {
  late MockSharedLivingRepository repository;

  setUp(() {
    repository = MockSharedLivingRepository(latency: Duration.zero);
  });

  group('DashboardCubit Tests', () {
    test('Initial load emits [DashboardLoading, DashboardLoaded] with Ali benchmark telemetry', () async {
      final cubit = DashboardCubit(repository: repository);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const DashboardLoading(),
          isA<DashboardLoaded>()
              .having((s) => s.activeMemberId, 'activeMemberId', 'M01')
              .having((s) => s.dashboardData.percent, 'budgetPercent', 84)
              .having((s) => s.dashboardData.status, 'budgetStatus', 'near_limit')
              .having((s) => s.dashboardData.member.message, 'message', 'You are owed PKR 250.00')
              .having((s) => s.activeMemberBalance.netBalancePaisa, 'netBalancePaisa', 25000),
        ]),
      );

      await cubit.loadDashboard(memberId: 'M01');
      cubit.close();
    });

    test('Switching active member updates perspective to Ayesha (M02)', () async {
      final cubit = DashboardCubit(repository: repository);

      await cubit.loadDashboard(memberId: 'M01');
      expect((cubit.state as DashboardLoaded).activeMemberId, 'M01');

      await cubit.switchMember('M02');
      final loaded = cubit.state as DashboardLoaded;

      expect(loaded.activeMemberId, 'M02');
      expect(loaded.activeMemberBalance.netBalancePaisa, -45000); // -PKR 450.00
      expect(loaded.dashboardData.member.message, 'You owe PKR 450.00');
      cubit.close();
    });
  });
}
