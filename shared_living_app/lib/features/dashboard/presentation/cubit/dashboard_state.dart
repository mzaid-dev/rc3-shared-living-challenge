import 'package:equatable/equatable.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/budget_and_dashboard.dart';
import '../../../shared_living/data/models/expense.dart';
import '../../../shared_living/data/models/member.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final String activeMemberId;
  final List<Member> members;
  final DashboardResponse dashboardData;
  final BalancesResponse balances;
  final List<Expense> recentExpenses;

  const DashboardLoaded({
    required this.activeMemberId,
    required this.members,
    required this.dashboardData,
    required this.balances,
    required this.recentExpenses,
  });

  MemberBalance get activeMemberBalance {
    return balances.balances.firstWhere(
      (b) => b.memberId == activeMemberId,
      orElse: () => balances.balances.first,
    );
  }

  @override
  List<Object?> get props => [
        activeMemberId,
        members,
        dashboardData,
        balances,
        recentExpenses,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError({required this.message});

  @override
  List<Object?> get props => [message];
}
