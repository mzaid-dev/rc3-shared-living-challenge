import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/idempotency_manager.dart';
import '../../../../core/utils/split_preview_calculator.dart';
import '../../../shared_living/data/models/checkout_request_dto.dart';
import '../../../shared_living/data/models/member.dart';
import '../../../shared_living/data/models/shopping_item.dart';

class ShoppingCheckoutSheet extends StatefulWidget {
  final List<ShoppingItem> selectedItems;
  final List<Member> members;
  final String initialPayerId;
  final Future<bool> Function(CheckoutRequestDto dto, String idempotencyKey) onConfirmCheckout;

  const ShoppingCheckoutSheet({
    super.key,
    required this.selectedItems,
    required this.members,
    required this.initialPayerId,
    required this.onConfirmCheckout,
  });

  @override
  State<ShoppingCheckoutSheet> createState() => _ShoppingCheckoutSheetState();
}

class _ShoppingCheckoutSheetState extends State<ShoppingCheckoutSheet> {
  final _amountController = TextEditingController(text: '780.00');
  final _taxPercentController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  late String _payerId;
  late Set<String> _splitMembers;
  bool _isSubmitting = false;
  String? _errorMessage;

  late final IdempotencyContext _idempotencyContext;

  @override
  void initState() {
    super.initState();
    _idempotencyContext = IdempotencyContext();
    _payerId = widget.initialPayerId;
    _splitMembers = widget.members.map((m) => m.id).toSet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _taxPercentController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _recalculateNetTotal() {
    final rawBase = double.tryParse(_amountController.text) ?? 0.0;
    final taxPct = double.tryParse(_taxPercentController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final net = (rawBase * (1.0 + (taxPct / 100.0))) - discount;
    if (net >= 0) {
      _amountController.text = net.toStringAsFixed(2);
    }
  }

  Map<String, int> _getPreviewShares() {
    try {
      final money = Money.parse(_amountController.text);
      return SplitPreviewCalculator.previewEqualSplit(
        totalPaisa: money.paisa,
        memberIds: _splitMembers.toList(),
      );
    } catch (_) {
      return {};
    }
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
    if (_isSubmitting) return; // In-flight lock

    final rawAmount = _amountController.text.trim();
    try {
      Money.parse(rawAmount);
    } catch (e) {
      final msg = e is AppFailure ? e.message : e.toString().replaceFirst(RegExp(r'^[^:]*:\s*'), '');
      setState(() => _errorMessage = msg.isNotEmpty ? msg : 'Please enter a valid amount.');
      return;
    }

    if (_splitMembers.isEmpty) {
      setState(() => _errorMessage = 'Select at least one member to split with.');
      return;
    }

    final dto = CheckoutRequestDto(
      itemIds: widget.selectedItems.map((i) => i.id).toList(),
      totalPaid: rawAmount,
      payerId: _payerId,
      splitMembers: _splitMembers.toList(),
    );

    final payloadStr = jsonEncode(dto.toJson());
    final key = _idempotencyContext.prepareKeyForPayload(payloadStr);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onConfirmCheckout(dto, key);
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
        final msg = e is AppFailure ? e.message : e.toString().replaceFirst(RegExp(r'^[^:]*:\s*'), '');
        setState(() {
          _isSubmitting = false;
          _errorMessage = msg.isNotEmpty ? msg : 'Checkout failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewShares = _getPreviewShares();
    final itemsSummary = widget.selectedItems.map((i) => '${i.title} (${i.requestedQty} ${i.unit})').join(', ');

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

            // Header Row: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Checkout',
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
            const SizedBox(height: 2),
            Text(
              '$itemsSummary · bill from the store',
              style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.coral50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.coral100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.coral600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.coral700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Tax & Discount (Surprise Task Feature)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TAX %',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: TextField(
                          controller: _taxPercentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) {
                            _recalculateNetTotal();
                            setState(() {});
                          },
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            suffixText: '%',
                            suffixStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
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
                        'DISCOUNT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: TextField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) {
                            _recalculateNetTotal();
                            setState(() {});
                          },
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            prefixText: 'PKR ',
                            prefixStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Total Paid Field (Highlighted Jade Container)
            const Text(
              'TOTAL PAID (NET)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.faint,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.jade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.jade200, width: 1.5),
              ),
              child: Row(
                children: [
                  const Text(
                    'PKR ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.jade700,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.jade900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Paid By Selector
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
            Row(
              children: widget.members.map((m) {
                final isSelected = m.id == _payerId;
                final initials = _getMemberInitials(m.name);
                final color = _getMemberColor(m.id);

                return Expanded(
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : () => setState(() => _payerId = m.id),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.jade600 : AppColors.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: isSelected ? AppColors.jade600 : AppColors.line,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : color,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? AppColors.jade700 : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Split Between Toggle Chips
            const Text(
              'SPLIT BETWEEN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.faint,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: widget.members.map((m) {
                final isIncluded = _splitMembers.contains(m.id);
                return Expanded(
                  child: GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              if (isIncluded) {
                                if (_splitMembers.length > 1) {
                                  _splitMembers.remove(m.id);
                                }
                              } else {
                                _splitMembers.add(m.id);
                              }
                            });
                          },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      height: 38,
                      decoration: BoxDecoration(
                        color: isIncluded ? AppColors.jade600 : AppColors.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: isIncluded ? AppColors.jade600 : AppColors.line,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isIncluded ? Colors.white : AppColors.slate,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Split Preview calculation box
            if (previewShares.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: previewShares.entries.map((entry) {
                    final memberName = widget.members
                        .firstWhere((m) => m.id == entry.key, orElse: () => Member(id: entry.key, name: entry.key))
                        .name;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$memberName share (preview):', style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
                          Text(
                            Money.fromPaisa(entry.value).format(),
                            style: AppTypography.currencyBody.copyWith(fontSize: 12.5, color: AppColors.ink),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 18),

            // Action Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.jade600,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Posting expense...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    )
                  : const Text(
                      'Post expense',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Button locks while the request is in flight · prevents double submits',
                style: TextStyle(fontSize: 11, color: AppColors.faint, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
