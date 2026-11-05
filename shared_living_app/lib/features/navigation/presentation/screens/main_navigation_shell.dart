import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/hisab_logo.dart';
import '../../../auth/domain/models/auth_user.dart';
import '../../../dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../dashboard/presentation/cubit/dashboard_state.dart';
import '../../../dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../../dashboard/presentation/widgets/switch_perspective_dialog.dart';
import '../../../expenses/presentation/cubit/expenses_cubit.dart';
import '../../../expenses/presentation/cubit/expenses_state.dart';
import '../../../expenses/presentation/screens/expenses_and_settle_screen.dart';
import '../../../expenses/presentation/widgets/add_expense_sheet.dart';
import '../../../expenses/presentation/widgets/settle_up_dialog.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../shared_living/data/models/member.dart';
import '../../../shopping/presentation/cubit/shopping_cubit.dart';
import '../../../shopping/presentation/screens/shopping_screen.dart';
import '../../../shopping/presentation/widgets/add_shopping_item_sheet.dart';
import '../widgets/hisab_bottom_nav_bar.dart';
import '../widgets/quick_action_bottom_sheet.dart';

class MainNavigationShell extends StatefulWidget {
  final AuthUser user;

  const MainNavigationShell({super.key, required this.user});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load initial data for all features
    context.read<DashboardCubit>().loadDashboard(memberId: widget.user.id);
    context.read<ShoppingCubit>().loadShopping();
    context.read<ExpensesCubit>().loadExpensesAndBalances();
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  void _promptSwitchPerspective(
    BuildContext context,
    String targetMemberId,
    DashboardState dashState,
  ) {
    if (dashState is! DashboardLoaded) return;
    if (dashState.activeMemberId == targetMemberId) return;

    final targetMember = dashState.members.firstWhere(
      (m) => m.id == targetMemberId,
      orElse: () => Member(id: targetMemberId, name: targetMemberId),
    );

    final targetBalance = dashState.balances.balances.firstWhere(
      (b) => b.memberId == targetMemberId,
      orElse: () => dashState.balances.balances.first,
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

  void _openQuickActionSheet(BuildContext context, String activeMemberId, List<Member> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSheetTop,
      ),
      builder: (sheetContext) => QuickActionBottomSheet(
        onLogExpense: () => _openAddExpenseModal(context, activeMemberId, members),
        onAddShoppingItem: () => _openAddShoppingModal(context),
        onRecordSettlement: () => _openRecordSettlementModal(context, members),
      ),
    );
  }

  void _openAddExpenseModal(BuildContext context, String activeMemberId, List<Member> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSheetTop,
      ),
      builder: (sheetContext) => AddExpenseSheet(
        members: members,
        initialPayerId: activeMemberId,
        onSubmit: (dto, key) async {
          final success = await context.read<ExpensesCubit>().addExpense(dto, idempotencyKey: key);
          if (success && context.mounted) {
            context.read<DashboardCubit>().refresh();
          }
          return success;
        },
      ),
    );
  }

  void _openAddShoppingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSheetTop,
      ),
      builder: (sheetContext) => AddShoppingItemSheet(
        onSubmit: (dto, key) async {
          final success = await context.read<ShoppingCubit>().addItem(dto, idempotencyKey: key);
          if (success && context.mounted) {
            context.read<DashboardCubit>().refresh();
          }
          return success;
        },
      ),
    );
  }

  void _openRecordSettlementModal(BuildContext context, List<Member> members) {
    final expState = context.read<ExpensesCubit>().state;
    if (expState is ExpensesLoaded) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.radiusSheetTop,
        ),
        builder: (sheetContext) => SettleUpDialog(
          members: members,
          balances: expState.balances,
          onConfirmSettlement: (dto, key) async {
            final success = await context.read<ExpensesCubit>().recordSettlement(dto, idempotencyKey: key);
            if (success && context.mounted) {
              context.read<DashboardCubit>().refresh();
            }
            return success;
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, dashState) {
        final activeMemberId = dashState is DashboardLoaded
            ? dashState.activeMemberId
            : widget.user.id;
        final members = dashState is DashboardLoaded ? dashState.members : const <Member>[];

        return Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(
            backgroundColor: AppColors.canvas,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 16,
            title: Row(
              children: const [
                HisabLogoMark(size: 30, borderRadius: 9),
                SizedBox(width: 8),
                HisabBrandWordmark(fontSize: 19),
              ],
            ),
            actions: [
              // Roommate Avatars Stack (Ali, Ayesha, Bilal)
              Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.jade900.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AvatarStackItem(
                        initials: 'A',
                        name: 'Ali',
                        color: AppColors.avatarAli,
                        isActive: activeMemberId == 'M01',
                        onTap: () => _promptSwitchPerspective(context, 'M01', dashState),
                      ),
                      const SizedBox(width: 3),
                      _AvatarStackItem(
                        initials: 'Ay',
                        name: 'Ayesha',
                        color: AppColors.avatarAyesha,
                        isActive: activeMemberId == 'M02',
                        onTap: () => _promptSwitchPerspective(context, 'M02', dashState),
                      ),
                      const SizedBox(width: 3),
                      _AvatarStackItem(
                        initials: 'B',
                        name: 'Bilal',
                        color: AppColors.avatarBilal,
                        isActive: activeMemberId == 'M03',
                        onTap: () => _promptSwitchPerspective(context, 'M03', dashState),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              // Tab 0: Home Dashboard
              HomeDashboardScreen(
                authUser: widget.user,
                onNavigateToShopping: () => _onTabSelected(1),
                onNavigateToExpenses: () => _onTabSelected(2),
              ),

              // Tab 1: Shopping List & Checkout
              ShoppingScreen(
                members: members,
                activeMemberId: activeMemberId,
              ),

              // Tab 2: Balances & Expenses (with segmented views)
              ExpensesAndSettleScreen(
                activeMemberId: activeMemberId,
              ),

              // Tab 3: Settings & Household Preferences
              SettingsScreen(user: widget.user),
            ],
          ),
          // Custom Hisab Bottom Navigation Bar matching user image
          bottomNavigationBar: HisabBottomNavBar(
            currentIndex: _currentIndex,
            onTabSelected: _onTabSelected,
            onCenterActionTap: () => _openQuickActionSheet(context, activeMemberId, members),
          ),
        );
      },
    );
  }
}

class _AvatarStackItem extends StatelessWidget {
  final String initials;
  final String name;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _AvatarStackItem({
    required this.initials,
    required this.name,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: isActive ? 30 : 26,
        height: isActive ? 30 : 26,
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.white : Colors.transparent,
            width: isActive ? 2.0 : 0.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: isActive ? 11 : 9.5,
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : color,
            ),
            child: Text(initials),
          ),
        ),
      ),
    );
  }
}
