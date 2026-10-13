class AppConstants {
  AppConstants._();

  static const publicCustomerGuid = '550e8400-e29b-41d4-a716-446655440000';

  static const splashScreenRoute = '/splash';
  static const onboardingRoute = '/onboarding';
  static const loginScreenRoute = '/login';
  static const welcomeScreenRoute = '/welcome';
  static const profileScreenRoute = '/profile';
  static const printerSettingsRoute = '/settings/printer';
  static const serverSettingsRoute = '/settings/server';
  static const licenseScreenRoute = '/license';
  static const inventoryScreenRoute = '/inventory';
  static const branchOperationScreenRoute = '/branch-operation';
  static const clientsScreenRoute = '/clients';
  static const clientFormScreenRoute = '/clients/form';
  static const salesScreenRoute = '/sales';
  static const purchasesScreenRoute = '/purchases';
  static const checkoutScreenRoute = '/sales/checkout';
  static const checkoutClientScreenRoute = '/sales/checkout/client';
  static const catalogSyncScreenRoute = '/catalog-sync';
  static const salesHistoryScreenRoute = '/sales-history';
  static const saleDetailScreenRoute = '/sales-history/:orderGuid';
  static const collectionsScreenRoute = '/collections';
  static const collectionClientScreenRoute = '/collections/:clientGuid';
  static const collectionRegisterScreenRoute =
      '/collections/:clientGuid/register';
  static const loansRoute = '/loans';
  static const loanFormRoute = '/loans/form';
  static const loanClientRoute = '/loans/client';
  static const reportsRoute = '/reports';
  static const profitReportRoute = '/reports/profits';
  static const profitReportDetailRoute = '/reports/profits/:operationGuid';
}
