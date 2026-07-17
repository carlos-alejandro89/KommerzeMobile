import 'package:flutter/material.dart';
import 'package:kommerze_mobile/features/sales/presentation/screens/sales_screen.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SalesScreen(purchaseMode: true);
}
