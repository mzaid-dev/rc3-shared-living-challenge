import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';
import 'package:shared_living_app/features/assistant/data/models/assistant_dtos.dart';

class ActionErrorCard extends StatelessWidget {
  final ActionErrorData data;
  final VoidCallback? onRetry;

  const ActionErrorCard({
    super.key,
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coral50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coral100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.coral700.withValues(alpha: 0.04),
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
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.coral600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Execution Failed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.coral700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.coral100),
                ),
                child: Text(
                  data.errorCode,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.coral600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          if (data.canRetry && onRetry != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.coral600,
                  side: const BorderSide(color: AppColors.coral100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
