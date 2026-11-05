import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/domain/models/auth_user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class HomeHeaderMenu extends StatelessWidget {
  final AuthUser user;

  const HomeHeaderMenu({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.surface,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.radiusCard,
        side: BorderSide(color: AppColors.line),
      ),
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.slate,
        size: 20,
      ),
      onSelected: (value) {
        if (value == 'logout') {
          context.read<AuthCubit>().logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: AppTypography.titleSmall),
              const SizedBox(height: 2),
              Text(user.email, style: AppTypography.caption),
              const SizedBox(height: 6),
              const Divider(color: AppColors.line, height: 1),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: const [
              Icon(Icons.logout_rounded, color: AppColors.coral600, size: 18),
              SizedBox(width: 10),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: AppColors.coral600,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
