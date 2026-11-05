import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../dashboard/presentation/cubit/dashboard_cubit.dart';
import '../../../shared_living/data/models/member.dart';
import '../cubit/shopping_cubit.dart';
import '../cubit/shopping_state.dart';
import '../widgets/add_shopping_item_sheet.dart';
import '../widgets/shopping_checkout_sheet.dart';
import '../widgets/shopping_item_tile.dart';

class ShoppingScreen extends StatefulWidget {
  final List<Member> members;
  final String activeMemberId;

  const ShoppingScreen({
    super.key,
    required this.members,
    required this.activeMemberId,
  });

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'bought'

  void _openAddItemSheet(BuildContext context) {
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

  void _openCheckoutSheet(BuildContext context, ShoppingLoaded state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSheetTop,
      ),
      builder: (sheetContext) => ShoppingCheckoutSheet(
        selectedItems: state.selectedItems,
        members: widget.members,
        initialPayerId: widget.activeMemberId,
        onConfirmCheckout: (dto, key) async {
          final success = await context.read<ShoppingCubit>().checkout(dto, idempotencyKey: key);
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
    return BlocConsumer<ShoppingCubit, ShoppingState>(
      listener: (context, state) {
        if (state is ShoppingLoaded) {
          if (state.actionSuccessMessage != null) {
            AppToast.showSuccess(context, message: state.actionSuccessMessage!);
          }
          if (state.actionErrorMessage != null) {
            AppToast.showError(context, message: state.actionErrorMessage!);
          }
        }
      },
      builder: (context, state) {
        if (state is ShoppingLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.jade600));
        }

        if (state is ShoppingError) {
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
                  onPressed: () => context.read<ShoppingCubit>().loadShopping(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is ShoppingLoaded) {
          final pending = state.pendingItems;
          final bought = state.boughtItems;
          final selectedCount = state.selectedItemIds.length;

          final showPending = _selectedFilter == 'all' || _selectedFilter == 'pending';
          final showBought = _selectedFilter == 'all' || _selectedFilter == 'bought';

          return Scaffold(
            backgroundColor: AppColors.canvas,
            body: RefreshIndicator(
              color: AppColors.jade600,
              backgroundColor: AppColors.surface,
              onRefresh: () => context.read<ShoppingCubit>().loadShopping(),
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
                          const Text(
                            'Shopping list',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pending.length} pending · ${bought.length} bought this week',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // Add item chip button
                      GestureDetector(
                        onTap: () => _openAddItemSheet(context),
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
                            children: const [
                              Icon(Icons.add, size: 14, color: AppColors.jade700),
                              SizedBox(width: 4),
                              Text(
                                'Add item',
                                style: TextStyle(
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

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All items',
                          isSelected: _selectedFilter == 'all',
                          onTap: () => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Pending (${pending.length})',
                          isSelected: _selectedFilter == 'pending',
                          onTap: () => setState(() => _selectedFilter = 'pending'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Bought (${bought.length})',
                          isSelected: _selectedFilter == 'bought',
                          onTap: () => setState(() => _selectedFilter = 'bought'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pending Items Section
                  if (showPending) ...[
                    if (pending.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.check_circle_outline, color: AppColors.jade600, size: 36),
                            SizedBox(height: 8),
                            Text(
                              'The list is clear',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'All requested groceries and household items are bought.',
                              style: TextStyle(fontSize: 11.5, color: AppColors.slate),
                            ),
                          ],
                        ),
                      )
                    else
                      ...pending.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ShoppingItemTile(
                            item: item,
                            isSelected: state.selectedItemIds.contains(item.id),
                            onSelectedChanged: (_) {
                              context.read<ShoppingCubit>().toggleItemSelection(item.id);
                            },
                          ),
                        );
                      }),
                  ],

                  // Bought section
                  if (showBought && bought.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Bought',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Auto-expired 7d',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...bought.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ShoppingItemTile(
                          item: item,
                          isSelected: false,
                          onSelectedChanged: null,
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 90),
                ],
              ),
            ),
            // Floating Checkout Action Bar when items selected
            bottomNavigationBar: selectedCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: const Border(top: BorderSide(color: AppColors.line)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.jade900.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$selectedCount items selected',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.read<ShoppingCubit>().clearSelection(),
                                  child: const Text(
                                    'Clear selection',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.coral600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _openCheckoutSheet(context, state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.jade600,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                            child: const Text(
                              'Checkout Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.jade600 : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.jade600 : AppColors.line,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.slate,
            ),
          ),
        ),
      ),
    );
  }
}
