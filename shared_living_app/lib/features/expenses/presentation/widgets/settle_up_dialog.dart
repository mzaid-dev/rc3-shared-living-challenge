import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/models/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/idempotency_manager.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/member.dart';

class SettleUpDialog extends StatefulWidget {
  final List<Member> members;
  final BalancesResponse balances;
  final Future<bool> Function(SettlementRequestDto dto, String idempotencyKey) onConfirmSettlement;
  final String? prefillSenderId;
  final String? prefillRecipientId;
  final String? prefillAmount;

  const SettleUpDialog({
    super.key,
    required this.members,
    required this.balances,
    required this.onConfirmSettlement,
    this.prefillSenderId,
    this.prefillRecipientId,
    this.prefillAmount,
  });

  @override
  State<SettleUpDialog> createState() => _SettleUpDialogState();
}

class _SettleUpDialogState extends State<SettleUpDialog> {
  late String _senderId;
  late String _recipientId;
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  late final IdempotencyContext _idempotencyContext;

  @override
  void initState() {
    super.initState();
    _idempotencyContext = IdempotencyContext();

    if (widget.prefillSenderId != null && widget.prefillRecipientId != null) {
      _senderId = widget.prefillSenderId!;
      _recipientId = widget.prefillRecipientId!;
      if (widget.prefillAmount != null) {
        _amountController.text = widget.prefillAmount!;
      }
    } else {
      // Default sender to debtor (Ayesha M02)
      final debtor = widget.balances.balances.firstWhere(
        (b) => b.netBalancePaisa < 0,
        orElse: () => widget.balances.balances.first,
      );
      // Default recipient to creditor (Ali M01)
      final creditor = widget.balances.balances.firstWhere(
        (b) => b.netBalancePaisa > 0 && b.memberId != debtor.memberId,
        orElse: () => widget.balances.balances.last,
      );

      _senderId = debtor.memberId;
      _recipientId = creditor.memberId;

      final defaultPaisa = debtor.netBalancePaisa.abs() < creditor.netBalancePaisa
          ? debtor.netBalancePaisa.abs()
          : creditor.netBalancePaisa;
      if (defaultPaisa > 0) {
        _amountController.text = Money.fromPaisa(defaultPaisa).toJsonString();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final rawAmount = _amountController.text.trim();

    // Strict validation order:
    // 1. amount > 0
    Money money;
    try {
      money = Money.parse(rawAmount);
      if (money.paisa <= 0) {
        setState(() => _errorMessage = 'Settlement amount must be positive.');
        return;
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      return;
    }

    // 2. sender != recipient
    if (_senderId == _recipientId) {
      setState(() => _errorMessage = 'Sender and recipient cannot be the same member.');
      return;
    }

    // 3. sender debt (SETTLE_EXCEEDS_DEBT)
    final senderBal = widget.balances.balances.firstWhere((b) => b.memberId == _senderId);
    final senderDebtPaisa = senderBal.netBalancePaisa < 0 ? senderBal.netBalancePaisa.abs() : 0;
    if (money.paisa > senderDebtPaisa) {
      setState(() => _errorMessage =
          'Amount of ${money.format()} exceeds sender debt of ${Money.fromPaisa(senderDebtPaisa).format()}.');
      return;
    }

    // 4. recipient credit (SETTLE_EXCEEDS_CREDIT)
    final recipientBal = widget.balances.balances.firstWhere((b) => b.memberId == _recipientId);
    final recipientCreditPaisa = recipientBal.netBalancePaisa > 0 ? recipientBal.netBalancePaisa : 0;
    if (money.paisa > recipientCreditPaisa) {
      setState(() => _errorMessage =
          'Amount of ${money.format()} exceeds recipient receivable credit of ${Money.fromPaisa(recipientCreditPaisa).format()}.');
      return;
    }

    final dto = SettlementRequestDto(
      senderId: _senderId,
      recipientId: _recipientId,
      amount: money.toJsonString(),
    );

    final payloadStr = jsonEncode(dto.toJson());
    final key = _idempotencyContext.prepareKeyForPayload(payloadStr);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onConfirmSettlement(dto, key);
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
    final senderBal = widget.balances.balances.firstWhere(
      (b) => b.memberId == _senderId,
      orElse: () => widget.balances.balances.first,
    );
    final maxDebtPaisa = senderBal.netBalancePaisa < 0 ? senderBal.netBalancePaisa.abs() : 0;

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
                  'Record a payment',
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
            const Text(
              'Direct cash or bank settlement between housemates',
              style: TextStyle(fontSize: 12.5, color: AppColors.slate),
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

            // Sender & Recipient Row with Arrow
            Row(
              children: [
                // Sender (Debtor)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SENDER (OWES)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _senderId,
                        isExpanded: true,
                        items: widget.members.map((m) {
                          return DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: _isSubmitting ? null : (val) => setState(() => _senderId = val!),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 22.0, left: 6, right: 6),
                  child: Icon(Icons.arrow_forward_rounded, color: AppColors.slate, size: 20),
                ),
                // Recipient (Creditor)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RECIPIENT (CREDIT)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _recipientId,
                        isExpanded: true,
                        items: widget.members.map((m) {
                          return DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: _isSubmitting ? null : (val) => setState(() => _recipientId = val!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount field with max debt helper
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SETTLEMENT AMOUNT',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.faint,
                      ),
                    ),
                    if (maxDebtPaisa > 0)
                      Text(
                        'max ${Money.fromPaisa(maxDebtPaisa).format()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.jade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                  decoration: const InputDecoration(
                    prefixText: 'PKR ',
                    hintText: '250.00',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

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
                      'Settle up',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
