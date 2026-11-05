import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';
import 'package:shared_living_app/features/assistant/data/models/assistant_dtos.dart';

class ShoppingListCard extends StatelessWidget {
  final ShoppingListData data;

  const ShoppingListCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.jade900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.jade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shopping_basket_outlined,
                  size: 15,
                  color: AppColors.jade600,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Shopping List',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${data.pendingCount} pending',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...data.items.map((item) {
            final isPending = item.isPending;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isPending ? AppColors.surface : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lineSoft),
              ),
              child: Row(
                children: [
                  Icon(
                    isPending
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: isPending ? AppColors.amber600 : AppColors.jade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isPending ? AppColors.ink : AppColors.slate,
                        decoration: isPending ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  Text(
                    '${item.quantity} ${item.unit}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
