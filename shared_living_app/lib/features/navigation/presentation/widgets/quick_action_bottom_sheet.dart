import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

class QuickActionBottomSheet extends StatelessWidget {
  final VoidCallback onLogExpense;
  final VoidCallback onAddShoppingItem;
  final VoidCallback onRecordSettlement;

  const QuickActionBottomSheet({
    super.key,
    required this.onLogExpense,
    required this.onAddShoppingItem,
    required this.onRecordSettlement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusSheetTop,
      ),
      padding: const EdgeInsets.only(left: 22, right: 22, top: 12, bottom: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grabber Handle
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick action',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.ink,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, color: AppColors.slate, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'What would you like to record for the apartment?',
            style: TextStyle(fontSize: 12.5, color: AppColors.slate),
          ),
          const SizedBox(height: 18),

          // Action 1: Log Shared Expense
          _QuickActionTile(
            icon: Icons.receipt_long_rounded,
            iconBg: AppColors.amber50,
            iconFg: AppColors.amber700,
            title: 'Log shared bill',
            subtitle: 'Add electricity, internet, or split a meal',
            onTap: () {
              Navigator.of(context).pop();
              onLogExpense();
            },
          ),
          const SizedBox(height: 10),

          // Action 2: Add Shopping Item
          _QuickActionTile(
            icon: Icons.shopping_bag_outlined,
            iconBg: AppColors.jade50,
            iconFg: AppColors.jade700,
            title: 'Add shopping item',
            subtitle: 'Request milk, eggs, or pantry supplies to buy',
            onTap: () {
              Navigator.of(context).pop();
              onAddShoppingItem();
            },
          ),
          const SizedBox(height: 10),

          // Action 3: Settle Up
          _QuickActionTile(
            icon: Icons.handshake_outlined,
            iconBg: AppColors.jade100,
            iconFg: AppColors.jade800,
            title: 'Record a payment (Settle up)',
            subtitle: 'Log direct cash or bank transfer to a roommate',
            onTap: () {
              Navigator.of(context).pop();
              onRecordSettlement();
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.jade900.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Icon(icon, color: iconFg, size: 21),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
