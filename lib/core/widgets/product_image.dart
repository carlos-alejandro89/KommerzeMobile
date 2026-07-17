import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/api_constants.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';

class ProductImage extends StatelessWidget {
  final String imagePath;
  final BoxFit fit;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.contain,
    this.iconSize = 32,
  });

  String? get _url {
    final path = imagePath.trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${ApiConstants.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return ColoredBox(
      color: Colors.white,
      child: url == null
          ? _fallback()
          : Image.network(
              url,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (_, _, _) => _fallback(),
            ),
    );
  }

  Widget _fallback() => Center(
    child: Icon(
      Icons.inventory_2_outlined,
      color: AppColors.primaryBlue,
      size: iconSize,
    ),
  );
}
