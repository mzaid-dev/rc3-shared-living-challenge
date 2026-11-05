import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/member.dart';

class MemberSelectorBar extends StatelessWidget {
  final List<Member> members;
  final String activeMemberId;
  final BalancesResponse balances;
  final ValueChanged<String> onMemberSelected;

  const MemberSelectorBar({
    super.key,
    required this.members,
    required this.activeMemberId,
    required this.balances,
    required this.onMemberSelected,
  });

  Color _getMemberColor(String memberId) {
    if (memberId == 'M01') return AppColors.avatarAli;
    if (memberId == 'M02') return AppColors.avatarAyesha;
    if (memberId == 'M03') return AppColors.avatarBilal;
    return AppColors.jade600;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'ROOMMATES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.faint,
              ),
            ),
            Text(
              'Tap to switch view',
              style: TextStyle(fontSize: 10.5, color: AppColors.faint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: members.map((member) {
            final isSelected = member.id == activeMemberId;
            final memberBalance = balances.balances.firstWhere(
              (b) => b.memberId == member.id,
              orElse: () => balances.balances.first,
            );
            final netPaisa = memberBalance.netBalancePaisa;
            final isPositive = netPaisa > 0;
            final sign = isPositive ? '+' : '';
            final memberBaseColor = _getMemberColor(member.id);

            return Expanded(
              child: GestureDetector(
                onTap: () => onMemberSelected(member.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surface : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.jade600 : AppColors.line,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.jade600.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: memberBaseColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                member.name.length > 2 && member.name.startsWith('Ay') ? 'Ay' : member.name[0],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              member.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppColors.ink : AppColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$sign${Money.fromPaisa(netPaisa).format()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: netPaisa == 0
                              ? AppColors.faint
                              : (isPositive ? AppColors.jade600 : AppColors.coral600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
