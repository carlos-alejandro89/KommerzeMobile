import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';

class ProductSelectionSheet extends StatefulWidget {
  final InventoryItem product;
  final bool purchaseMode;

  const ProductSelectionSheet({
    super.key,
    required this.product,
    this.purchaseMode = false,
  });

  static Future<double?> show(
    BuildContext context,
    InventoryItem product, {
    bool purchaseMode = false,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ProductSelectionSheet(product: product, purchaseMode: purchaseMode),
    );
  }

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  late final TextEditingController _quantityController;
  late final FocusNode _quantityFocus;
  double _quantity = 1;
  bool _quantityFocused = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _quantityFocus = FocusNode()..addListener(_onQuantityFocusChanged);
  }

  void _onQuantityFocusChanged() {
    if (!_quantityFocus.hasFocus) _normalizeQuantity();
    if (mounted) setState(() => _quantityFocused = _quantityFocus.hasFocus);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _quantityFocus
      ..removeListener(_onQuantityFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _setQuantity(double value) {
    final bounded = widget.purchaseMode
        ? value.clamp(0, 999999999).toDouble()
        : value.clamp(0, widget.product.stock).toDouble();
    setState(() {
      _quantity = bounded;
      _quantityController.text = _number(bounded);
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
    });
  }

  void _onQuantityChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    setState(() => _quantity = parsed ?? 0);
  }

  void _normalizeQuantity() {
    if (_quantity <= 0) {
      _setQuantity(1);
    } else if (!widget.purchaseMode && _quantity > widget.product.stock) {
      _setQuantity(widget.product.stock);
    } else {
      _setQuantity(_quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final available = widget.purchaseMode || product.stock > 0;
    final validQuantity =
        _quantity > 0 && (widget.purchaseMode || _quantity <= product.stock);
    final unitPrice = widget.purchaseMode
        ? product.purchasePrice
        : product.salePrice;
    final grossAmount = _quantity * unitPrice;
    final discountAmount = widget.purchaseMode
        ? 0.0
        : grossAmount * product.discountPercentage / 100;
    final netAmount = grossAmount - discountAmount;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderGrey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.navy,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Agregar artículo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 300,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primaryBlue,
                          size: 92,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Text(
                        product.displayName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${product.code}  ·  ${product.packageLevel}',
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                      if (product.barcode.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          product.barcode,
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuantityButton(
                            icon: Icons.remove_rounded,
                            enabled: _quantity > 1,
                            onPressed: () => _setQuantity(_quantity - 1),
                          ),
                          const SizedBox(width: 34),
                          SizedBox(
                            width: 82,
                            height: 70,
                            child: TextField(
                              controller: _quantityController,
                              focusNode: _quantityFocus,
                              onChanged: _onQuantityChanged,
                              onEditingComplete: () {
                                _normalizeQuantity();
                                FocusScope.of(context).unfocus();
                              },
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 42,
                                height: 1,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                filled: _quantityFocused,
                                fillColor: Colors.white,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.brightBlue,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 34),
                          _QuantityButton(
                            icon: Icons.add_rounded,
                            enabled:
                                widget.purchaseMode ||
                                _quantity < product.stock,
                            onPressed: () => _setQuantity(_quantity + 1),
                          ),
                        ],
                      ),
                      if (!widget.purchaseMode && discountAmount > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Descuento aplicado: ',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '-\$${discountAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _SaleMetric(
                              label: 'Existencia',
                              value: _number(product.stock),
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SaleMetric(
                              label: widget.purchaseMode
                                  ? 'Exist. final'
                                  : 'Descuento',
                              value: widget.purchaseMode
                                  ? _number(product.stock + _quantity)
                                  : '${product.discountPercentage.toStringAsFixed(0)}%',
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SaleMetric(
                              label: widget.purchaseMode
                                  ? 'Precio compra'
                                  : 'Precio',
                              value: '\$${unitPrice.toStringAsFixed(2)}',
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      if (!validQuantity) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            widget.purchaseMode
                                ? 'Ingresa una cantidad mayor a cero.'
                                : available
                                ? 'Ingresa una cantidad entre 1 y ${_number(product.stock)}.'
                                : 'Artículo sin existencia.',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: validQuantity
                              ? () => Navigator.pop(context, _quantity)
                              : null,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(
                            'Agregar  ·  \$${netAmount.toStringAsFixed(2)}',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4E7BFA),
                            disabledBackgroundColor: AppColors.borderGrey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primarySurface,
    shape: CircleBorder(
      side: BorderSide(
        color: enabled ? AppColors.borderGrey : const Color(0xFFE9EEF5),
      ),
    ),
    child: InkWell(
      onTap: enabled ? onPressed : null,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Icon(
          icon,
          color: enabled ? AppColors.primaryBlue : AppColors.borderGrey,
          size: 28,
        ),
      ),
    ),
  );
}

class _SaleMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SaleMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
