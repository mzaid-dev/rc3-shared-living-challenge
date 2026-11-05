import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';

class TypingIndicator extends StatefulWidget {
  final double dotSize;
  final Color dotColor;

  const TypingIndicator({
    super.key,
    this.dotSize = 6.0,
    this.dotColor = AppColors.jade600,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double start = index * 0.2;
        final double end = start + 0.5;
        final double progress = _controller.value;
        double bounce = 0.0;
        if (progress >= start && progress <= end) {
          final double t = (progress - start) / (end - start);
          bounce = -4.0 * (1.0 - (2.0 * t - 1.0).abs());
        }

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: widget.dotColor.withOpacity(
                0.4 + (bounce != 0 ? 0.6 : 0.0),
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.jade900.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0),
          _buildDot(1),
          _buildDot(2),
          const SizedBox(width: 8),
          const Text(
            'Assistant is thinking...',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}
