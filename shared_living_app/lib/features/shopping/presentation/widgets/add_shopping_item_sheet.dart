import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/idempotency_manager.dart';
import '../../../shared_living/data/models/shopping_item.dart';

class AddShoppingItemSheet extends StatefulWidget {
  final Future<bool> Function(CreateShoppingItemDto dto, String idempotencyKey) onSubmit;

  const AddShoppingItemSheet({super.key, required this.onSubmit});

  @override
  State<AddShoppingItemSheet> createState() => _AddShoppingItemSheetState();
}

class _AddShoppingItemSheetState extends State<AddShoppingItemSheet> {
  final _titleController = TextEditingController();
  String _selectedUnit = AppConstants.validUnits.first;
  int _qty = 1;
  bool _isSubmitting = false;
  String? _errorMessage;

  late final IdempotencyContext _idempotencyContext;

  @override
  void initState() {
    super.initState();
    _idempotencyContext = IdempotencyContext();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Item title is required');
      return;
    }

    final dto = CreateShoppingItemDto(
      title: title,
      unit: _selectedUnit,
      requestedQty: _qty,
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
                'Add shopping item',
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

          // Title field
          const Text(
            'ITEM NAME',
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
              hintText: 'e.g. Milk, Eggs, Tea bags',
            ),
          ),
          const SizedBox(height: 16),

          // Unit & Quantity row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UNIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      items: AppConstants.validUnits.map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              if (val != null) setState(() => _selectedUnit = val);
                            },
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
                      'QUANTITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.faint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: (_isSubmitting || _qty <= 1) ? null : () => setState(() => _qty--),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.jade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.remove, size: 16, color: AppColors.jade700),
                            ),
                          ),
                          Text('$_qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          GestureDetector(
                            onTap: _isSubmitting ? null : () => setState(() => _qty++),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.jade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, size: 16, color: AppColors.jade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

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
                    'Add item',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
          ),
        ],
      ),
    );
  }
}
