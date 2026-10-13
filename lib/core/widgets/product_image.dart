import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';
import 'package:kommerze_mobile/core/network/dio_provider.dart';
import 'package:kommerze_mobile/core/network/url_builder.dart';
import 'package:kommerze_mobile/core/setup/app_setup_controller.dart';

final _productImageProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, url) async {
      final response = await ref
          .read(dioProvider)
          .get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('El servidor devolvió una imagen vacía.');
      }
      return Uint8List.fromList(bytes);
    });

class ProductImage extends ConsumerWidget {
  final String imagePath;
  final BoxFit fit;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.contain,
    this.iconSize = 32,
  });

  String? _url(String baseUrl) {
    final path = imagePath.trim();
    if (path.isEmpty) return null;
    final url = UrlBuilder.join(baseUrl, path);
    return url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = _url(ref.watch(appSetupControllerProvider).baseUrl);
    final image = url == null ? null : ref.watch(_productImageProvider(url));
    return ColoredBox(
      color: Colors.white,
      child: url == null
          ? _fallback()
          : image!.when(
              data: (bytes) => Image.memory(
                bytes,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallback(),
              ),
              loading: () => const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => _fallback(),
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
