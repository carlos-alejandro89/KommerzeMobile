import 'package:flutter/widgets.dart';

abstract final class AppBreakpoints {
  static const double tablet = 720;
  static const double desktop = 1100;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isTabletLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide >= 600 && size.width > size.height;
  }

  static double pagePadding(BuildContext context) => isWide(context) ? 24 : 16;
}

class AdaptiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    ),
  );
}
