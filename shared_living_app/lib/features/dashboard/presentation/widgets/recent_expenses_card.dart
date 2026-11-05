import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../shared_living/data/models/expense.dart';
import '../../../shared_living/data/models/member.dart';

class RecentExpensesCard extends StatelessWidget {
  final List<Expense> expenses;
  final List<Member> members;
  final VoidCallback onViewAllTapped;

  const RecentExpensesCard({
    super.key,
    required this.expenses,
    required this.members,
    required this.onViewAllTapped,
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

  String _formatAmount(String raw) {
    try {
      return Money.parse(raw).format().replaceFirst('PKR ', '');
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title: "This month" + "See all"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'This month',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              GestureDetector(
                onTap: onViewAllTapped,
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.jade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (expenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(color: AppColors.line),
            ),
            child: const Center(
              child: Text(
                'No expenses logged for this month yet.',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.jade900.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length,
              separatorBuilder: (_, _) => const Divider(
                color: AppColors.lineSoft,
                height: 1,
                indent: 14,
                endIndent: 14,
              ),
              itemBuilder: (context, index) {
                final exp = expenses[index];
                final payerName = _getPayerName(exp.payerId);
                final (catBg, catFg, catIcon) = _getCategoryAppearance(exp.category);
                final isCustom = exp.splitType == 'custom';

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      // Category Icon Squircle
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: catBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(catIcon, color: catFg, size: 19),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    exp.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
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
                              '${exp.category} · paid by $payerName',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tabular Amount formatted with thousands commas
                      Text(
                        _formatAmount(exp.amount),
                        style: AppTypography.currencyBody.copyWith(
                          fontSize: 13.5,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
