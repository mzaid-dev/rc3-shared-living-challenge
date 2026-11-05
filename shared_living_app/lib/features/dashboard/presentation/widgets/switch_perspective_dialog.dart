import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/member.dart';

/// Professional confirmation dialog shown prior to switching the active household viewpoint.
/// Verifies user intent and displays the target roommate's net balance summary.
class SwitchPerspectiveDialog extends StatelessWidget {
  final Member targetMember;
  final MemberBalance? targetBalance;
  final VoidCallback onConfirm;

  const SwitchPerspectiveDialog({
    super.key,
    required this.targetMember,
    this.targetBalance,
    required this.onConfirm,
  });

  Color _getMemberColor(String memberId) {
    if (memberId == 'M01') return AppColors.avatarAli;
    if (memberId == 'M02') return AppColors.avatarAyesha;
    if (memberId == 'M03') return AppColors.avatarBilal;
    return AppColors.jade600;
  }

  String _getMemberInitials(String name) {
    if (name.length > 2 && name.startsWith('Ay')) return 'Ay';
    return name.isNotEmpty ? name[0] : '?';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getMemberColor(targetMember.id);
    final initials = _getMemberInitials(targetMember.name);
    final netPaisa = targetBalance?.netBalancePaisa ?? 0;
    final isPositive = netPaisa > 0;
    final netColor = isPositive
        ? AppColors.jade700
        : (netPaisa < 0 ? AppColors.coral700 : AppColors.slate);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusSheetTop,
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Grabber handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Member Avatar Badge
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Title & Explanation
          Text(
            'Switch to ${targetMember.name}\'s perspective?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your dashboard, individual net balance, and debts will be calculated from ${targetMember.name}\'s viewpoint.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.slate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // 4. Member Financial Preview Card
          if (targetBalance != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT NET BALANCE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isPositive
                            ? '+${Money.fromPaisa(netPaisa).format()}'
                            : Money.fromPaisa(netPaisa).format(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: netColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? AppColors.jade50
                          : (netPaisa < 0 ? AppColors.coral50 : AppColors.lineSoft),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPositive
                          ? 'Is Owed'
                          : (netPaisa < 0 ? 'Owes Money' : 'Settled'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: netColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),

          // 5. Action Buttons: Cancel vs Confirm
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.slate,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm();
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Switch to ${targetMember.name}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.jade600,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
