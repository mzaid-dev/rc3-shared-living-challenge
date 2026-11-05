import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../dashboard/presentation/cubit/dashboard_cubit.dart';
import '../cubit/expenses_cubit.dart';
import '../cubit/expenses_state.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/member_balances_card.dart';
import '../widgets/settle_up_dialog.dart';

class ExpensesAndSettleScreen extends StatefulWidget {
  final String activeMemberId;

  const ExpensesAndSettleScreen({super.key, required this.activeMemberId});

  @override
  State<ExpensesAndSettleScreen> createState() => _ExpensesAndSettleScreenState();
}

class _ExpensesAndSettleScreenState extends State<ExpensesAndSettleScreen> {
  int _selectedSubTab = 0; // 0: Expenses, 1: Balances

  void _openAddExpenseSheet(BuildContext context, ExpensesLoaded state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSheetTop,
      ),
      builder: (sheetContext) => AddExpenseSheet(
        members: state.members,
        initialPayerId: widget.activeMemberId,
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

  void _openSettleUpDialog(
    BuildContext context,
    ExpensesLoaded state, {
    String? prefillSenderId,
    String? prefillRecipientId,
    String? prefillAmount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSheetTop,
      ),
      builder: (dialogContext) => SettleUpDialog(
        members: state.members,
        balances: state.balances,
        prefillSenderId: prefillSenderId,
        prefillRecipientId: prefillRecipientId,
        prefillAmount: prefillAmount,
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpensesCubit, ExpensesState>(
      listener: (context, state) {
        if (state is ExpensesLoaded) {
          if (state.actionSuccessMessage != null) {
            AppToast.showSuccess(context, message: state.actionSuccessMessage!);
          }
          if (state.actionErrorMessage != null) {
            AppToast.showError(context, message: state.actionErrorMessage!);
          }
        }
      },
      builder: (context, state) {
        if (state is ExpensesLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.jade600));
        }

        if (state is ExpensesError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.coral600, size: 48),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<ExpensesCubit>().loadExpensesAndBalances(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is ExpensesLoaded) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            body: RefreshIndicator(
              color: AppColors.jade600,
              backgroundColor: AppColors.surface,
              onRefresh: () => context.read<ExpensesCubit>().loadExpensesAndBalances(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                children: [
                  // App Bar Style Title & Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedSubTab == 0 ? 'Expenses' : 'Balances',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedSubTab == 0
                                ? 'November · ${state.expenses.length} bills logged'
                                : 'Before settlements · sum is ${state.balances.sum}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Top Action Chip
                      GestureDetector(
                        onTap: () {
                          if (_selectedSubTab == 0) {
                            _openAddExpenseSheet(context, state);
                          } else {
                            _openSettleUpDialog(context, state);
                          }
                        },
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.jade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.jade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedSubTab == 0 ? Icons.add : Icons.handshake_outlined,
                                size: 14,
                                color: AppColors.jade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedSubTab == 0 ? 'Log bill' : 'Settle up',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.jade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sub-Tab Switcher: "Expenses" vs "Balances"
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSubTab = 0),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: _selectedSubTab == 0 ? AppColors.jade600 : AppColors.surface,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: _selectedSubTab == 0 ? AppColors.jade600 : AppColors.line,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Shared bills (${state.expenses.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedSubTab == 0 ? Colors.white : AppColors.slate,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSubTab = 1),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: _selectedSubTab == 1 ? AppColors.jade600 : AppColors.surface,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: _selectedSubTab == 1 ? AppColors.jade600 : AppColors.line,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Balances & Settle',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedSubTab == 1 ? Colors.white : AppColors.slate,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SUBTAB 0: EXPENSES FEED (Screen 3 in Spec)
                  if (_selectedSubTab == 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'This month',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.faint,
                            ),
                          ),
                          Text(
                            '${state.expenses.length} bills',
                            style: const TextStyle(fontSize: 11, color: AppColors.faint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.expenses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Center(
                          child: Text(
                            'No shared expenses logged yet.',
                            style: TextStyle(fontSize: 12, color: AppColors.faint),
                          ),
                        ),
                      )
                    else
                      ...state.expenses.map((expense) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ExpenseTile(expense: expense, members: state.members),
                        );
                      }),
                  ],

                  // SUBTAB 1: BALANCES & SMART SETTLE (Screen 4 in Spec)
                  if (_selectedSubTab == 1) ...[
                    MemberBalancesCard(
                      balances: state.balances,
                      onSettleUpTapped: () => _openSettleUpDialog(context, state),
                      onQuickSettleSelected: (senderId, recipientId, amount) {
                        _openSettleUpDialog(
                          context,
                          state,
                          prefillSenderId: senderId,
                          prefillRecipientId: recipientId,
                          prefillAmount: amount,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Settlement History
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Settlement history',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.jade50,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Center(
                              child: Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.jade600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Ayesha settled with Ali',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '5 Nov · direct transfer',
                                  style: TextStyle(fontSize: 11, color: AppColors.faint, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            '250.00',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 50),
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
