import 'package:flutter/material.dart';
import 'package:shared_living_app/core/theme/app_colors.dart';

class SuggestedPromptsBar extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onSelectPrompt;

  const SuggestedPromptsBar({
    super.key,
    required this.prompts,
    required this.onSelectPrompt,
  });

  IconData _getPromptIcon(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('spend') || lower.contains('budget')) {
      return Icons.pie_chart_outline_rounded;
    }
    if (lower.contains('balance') || lower.contains('owe')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (lower.contains('shopping') || lower.contains('list')) {
      return Icons.shopping_bag_outlined;
    }
    if (lower.contains('expense') || lower.contains('add')) {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('settle')) {
      return Icons.sync_alt_rounded;
    }
    return Icons.auto_awesome_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.lightbulb_outline_rounded, size: 13, color: AppColors.amber600),
                SizedBox(width: 5),
                Text(
                  'Suggested queries',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: prompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                final icon = _getPromptIcon(prompt);

                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  backgroundColor: AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  side: const BorderSide(color: AppColors.line, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  avatar: Icon(icon, size: 14, color: AppColors.jade600),
                  label: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  onPressed: () => onSelectPrompt(prompt),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
