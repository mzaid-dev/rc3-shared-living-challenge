import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../shared_living/data/models/expense.dart';
import '../../../shared_living/data/models/member.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final List<Member> members;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.members,
  });

  String _getPayerName(String payerId) {
    return members.firstWhere((m) => m.id == payerId, orElse: () => Member(id: payerId, name: payerId)).name;
  }

  (Color, Color, IconData) _getCategoryAppearance(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('utilit') || cat.contains('elect') || cat.contains('bill')) {
      return (AppColors.catUtilitiesBg, AppColors.catUtilitiesFg, Icons.bolt_rounded);
    }
    if (cat.contains('inter') || cat.contains('wifi')) {
      return (AppColors.catUtilitiesBg, AppColors.catUtilitiesFg, Icons.wifi_rounded);
    }
    if (cat.contains('clean')) {
      return (AppColors.catCleaningBg, AppColors.catCleaningFg, Icons.cleaning_services_rounded);
    }
    return (AppColors.catGroceriesBg, AppColors.catGroceriesFg, Icons.shopping_bag_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final payerName = _getPayerName(expense.payerId);
    final (catBg, catFg, catIcon) = _getCategoryAppearance(expense.category);
    final isCustom = expense.splitType == 'custom';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: catBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(catIcon, color: catFg, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.amber50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.amber100),
                        ),
                        child: const Text(
                          'CUSTOM SPLIT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amber700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.date} · $payerName paid · ${isCustom ? "Custom" : "${expense.splits.length}-way split"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),

          // Tabular Amount and Split Tag
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${expense.amount}',
                style: AppTypography.currencyBody.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                isCustom ? 'custom' : '${expense.splits.length}-way',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isCustom ? AppColors.amber700 : AppColors.jade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
