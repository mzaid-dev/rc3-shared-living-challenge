import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class PendingShoppingCard extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onShopTapped;

  const PendingShoppingCard({
    super.key,
    required this.pendingCount,
    required this.onShopTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: pendingCount > 0
              ? AppColors.accentEmerald.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPine,
              borderRadius: AppRadius.radiusMd,
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              color: AppColors.accentEmerald,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendingCount > 0 ? 'Grocery Run Needed' : 'Pantry Fully Stocked',
                  style: AppTypography.titleMedium.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingCount > 0
                      ? '$pendingCount pending items in shopping list'
                      : 'All household items are bought',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onShopTapped,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: AppColors.accentEmerald,
              foregroundColor: AppColors.backgroundSlate,
            ),
            child: const Text('View List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
