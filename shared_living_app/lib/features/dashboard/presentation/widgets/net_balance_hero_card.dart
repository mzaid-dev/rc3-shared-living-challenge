import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/budget_and_dashboard.dart';

class NetBalanceHeroCard extends StatelessWidget {
  final DashboardMemberSummary memberSummary;
  final MemberBalance balanceDetail;
  final VoidCallback? onQuickSettleTapped;

  const NetBalanceHeroCard({
    super.key,
    required this.memberSummary,
    required this.balanceDetail,
    this.onQuickSettleTapped,
  });

  @override
  Widget build(BuildContext context) {
    final netPaisa = balanceDetail.netBalancePaisa;
    final isPositive = netPaisa > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.jade700,
            AppColors.jade600,
          ],
        ),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.jade900.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'YOUR NET BALANCE',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xBFFFFFFF), // 75% white
                  ),
                ),
                Text(
                  isPositive
                      ? '+${Money.fromPaisa(netPaisa).format()}'
                      : Money.fromPaisa(netPaisa).format(),
                  style: AppTypography.currencyHero.copyWith(
                    color: Colors.white,
                    fontSize: 29,
                  ),
                ),
                Text(
                  memberSummary.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xD9FFFFFF), // 85% white
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Fast Action Icon Button
          GestureDetector(
            onTap: onQuickSettleTapped,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_outward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
