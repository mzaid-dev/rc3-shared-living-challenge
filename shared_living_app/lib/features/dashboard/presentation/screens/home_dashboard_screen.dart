import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/member_selector_bar.dart';
import '../widgets/net_balance_hero_card.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/recent_expenses_card.dart';

class HomeDashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToShopping;
  final VoidCallback onNavigateToExpenses;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToShopping,
    required this.onNavigateToExpenses,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.jade600),
          );
        }

        if (state is DashboardError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.coral600, size: 48),
                  const SizedBox(height: AppSpacing.spaceSm),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                  ElevatedButton(
                    onPressed: () => context.read<DashboardCubit>().refresh(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is DashboardLoaded) {
          final activeMemberName = state.dashboardData.member.name;

          return RefreshIndicator(
            color: AppColors.jade600,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<DashboardCubit>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Warm Greeting & Apartment Location
                  Padding(
                    padding: const EdgeInsets.only(left: 2.0, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assalam-o-Alaikum, $activeMemberName',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Gulberg apartment · November 2026',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Monthly Budget Progress Card (Near Limit 84%)
                  BudgetProgressCard(dashboardData: state.dashboardData),
                  const SizedBox(height: 12),

                  // 3. Deep Jade Net Balance Hero Card
                  NetBalanceHeroCard(
                    memberSummary: state.dashboardData.member,
                    balanceDetail: state.activeMemberBalance,
                    onQuickSettleTapped: onNavigateToExpenses,
                  ),
                  const SizedBox(height: 12),

                  // 4. Quick Micro-Metrics Row (3 cards: Pending, Housemates, Days Left)
                  QuickStatsRow(
                    pendingItemsCount: state.dashboardData.pendingItemsCount,
                    housematesCount: state.members.length,
                    daysLeft: 25,
                    onPendingTapped: onNavigateToShopping,
                  ),
                  const SizedBox(height: 16),

                  // 5. Active Roommate Perspective Selector
                  MemberSelectorBar(
                    members: state.members,
                    activeMemberId: state.activeMemberId,
                    balances: state.balances,
                    onMemberSelected: (id) {
                      context.read<DashboardCubit>().switchMember(id);
                    },
                  ),
                  const SizedBox(height: 18),

                  // 6. Recent Shared Bills Feed ("This month")
                  RecentExpensesCard(
                    expenses: state.recentExpenses,
                    members: state.members,
                    onViewAllTapped: onNavigateToExpenses,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
