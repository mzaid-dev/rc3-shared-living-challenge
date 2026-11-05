import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../shared_living/data/models/balances_response.dart';

class MemberBalancesCard extends StatelessWidget {
  final BalancesResponse balances;
  final VoidCallback onSettleUpTapped;
  final void Function(String senderId, String recipientId, String amount)? onQuickSettleSelected;

  const MemberBalancesCard({
    super.key,
    required this.balances,
    required this.onSettleUpTapped,
    this.onQuickSettleSelected,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Balances Table Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.radiusCard,
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.jade900.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Header Row
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line, width: 1.5)),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'MEMBER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'PAID',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'OWED',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'NET',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.faint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Body Rows
              ...balances.balances.map((member) {
                final net = member.netBalancePaisa;
                final isPositive = net > 0;
                final isSettled = net == 0;
                final netColor = isSettled
                    ? AppColors.faint
                    : (isPositive ? AppColors.jade600 : AppColors.coral600);

                final initials = _getMemberInitials(member.name);
                final avatarColor = _getMemberColor(member.memberId);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
                  ),
                  child: Row(
                    children: [
                      // Member Avatar & Name
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: avatarColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Paid
                      Expanded(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            member.totalPaid,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),

                      // Owed
                      Expanded(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            member.shareOwed,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),

                      // Net
                      Expanded(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            isPositive
                                ? '+${Money.fromPaisa(net).format()}'
                                : Money.fromPaisa(net).format(),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: netColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Zero-Sum Verification Footer
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.jade600),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Household total checks out: ${balances.sum}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.jade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Smart Settle Suggestion Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.jade700,
                AppColors.jade600,
              ],
            ),
            borderRadius: AppRadius.radiusCard,
            boxShadow: [
              BoxShadow(
                color: AppColors.jade700.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lightbulb_outline_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Smart Settle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '2 payments',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                'Minimum transfers to clear all household debts',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Color(0xCCFFFFFF), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),

              // Smart Settlement Suggestions Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    // Transfer 1: Ayesha pays Ali 250.00
                    GestureDetector(
                      onTap: () => onQuickSettleSelected?.call('M02', 'M01', '250.00'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(color: AppColors.avatarAyesha, shape: BoxShape.circle),
                              child: const Center(child: Text('Ay', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(color: AppColors.avatarAli, shape: BoxShape.circle),
                              child: const Center(child: Text('A', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Ayesha pays Ali',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                            const Text(
                              'PKR 250.00',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // Transfer 2: Ayesha pays Bilal 200.00
                    GestureDetector(
                      onTap: () => onQuickSettleSelected?.call('M02', 'M03', '200.00'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(color: AppColors.avatarAyesha, shape: BoxShape.circle),
                              child: const Center(child: Text('Ay', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(color: AppColors.avatarBilal, shape: BoxShape.circle),
                              child: const Center(child: Text('B', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white))),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Ayesha pays Bilal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                            const Text(
                              'PKR 200.00',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Settle Up CTA Button
        ElevatedButton.icon(
          onPressed: onSettleUpTapped,
          icon: const Icon(Icons.handshake_outlined, size: 18),
          label: const Text('Record a payment (Settle up)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.jade600,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}
