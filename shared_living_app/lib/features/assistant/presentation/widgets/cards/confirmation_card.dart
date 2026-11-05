import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';
import 'package:shared_living_app/features/assistant/data/models/assistant_dtos.dart';

class ConfirmationCard extends StatelessWidget {
  final ConfirmationRequiredData data;
  final bool isConfirming;
  final bool isConfirmed;
  final bool isCancelled;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmationCard({
    super.key,
    required this.data,
    required this.isConfirming,
    this.isConfirmed = false,
    this.isCancelled = false,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final payload = data.payload;
    final title = payload['title']?.toString();
    final amount = payload['amount']?.toString();
    final category = payload['category']?.toString();
    final payer = payload['payer_name']?.toString() ?? payload['payer']?.toString() ?? payload['payer_id']?.toString();
    final splits = payload['splits'] as List<dynamic>?;
    final items = payload['items'] as List<dynamic>?;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed
              ? AppColors.jade400
              : (isCancelled ? AppColors.line : AppColors.amber500.withValues(alpha: 0.6)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed ? AppColors.jade600 : AppColors.amber500)
                .withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: isConfirmed
                      ? AppColors.jade50
                      : (isCancelled ? AppColors.canvas : AppColors.amber50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isConfirmed
                      ? Icons.check_circle_rounded
                      : (isCancelled ? Icons.cancel_outlined : Icons.lock_outline_rounded),
                  size: 16,
                  color: isConfirmed
                      ? AppColors.jade600
                      : (isCancelled ? AppColors.slate : AppColors.amber700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConfirmed
                    ? 'Action Confirmed'
                    : (isCancelled ? 'Action Cancelled' : 'Action Confirmation Required'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isConfirmed
                    ? AppColors.jade700
                    : (isCancelled ? AppColors.slate : AppColors.amber700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            data.summary,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lineSoft),
            ),
            child: Column(
              children: [
                if (title != null) _buildParamRow('Description', title),
                if (category != null) _buildParamRow('Category', category),
                if (amount != null)
                  _buildParamRow(
                    'Total Amount',
                    'PKR $amount',
                    isHighlight: true,
                  ),
                if (payer != null) _buildParamRow('Payer', payer),
                if (splits != null && splits.isNotEmpty)
                  _buildParamRow(
                    'Participants',
                    '${splits.length} household members',
                  ),
                if (items != null && items.isNotEmpty)
                  _buildParamRow(
                    'Items',
                    '${items.length} items',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.jade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.jade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: AppColors.jade600),
                  SizedBox(width: 6),
                  Text(
                    'Recorded to household ledger',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.jade700,
                    ),
                  ),
                ],
              ),
            )
          else if (isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Transaction cancelled',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isConfirming ? null : onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      backgroundColor: AppColors.jade600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isConfirming ? null : onConfirm,
                    child: isConfirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Confirm & Record',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.slate),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
              color: isHighlight ? AppColors.jade700 : AppColors.ink,
              fontFeatures: isHighlight ? const [FontFeature.tabularFigures()] : null,
            ),
          ),
        ],
      ),
    );
  }
}
