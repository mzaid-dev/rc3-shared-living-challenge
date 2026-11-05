import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/hisab_logo.dart';
import '../../../auth/domain/models/auth_user.dart';
import '../../../dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../dashboard/presentation/cubit/dashboard_state.dart';
import '../../../dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../../expenses/presentation/cubit/expenses_cubit.dart';
import '../../../expenses/presentation/cubit/expenses_state.dart';
import '../../../expenses/presentation/screens/expenses_and_settle_screen.dart';
import '../../../expenses/presentation/widgets/add_expense_sheet.dart';
import '../../../expenses/presentation/widgets/settle_up_dialog.dart';
import '../../../home/presentation/widgets/home_header_menu.dart';
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
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AvatarStackItem(
                      initials: 'A',
                      color: AppColors.avatarAli,
                      isActive: activeMemberId == 'M01',
                      onTap: () => context.read<DashboardCubit>().switchMember('M01'),
                    ),
                    const SizedBox(width: 4),
                    _AvatarStackItem(
                      initials: 'Ay',
                      color: AppColors.avatarAyesha,
                      isActive: activeMemberId == 'M02',
                      onTap: () => context.read<DashboardCubit>().switchMember('M02'),
                    ),
                    const SizedBox(width: 4),
                    _AvatarStackItem(
                      initials: 'B',
                      color: AppColors.avatarBilal,
                      isActive: activeMemberId == 'M03',
                      onTap: () => context.read<DashboardCubit>().switchMember('M03'),
                    ),
                    const SizedBox(width: 10),
                    HomeHeaderMenu(user: widget.user),
                  ],
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              // Tab 0: Home Dashboard
              HomeDashboardScreen(
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
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _AvatarStackItem({
    required this.initials,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? color : AppColors.jade50,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? AppColors.jade500 : AppColors.line,
            width: isActive ? 1.8 : 1,
          ),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppColors.jade700,
            ),
          ),
        ),
      ),
    );
  }
}
