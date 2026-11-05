import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../shared_living/domain/repositories/shared_living_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SharedLivingRepository repository;
  String _activeMemberId = 'M01'; // Default to Ali (M01)

  DashboardCubit({required this.repository}) : super(const DashboardInitial());

  String get activeMemberId => _activeMemberId;

  Future<void> loadDashboard({String? memberId}) async {
    if (memberId != null) {
      _activeMemberId = memberId;
    }
    emit(const DashboardLoading());

    try {
      final members = await repository.getMembers();
      final dashboardData = await repository.getDashboard(memberId: _activeMemberId);
      final balances = await repository.getBalances();
      final allExpenses = await repository.getExpenses();
      final recent = allExpenses.take(3).toList();

      emit(DashboardLoaded(
        activeMemberId: _activeMemberId,
        members: members,
        dashboardData: dashboardData,
        balances: balances,
        recentExpenses: recent,
      ));
    } on AppFailure catch (f) {
      emit(DashboardError(message: f.message));
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }

  Future<void> switchMember(String memberId) async {
    _activeMemberId = memberId;
    await loadDashboard(memberId: memberId);
  }

  Future<void> refresh() async {
    await loadDashboard(memberId: _activeMemberId);
  }
}
