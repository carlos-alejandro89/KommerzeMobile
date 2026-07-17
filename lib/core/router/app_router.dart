import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kommerze_mobile/core/constants/app_constants.dart';
import 'package:kommerze_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kommerze_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:kommerze_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:kommerze_mobile/features/license/presentation/screens/license_screen.dart';
import 'package:kommerze_mobile/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:kommerze_mobile/features/branch_operation/presentation/screens/branch_operation_screen.dart';
import 'package:kommerze_mobile/features/clients/presentation/screens/clients_screen.dart';
import 'package:kommerze_mobile/features/clients/presentation/screens/client_form_screen.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:kommerze_mobile/features/sales/presentation/screens/sales_screen.dart';
import 'package:kommerze_mobile/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:kommerze_mobile/features/checkout/presentation/screens/client_selection_screen.dart';
import 'package:kommerze_mobile/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:kommerze_mobile/features/sync/presentation/screens/catalog_sync_screen.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/screens/sales_history_screen.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/screens/sale_detail_screen.dart';
import 'package:kommerze_mobile/features/welcome/presentation/screens/welcome_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier(ref.read(authControllerProvider));

  ref.listen(authControllerProvider, (_, next) => authState.value = next);
  ref.onDispose(authState.dispose);

  return GoRouter(
    initialLocation: AppConstants.splashScreenRoute,
    refreshListenable: authState,
    redirect: (context, state) {
      final authentication = ref.read(authControllerProvider);
      final path = state.uri.path;

      if (path == AppConstants.splashScreenRoute || authentication.isLoading) {
        return null;
      }

      final isAuthenticated = authentication.value != null;
      if (!isAuthenticated && path != AppConstants.loginScreenRoute) {
        return AppConstants.loginScreenRoute;
      }
      if (isAuthenticated && path == AppConstants.loginScreenRoute) {
        return AppConstants.welcomeScreenRoute;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.splashScreenRoute,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.loginScreenRoute,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.welcomeScreenRoute,
        builder: (_, _) => WelcomeScreen(
          userName: ref.read(authControllerProvider).value?.name ?? 'Carlos',
        ),
      ),
      GoRoute(
        path: AppConstants.profileScreenRoute,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppConstants.licenseScreenRoute,
        builder: (_, _) => const LicenseScreen(),
      ),
      GoRoute(
        path: AppConstants.inventoryScreenRoute,
        builder: (_, _) => const InventoryScreen(),
      ),
      GoRoute(
        path: AppConstants.branchOperationScreenRoute,
        builder: (_, _) => const BranchOperationScreen(),
      ),
      GoRoute(
        path: AppConstants.clientsScreenRoute,
        builder: (_, _) => const ClientsScreen(),
      ),
      GoRoute(
        path: AppConstants.clientFormScreenRoute,
        builder: (_, state) => ClientFormScreen(client: state.extra as Client?),
      ),
      GoRoute(
        path: AppConstants.salesScreenRoute,
        builder: (_, _) => const SalesScreen(),
      ),
      GoRoute(
        path: AppConstants.purchasesScreenRoute,
        builder: (_, _) => const PurchasesScreen(),
      ),
      GoRoute(
        path: AppConstants.checkoutScreenRoute,
        builder: (_, _) => const CheckoutScreen(),
      ),
      GoRoute(
        path: AppConstants.checkoutClientScreenRoute,
        builder: (_, _) => const ClientSelectionScreen(),
      ),
      GoRoute(
        path: AppConstants.catalogSyncScreenRoute,
        builder: (_, _) => const CatalogSyncScreen(),
      ),
      GoRoute(
        path: AppConstants.salesHistoryScreenRoute,
        builder: (_, _) => const SalesHistoryScreen(),
      ),
      GoRoute(
        path: AppConstants.saleDetailScreenRoute,
        builder: (_, state) => SaleDetailScreen(
          orderGuid: state.pathParameters['orderGuid'] ?? '',
        ),
      ),
    ],
  );
});
