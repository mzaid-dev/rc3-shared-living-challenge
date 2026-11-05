import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';
import 'package:shared_living_app/features/assistant/data/models/assistant_dtos.dart';

class ExpenseSummaryCard extends StatelessWidget {
  final ExpenseSummaryData data;

  const ExpenseSummaryCard({super.key, required this.data});

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.amber100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded, size: 14, color: AppColors.amber700),
                    const SizedBox(width: 4),
                    Text(
                      data.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (data.date != null)
                Text(
                  data.date!,
                  style: const TextStyle(fontSize: 11, color: AppColors.faint),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                'PKR ${data.amount}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.jade700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Text(
                'Paid by: ',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
              Flexible(
                child: Text(
                  data.payerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.jade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.splitType == 'equal' ? 'Split Equally' : 'Custom Split',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.jade600,
                  ),
                ),
              ),
            ],
          ),

          if (data.participants.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.lineSoft, height: 1),
            const SizedBox(height: 8),
            Text(
              'Participant Shares (${data.participants.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 6),
            ...data.participants.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 12, color: AppColors.ink),
                    ),
                    Text(
                      'PKR ${p.share}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
