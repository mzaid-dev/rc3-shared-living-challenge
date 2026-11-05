import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../shared_living/data/models/budget_and_dashboard.dart';

class BudgetProgressCard extends StatelessWidget {
  final DashboardResponse dashboardData;

  const BudgetProgressCard({super.key, required this.dashboardData});

  String _formatPkr(String rawAmount) {
    try {
      return Money.parse(rawAmount).format();
    } catch (_) {
      return 'PKR $rawAmount';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = dashboardData.percent;
    final isNearLimit = dashboardData.status == 'near_limit';
    final isOverBudget = dashboardData.status == 'over_budget';

    Color progressColorStart = AppColors.jade600;
    Color progressColorEnd = AppColors.jade500;
    Color badgeBg = AppColors.jade50;
    Color badgeFg = AppColors.jade700;
    String badgeText = '$percent% ON TRACK';

    if (isOverBudget) {
      progressColorStart = AppColors.coral700;
      progressColorEnd = AppColors.coral500;
      badgeBg = AppColors.coral50;
      badgeFg = AppColors.coral700;
      badgeText = 'OVER BUDGET · $percent%';
    } else if (isNearLimit) {
      progressColorStart = AppColors.amber600;
      progressColorEnd = AppColors.amber500;
      badgeBg = AppColors.amber500;
      badgeFg = Colors.white;
      badgeText = 'NEAR LIMIT · $percent%';
    }

    final double progressFraction = (percent / 100).clamp(0.0, 1.0);
    final spentFormatted = _formatPkr(dashboardData.spent);
    final limitFormatted = _formatPkr(dashboardData.limit);
    final remainingFormatted = _formatPkr(dashboardData.remaining);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusCard,
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A000000),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Month Label & Warning Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${dashboardData.month} budget',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: AppRadius.radiusTag,
                  border: isNearLimit
                      ? null
                      : Border.all(color: badgeFg.withValues(alpha: 0.2)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),

          // Middle Row: Spent Amount & Limit
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                spentFormatted,
                style: AppTypography.displayLarge.copyWith(fontSize: 27),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'of $limitFormatted',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.faint,
                  ),
                ),
              ),
            ],
          ),

          // Custom Progress Track
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.lineSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progressFraction,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [progressColorStart, progressColorEnd],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),

          // Bottom Row: Remaining amount & Bill count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remainingFormatted remaining',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber700,
                ),
              ),
              const Text(
                '4 shared bills',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.faint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
