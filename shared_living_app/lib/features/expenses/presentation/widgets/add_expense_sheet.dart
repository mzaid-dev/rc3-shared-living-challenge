import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/idempotency_manager.dart';
import '../../../../core/utils/split_preview_calculator.dart';
import '../../../shared_living/data/models/expense.dart';
import '../../../shared_living/data/models/member.dart';

class AddExpenseSheet extends StatefulWidget {
  final List<Member> members;
  final String initialPayerId;
  final Future<bool> Function(CreateExpenseDto dto, String idempotencyKey) onSubmit;

  const AddExpenseSheet({
    super.key,
    required this.members,
    required this.initialPayerId,
    required this.onSubmit,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Utilities';
  late String _payerId;
  String _splitType = 'equal'; // 'equal' | 'custom'
  bool _isRecurring = false;

  final Map<String, TextEditingController> _customControllers = {};
  bool _isSubmitting = false;
  String? _errorMessage;

  late final IdempotencyContext _idempotencyContext;

  @override
  void initState() {
    super.initState();
    _idempotencyContext = IdempotencyContext();
    _payerId = widget.initialPayerId;
    for (final m in widget.members) {
      _customControllers[m.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, int> _getPreviewShares() {
    if (_splitType != 'equal') return {};
    try {
      final money = Money.parse(_amountController.text);
      return SplitPreviewCalculator.previewEqualSplit(
        totalPaisa: money.paisa,
        memberIds: widget.members.map((m) => m.id).toList(),
      );
    } catch (_) {
      return {};
    }
  }

  int _getCustomAllocatedPaisa() {
    int total = 0;
    for (final c in _customControllers.values) {
      try {
        final m = Money.parse(c.text);
        total += m.paisa;
      } catch (_) {}
    }
    return total;
  }

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

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title is required');
      return;
    }

    final rawAmount = _amountController.text.trim();
    Money money;
    try {
      money = Money.parse(rawAmount);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      return;
    }

    List<CustomSplitItemDto>? customSplits;
    if (_splitType == 'custom') {
      customSplits = [];
      int customSum = 0;
      for (final m in widget.members) {
        final raw = _customControllers[m.id]?.text.trim() ?? '';
        try {
          final shareMoney = Money.parse(raw);
          customSplits.add(CustomSplitItemDto(memberId: m.id, amount: shareMoney.toJsonString()));
          customSum += shareMoney.paisa;
        } catch (e) {
          setState(() => _errorMessage = 'Invalid allocation for ${m.name}');
          return;
        }
      }

      if (customSum != money.paisa) {
        setState(() => _errorMessage =
            'Sum of custom allocations (${Money.fromPaisa(customSum).format()}) does not match total (${money.format()}).');
        return;
      }
    }

    final dto = CreateExpenseDto(
      title: title,
      category: _category,
      amount: money.toJsonString(),
      payerId: _payerId,
      splitType: _splitType,
      customSplits: customSplits,
      date: DateTime.now().toIso8601String().substring(0, 10),
    );

    final payloadStr = jsonEncode(dto.toJson());
    final key = _idempotencyContext.prepareKeyForPayload(payloadStr);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onSubmit(dto, key);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          _idempotencyContext.handleFailure(
            isNetworkOrTimeoutOr5xx: false,
            payload: payloadStr,
          );
          setState(() => _isSubmitting = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _idempotencyContext.handleFailure(
          isNetworkOrTimeoutOr5xx: true,
          payload: payloadStr,
        );
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewShares = _getPreviewShares();
    final customAllocatedPaisa = _getCustomAllocatedPaisa();
    int? totalPaisa;
    try {
      totalPaisa = Money.parse(_amountController.text).paisa;
    } catch (_) {}

    final categories = ['Utilities', 'Groceries', 'Cleaning', 'Dining'];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusSheetTop,
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber Handle
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log shared expense',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.ink,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded, color: AppColors.slate, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.coral50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.coral100),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.coral700, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Title & Amount row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TITLE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        enabled: !_isSubmitting,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                        decoration: const InputDecoration(
                          hintText: 'e.g. Internet bill',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AMOUNT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                        decoration: const InputDecoration(
                          prefixText: 'PKR ',
                          hintText: '1,500',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category Chips
            const Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.faint,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _category == cat;
                  return GestureDetector(
                    onTap: _isSubmitting ? null : () => setState(() => _category = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.jade600 : AppColors.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: isSelected ? AppColors.jade600 : AppColors.line,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.slate,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Paid By & Split Type row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PAID BY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _payerId,
                        items: widget.members.map((m) {
                          return DropdownMenuItem(value: m.id, child: Text(m.name));
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) setState(() => _payerId = val);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SPLIT TYPE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _splitType,
                        items: const [
                          DropdownMenuItem(value: 'equal', child: Text('Equal split')),
                          DropdownMenuItem(value: 'custom', child: Text('By amounts')),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) setState(() => _splitType = val);
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Equal preview or custom allocation card
            if (_splitType == 'equal') ...[
              if (previewShares.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.jade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.jade200),
                  ),
                  child: Column(
                    children: previewShares.entries.map((entry) {
                      final mName = widget.members.firstWhere((m) => m.id == entry.key).name;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$mName share (preview):', style: const TextStyle(fontSize: 12, color: AppColors.jade700, fontWeight: FontWeight.w600)),
                            Text(
                              Money.fromPaisa(entry.value).format(),
                              style: AppTypography.currencyBody.copyWith(fontSize: 12.5, color: AppColors.jade900),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ] else ...[
              // Custom allocation card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.jade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.jade200, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CUSTOM SHARES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.jade700,
                          ),
                        ),
                        if (totalPaisa != null)
                          Text(
                            '${Money.fromPaisa(customAllocatedPaisa).format()} / ${Money.fromPaisa(totalPaisa).format()}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: customAllocatedPaisa == totalPaisa ? AppColors.jade700 : AppColors.coral600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...widget.members.map((m) {
                      final initials = _getMemberInitials(m.name);
                      final color = _getMemberColor(m.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _customControllers[m.id],
                                enabled: !_isSubmitting,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  prefixText: 'PKR ',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Recurring bill checkbox
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _isRecurring,
                    onChanged: (val) => setState(() => _isRecurring = val ?? false),
                    activeColor: AppColors.jade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mark as monthly recurring bill',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.jade600,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Text(
                      'Save expense',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
