import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../shared_living/data/models/shopping_item.dart';

class ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.isSelected,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isBought = item.status == 'bought';

    return GestureDetector(
      onTap: isBought ? null : () => onSelectedChanged?.call(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.jade50 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.jade400 : AppColors.line,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Custom Square Checkbox
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isBought
                    ? AppColors.jade100
                    : (isSelected ? AppColors.jade600 : Colors.transparent),
                borderRadius: BorderRadius.circular(7),
                border: isSelected || isBought
                    ? null
                    : Border.all(color: AppColors.line, width: 1.8),
              ),
              child: isBought
                  ? const Center(
                      child: Icon(Icons.check, size: 14, color: AppColors.jade700),
                    )
                  : (isSelected
                      ? const Center(
                          child: Icon(Icons.check, size: 14, color: Colors.white),
                        )
                      : null),
            ),
            const SizedBox(width: 12),

            // Item Title & Units
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isBought ? AppColors.faint : AppColors.ink,
                      decoration: isBought ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.faint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.requestedQty} × ${item.unit} · ${isBought ? "logged as expense" : "requested"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge (PENDING or BOUGHT)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isBought ? AppColors.jade50 : AppColors.amber50,
                borderRadius: AppRadius.radiusTag,
                border: Border.all(
                  color: isBought ? AppColors.jade100 : AppColors.amber100,
                ),
              ),
              child: Text(
                isBought ? 'BOUGHT' : 'PENDING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: isBought ? AppColors.jade700 : AppColors.amber700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
