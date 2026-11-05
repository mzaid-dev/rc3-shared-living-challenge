import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuickStatsRow extends StatelessWidget {
  final int pendingItemsCount;
  final int housematesCount;
  final int daysLeft;
  final VoidCallback onPendingTapped;

  const QuickStatsRow({
    super.key,
    required this.pendingItemsCount,
    required this.housematesCount,
    this.daysLeft = 25,
    required this.onPendingTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Pending Items
        Expanded(
          child: GestureDetector(
            onTap: onPendingTapped,
            child: _StatCard(
              icon: Icons.inventory_2_outlined,
              value: '$pendingItemsCount',
              label: 'pending items',
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Housemates
        Expanded(
          child: _StatCard(
            icon: Icons.group_outlined,
            value: '$housematesCount',
            label: 'housemates',
          ),
        ),
        const SizedBox(width: 8),

        // 3. Days Left in Month
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today_outlined,
            value: '$daysLeft',
            label: 'days left',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.jade900.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 17, color: AppColors.jade600),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
