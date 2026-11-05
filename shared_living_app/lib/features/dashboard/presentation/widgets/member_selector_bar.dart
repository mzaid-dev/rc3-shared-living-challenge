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
  final String? authenticatedMemberId;

  const MemberSelectorBar({
    super.key,
    required this.members,
    required this.activeMemberId,
    required this.balances,
    required this.onMemberSelected,
    this.authenticatedMemberId,
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
              'ROOMMATE PERSPECTIVES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.faint,
              ),
            ),
            Text(
              'Tap to switch view',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.faint),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: members.map((member) {
              final isSelected = member.id == activeMemberId;
              final isAuthUser = authenticatedMemberId != null && member.id == authenticatedMemberId;
              final memberBalance = balances.balances.firstWhere(
                (b) => b.memberId == member.id,
                orElse: () => balances.balances.first,
              );
              final netPaisa = memberBalance.netBalancePaisa;
              final isPositive = netPaisa > 0;
              final sign = isPositive ? '+' : '';
              final memberBaseColor = _getMemberColor(member.id);

              return Container(
                width: 124,
                height: 78,
                margin: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onMemberSelected(member.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
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
                          : [
                              BoxShadow(
                                color: AppColors.jade900.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                                  member.name.length > 2 && member.name.startsWith('Ay')
                                      ? 'Ay'
                                      : member.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isAuthUser ? '${member.name} (You)' : member.name,
                                maxLines: 1,
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
                        Text(
                          '$sign${Money.fromPaisa(netPaisa).format()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
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
        ),
      ],
    );
  }
}
