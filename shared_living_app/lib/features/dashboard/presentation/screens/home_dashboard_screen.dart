import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../assistant/presentation/screens/assistant_chat_screen.dart';
import '../../../auth/domain/models/auth_user.dart';
import '../../../shared_living/data/models/member.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/hero_financial_carousel.dart';
import '../widgets/member_selector_bar.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/recent_expenses_card.dart';
import '../widgets/switch_perspective_dialog.dart';

class HomeDashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToShopping;
  final VoidCallback onNavigateToExpenses;
  final AuthUser? authUser;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToShopping,
    required this.onNavigateToExpenses,
    this.authUser,
  });

  void _promptSwitchPerspective(
    BuildContext context,
    String targetMemberId,
    DashboardLoaded state,
  ) {
    if (state.activeMemberId == targetMemberId) return;

    final targetMember = state.members.firstWhere(
      (m) => m.id == targetMemberId,
      orElse: () => Member(id: targetMemberId, name: targetMemberId),
    );

    final targetBalance = state.balances.balances.firstWhere(
      (b) => b.memberId == targetMemberId,
      orElse: () => state.balances.balances.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => SwitchPerspectiveDialog(
        targetMember: targetMember,
        targetBalance: targetBalance,
        onConfirm: () {
          context.read<DashboardCubit>().switchMember(targetMemberId);
          Color color = AppColors.jade600;
          String initials = targetMember.name[0];
          if (targetMemberId == 'M01') {
            color = AppColors.avatarAli;
            initials = 'A';
          } else if (targetMemberId == 'M02') {
            color = AppColors.avatarAyesha;
            initials = 'Ay';
          } else if (targetMemberId == 'M03') {
            color = AppColors.avatarBilal;
            initials = 'B';
          }
          AppToast.showTopPerspectiveSwitch(
            context,
            memberName: targetMember.name,
            initials: initials,
            color: color,
          );
        },
      ),
    );
  }

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
          final effectiveAuthUser = authUser;
          final greetingName = effectiveAuthUser?.name.isNotEmpty == true
              ? effectiveAuthUser!.name
              : state.dashboardData.member.name;
          final isViewingOther = effectiveAuthUser != null && effectiveAuthUser.id != state.activeMemberId;

          return RefreshIndicator(
            color: AppColors.jade600,
            backgroundColor: AppColors.surface,
            onRefresh: () => context.read<DashboardCubit>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Warm Greeting & Apartment Location / Perspective Indicator
                  Padding(
                    padding: const EdgeInsets.only(left: 2.0, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assalam-o-Alaikum, $greetingName',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.ink,
                          ),
                        ),
                        if (isViewingOther) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.jade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.jade200),
                                ),
                                child: const Text(
                                  'VIEWING PERSPECTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: AppColors.jade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Viewing ${state.dashboardData.member.name}\'s ledger perspective',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 3),
                          const Text(
                            'Gulberg apartment · November 2026',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. Smooth Swipeable Hero Carousel (Net Balance & November Budget)
                  HeroFinancialCarousel(
                    memberSummary: state.dashboardData.member,
                    balanceDetail: state.activeMemberBalance,
                    dashboardData: state.dashboardData,
                    onQuickSettleTapped: onNavigateToExpenses,
                  ),
                  const SizedBox(height: 20),

                  // 3. Quick Micro-Metrics Row (3 cards: Pending, Housemates, Days Left)
                  QuickStatsRow(
                    pendingItemsCount: state.dashboardData.pendingItemsCount,
                    housematesCount: state.members.length,
                    daysLeft: 25,
                    onPendingTapped: onNavigateToShopping,
                  ),
                  const SizedBox(height: 18),

                  // 3.5. Hisab AI Copilot Quick Banner
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AssistantChatScreen(activeMemberId: state.activeMemberId),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.jade900, Color(0xFF134E3A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.jade900.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                            ),
                            child: const Center(
                              child: Icon(Icons.auto_awesome_rounded, color: AppColors.jade200, size: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Hisab AI Assistant',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF1B7A5A),
                                        borderRadius: BorderRadius.all(Radius.circular(4)),
                                      ),
                                      child: const Text(
                                        'COPILOT',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ask "Who owes money?" or log shared expenses',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFD4E7DE),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.jade200),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. Active Roommate Perspective Selector
                  MemberSelectorBar(
                    members: state.members,
                    activeMemberId: state.activeMemberId,
                    balances: state.balances,
                    authenticatedMemberId: authUser?.id,
                    onMemberSelected: (id) => _promptSwitchPerspective(context, id, state),
                  ),
                  const SizedBox(height: 18),

                  // 5. Recent Shared Bills Feed ("This month")
                  RecentExpensesCard(
                    expenses: state.recentExpenses,
                    members: state.members,
                    onViewAllTapped: onNavigateToExpenses,
                  ),
                  const SizedBox(height: 40),
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
