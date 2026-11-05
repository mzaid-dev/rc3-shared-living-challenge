import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';

class HisabAssistantAvatar extends StatelessWidget {
  final double size;
  final bool showStatus;
  final bool isOnline;
  final ImageProvider? customImage;

  const HisabAssistantAvatar({
    super.key,
    this.size = 36,
    this.showStatus = false,
    this.isOnline = true,
    this.customImage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.jade700, AppColors.jade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.jade900.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: customImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.32),
                  child: Image(image: customImage!, fit: BoxFit.cover),
                )
              : Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: size * 0.52,
                  ),
                ),
        ),
        if (showStatus)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF10B981) : AppColors.faint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
