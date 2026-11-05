import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class HisabBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterActionTap;

  const HisabBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCenterActionTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic calculation for iOS Home Indicator safe area
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // 56px content area + bottom safe area inset
    final totalBarHeight = 56.0 + bottomInset;

    return Container(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1. Navigation Bar Base Dock
          Container(
            height: totalBarHeight,
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset - 4 : 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: const Border(
                top: BorderSide(color: AppColors.line, width: 1.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.jade900.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Tab 0: Home
                Expanded(
                  child: _NavItem(
                    icon: currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                ),

                // Tab 1: Shopping
                Expanded(
                  child: _NavItem(
                    icon: currentIndex == 1 ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                    label: 'Shopping',
                    isSelected: currentIndex == 1,
                    onTap: () => onTabSelected(1),
                  ),
                ),

                // Center Spacer for the elevated '+' button
                const SizedBox(width: 56),

                // Tab 2: Balances
                Expanded(
                  child: _NavItem(
                    icon: currentIndex == 2 ? Icons.monetization_on_rounded : Icons.monetization_on_outlined,
                    label: 'Balances',
                    isSelected: currentIndex == 2,
                    onTap: () => onTabSelected(2),
                  ),
                ),

                // Tab 3: Settings
                Expanded(
                  child: _NavItem(
                    icon: currentIndex == 3 ? Icons.settings_rounded : Icons.settings_outlined,
                    label: 'Settings',
                    isSelected: currentIndex == 3,
                    onTap: () => onTabSelected(3),
                  ),
                ),
              ],
            ),
          ),

          // 2. Elevated Floating Center '+' Button
          Positioned(
            top: -18,
            child: GestureDetector(
              onTap: onCenterActionTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.jade500,
                      AppColors.jade600,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.jade600.withValues(alpha: 0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.jade600 : AppColors.faint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.jade600 : AppColors.slate,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
