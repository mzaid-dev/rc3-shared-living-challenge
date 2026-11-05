import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../shared_living/domain/repositories/shared_living_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final SharedLivingRepository repository;
  String _activeMemberId = 'M01';
  int _activeRequestId = 0;

  DashboardCubit({required this.repository}) : super(const DashboardInitial());

  String get activeMemberId => _activeMemberId;

  Future<void> loadDashboard({String? memberId}) async {
    final requestId = ++_activeRequestId;
    if (memberId != null && memberId.isNotEmpty) {
      _activeMemberId = memberId;
    }

    // Only show full-screen loader on initial boot
    if (state is! DashboardLoaded) {
      emit(const DashboardLoading());
    }

    try {
      final members = await repository.getMembers();
      if (requestId != _activeRequestId) return; // Drop stale request

      // Ensure activeMemberId is validated against household members list
      final memberExists = members.any((m) => m.id == _activeMemberId);
      if (!memberExists && members.isNotEmpty) {
        _activeMemberId = members.first.id;
      }

      final dashboardData = await repository.getDashboard(memberId: _activeMemberId);
      if (requestId != _activeRequestId) return;

      final balances = await repository.getBalances();
      if (requestId != _activeRequestId) return;

      final allExpenses = await repository.getExpenses();
      if (requestId != _activeRequestId) return;

      final recent = allExpenses.take(3).toList();

      emit(DashboardLoaded(
        activeMemberId: _activeMemberId,
        members: members,
        dashboardData: dashboardData,
        balances: balances,
        recentExpenses: recent,
      ));
    } on AppFailure catch (f) {
      if (requestId == _activeRequestId) {
        emit(DashboardError(message: f.message));
      }
    } catch (e) {
      if (requestId == _activeRequestId) {
        emit(DashboardError(message: e.toString()));
      }
    }
  }

  Future<void> switchMember(String memberId) async {
    if (memberId == _activeMemberId && state is DashboardLoaded) return;
    _activeMemberId = memberId;
    await loadDashboard(memberId: memberId);
  }

  Future<void> refresh() async {
    await loadDashboard(memberId: _activeMemberId);
  }

  void reset() {
    _activeRequestId++;
    _activeMemberId = 'M01';
    emit(const DashboardInitial());
  }
}
