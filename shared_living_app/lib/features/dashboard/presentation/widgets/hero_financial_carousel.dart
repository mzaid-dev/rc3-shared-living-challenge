import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/budget_and_dashboard.dart';
import 'budget_progress_card.dart';
import 'net_balance_hero_card.dart';

/// Clean, gesture-driven swipeable carousel for the Hisab home dashboard.
/// Features generous spacing between cards, smooth iOS bouncing physics,
/// unclipped soft elevation, and dedicated breathing room.
class HeroFinancialCarousel extends StatefulWidget {
  final DashboardMemberSummary memberSummary;
  final MemberBalance balanceDetail;
  final DashboardResponse dashboardData;
  final VoidCallback onQuickSettleTapped;

  const HeroFinancialCarousel({
    super.key,
    required this.memberSummary,
    required this.balanceDetail,
    required this.dashboardData,
    required this.onQuickSettleTapped,
  });

  @override
  State<HeroFinancialCarousel> createState() => _HeroFinancialCarouselState();
}

class _HeroFinancialCarouselState extends State<HeroFinancialCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDotTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Full-Sized, Unclipped Swipeable Card Viewport
        SizedBox(
          height: 172,
          child: PageView(
            clipBehavior: Clip.none,
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              // Slide 0: Deep Jade Net Balance Hero Card (with horizontal gutter spacing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: NetBalanceHeroCard(
                  memberSummary: widget.memberSummary,
                  balanceDetail: widget.balanceDetail,
                  onQuickSettleTapped: widget.onQuickSettleTapped,
                ),
              ),

              // Slide 1: Monthly Budget Progress Card (with horizontal gutter spacing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: BudgetProgressCard(dashboardData: widget.dashboardData),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Subtle, Minimalist Page Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _onDotTapped(0),
              behavior: HitTestBehavior.opaque,
              child: _IndicatorDot(isActive: _currentPage == 0),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _onDotTapped(1),
              behavior: HitTestBehavior.opaque,
              child: _IndicatorDot(isActive: _currentPage == 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _IndicatorDot extends StatelessWidget {
  final bool isActive;

  const _IndicatorDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isActive ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? AppColors.jade600 : AppColors.line,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
