import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../auth/domain/models/auth_user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class SettingsScreen extends StatelessWidget {
  final AuthUser user;

  const SettingsScreen({super.key, required this.user});

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
    final initials = _getMemberInitials(user.name);
    final avatarColor = _getMemberColor(user.id);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
        children: [
          // Screen Header
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Household preferences & profile',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.slate,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // 1. User Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.jade900.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.jade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.jade100),
                            ),
                            child: Text(
                              user.id,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.jade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Household Info Card
          const Text(
            'HOUSEHOLD APARTMENT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.faint,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: const [
                _SettingRow(
                  icon: Icons.apartment_rounded,
                  title: 'Apartment Location',
                  value: 'Gulberg 4B, Lahore',
                ),
                Divider(color: AppColors.lineSoft, height: 18),
                _SettingRow(
                  icon: Icons.group_rounded,
                  title: 'Housemates',
                  value: 'Ali, Ayesha, Bilal (3)',
                ),
                Divider(color: AppColors.lineSoft, height: 18),
                _SettingRow(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'November Budget Limit',
                  value: 'PKR 5,000.00',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Sign Out Button
          OutlinedButton.icon(
            onPressed: () => context.read<AuthCubit>().logout(),
            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.coral600),
            label: const Text(
              'Sign Out of Hisab',
              style: TextStyle(color: AppColors.coral600, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.coral100, width: 1.5),
              backgroundColor: AppColors.coral50,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.slate),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ],
    );
  }
}
