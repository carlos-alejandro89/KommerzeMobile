import 'package:flutter/material.dart';
import 'package:kommerze_mobile/core/constants/app_colors.dart';

class AppPopupMenuLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const AppPopupMenuLabel({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Text(
        text,
        style: TextStyle(
          color: color == AppColors.error ? AppColors.error : AppColors.navy,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

RoundedRectangleBorder appPopupMenuShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(14),
  side: BorderSide(color: AppColors.borderGrey.withValues(alpha: .8)),
);
