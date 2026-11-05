import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';
import 'package:shared_living_app/features/assistant/data/models/assistant_dtos.dart';

class ActionSuccessCard extends StatelessWidget {
  final ActionSuccessData data;

  const ActionSuccessCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.jade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.jade200, width: 1.2),
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
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.jade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recorded to Ledger',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.jade800,
                ),
              ),
              const Spacer(),
              if (data.transactionId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.jade200),
                  ),
                  child: Text(
                    '#${data.transactionId}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.jade700,
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
        ],
      ),
    );
  }
}
