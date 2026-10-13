import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kommerze_mobile/core/device/device_type_controller.dart';
import 'package:kommerze_mobile/features/sales/presentation/screens/pda_sales_screen.dart';
import 'package:kommerze_mobile/features/sales/presentation/screens/sales_screen.dart';

class SalesEntryScreen extends ConsumerWidget {
  const SalesEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceType = ref.watch(deviceTypeControllerProvider);
    return deviceType == DeviceType.pda
        ? const PdaSalesScreen()
        : const SalesScreen();
  }
}
