import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:kommerze_mobile/core/device/device_identity_service.dart';
import 'package:kommerze_mobile/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:kommerze_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:kommerze_mobile/features/profile/presentation/controllers/profile_photo_controller.dart';
import 'package:kommerze_mobile/features/auth/data/models/usuario_dto.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_request_dto.dart';
import 'package:kommerze_mobile/features/license/presentation/screens/license_screen.dart';
import 'package:kommerze_mobile/features/license/presentation/controllers/license_activation_controller.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_license.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_branch.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_response_dto.dart';
import 'package:kommerze_mobile/features/inventory/data/models/inventory_dto.dart';
import 'package:kommerze_mobile/features/inventory/domain/entities/inventory_item.dart';
import 'package:kommerze_mobile/features/purchases/presentation/controllers/purchases_controller.dart';
import 'package:kommerze_mobile/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/clients/data/models/client_request_dto.dart';
import 'package:kommerze_mobile/features/clients/data/models/client_response_dto.dart';
import 'package:kommerze_mobile/features/sync/presentation/controllers/catalog_sync_controller.dart';
import 'package:kommerze_mobile/features/sync/presentation/screens/catalog_sync_screen.dart';
import 'package:kommerze_mobile/features/sync/data/models/status_catalog_dto.dart';
import 'package:kommerze_mobile/features/sync/data/models/user_catalog_dto.dart';
import 'package:kommerze_mobile/features/sync/data/models/payment_method_dto.dart';
import 'package:kommerze_mobile/features/sales/data/models/sale_order_request_dto.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_order.dart';
import 'package:kommerze_mobile/features/sales/domain/entities/sale_payment_draft.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_history_item.dart';
import 'package:kommerze_mobile/features/sales_history/domain/entities/sale_detail.dart';
import 'package:kommerze_mobile/features/sales_history/data/services/sale_receipt_pdf_service.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/controllers/sales_history_controller.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/screens/sale_detail_screen.dart';
import 'package:kommerze_mobile/features/sales_history/presentation/screens/sales_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('calcula ventas del día por hora y excluye canceladas', () {
    final items = [
      SaleHistoryItem(
        orderGuid: 'today-1',
        folio: 1,
        date: DateTime(2026, 7, 17, 10, 30),
        isCredit: false,
        sent: false,
        clientName: 'Cliente',
        statusName: 'Confirmado',
        orderTypeName: 'Venta',
        total: 500,
        units: 1,
      ),
      SaleHistoryItem(
        orderGuid: 'today-cancelled',
        folio: 2,
        date: DateTime(2026, 7, 17, 10, 45),
        isCredit: false,
        sent: false,
        clientName: 'Cliente',
        statusName: 'Cancelado',
        orderTypeName: 'Venta',
        total: 900,
        units: 1,
      ),
      SaleHistoryItem(
        orderGuid: 'yesterday',
        folio: 3,
        date: DateTime(2026, 7, 16, 18),
        isCredit: false,
        sent: false,
        clientName: 'Cliente',
        statusName: 'Confirmado',
        orderTypeName: 'Venta',
        total: 400,
        units: 1,
      ),
    ];
    final analytics = DailySalesAnalytics.fromItems(
      items,
      now: DateTime(2026, 7, 17, 20),
    );

    expect(analytics.todayTotal, 500);
    expect(analytics.yesterdayTotal, 400);
    expect(analytics.hourlyTotals[10], 500);
    expect(analytics.variationPercentage, 25);
  });

  test('aplica al efectivo sólo el saldo pendiente y conserva el cambio', () {
    final payments = applyPaymentsToTotal([
      SalePaymentDraft(
        paymentFormKey: '03',
        amount: 300,
        isCredit: false,
        paidAt: DateTime.utc(2026, 7, 17),
      ),
      SalePaymentDraft(
        paymentFormKey: '01',
        amount: 1000,
        isCredit: false,
        paidAt: DateTime.utc(2026, 7, 17),
      ),
    ], 800);

    expect(payments, hasLength(2));
    expect(payments.first.amount, 300);
    expect(payments.last.amount, 500);
    expect(payments.fold<double>(0, (sum, item) => sum + item.amount), 800);
  });

  test('calcula el resumen del historial de ventas', () {
    final summary = SalesHistorySummary.fromItems([
      _historyItem(folio: 1, total: 100, isCredit: false),
      _historyItem(folio: 2, total: 250, isCredit: true),
    ]);

    expect(summary.sales, 2);
    expect(summary.total, 350);
    expect(summary.cashTotal, 100);
    expect(summary.creditTotal, 250);
  });

  test('identifica una venta con múltiples formas de pago', () {
    final item = SaleHistoryItem(
      orderGuid: 'order-guid',
      folio: 1,
      date: DateTime(2026, 7, 16),
      isCredit: false,
      sent: false,
      clientName: 'Cliente',
      statusName: 'Confirmado',
      orderTypeName: 'Venta',
      total: 800,
      units: 1,
      paymentForms: const [
        SalePaymentIdentifier(key: '01', description: 'EFECTIVO'),
        SalePaymentIdentifier(
          key: '03',
          description: 'TRANSFERENCIA ELECTRÓNICA DE FONDOS',
        ),
      ],
    );

    expect(item.paymentLabel, 'Multipago');
  });

  test('calcula totales del detalle de venta', () {
    final detail = _saleDetail();

    expect(detail.subtotal, 300);
    expect(detail.discount, 30);
    expect(detail.total, 270);
    expect(detail.paid, 270);
    expect(detail.payments.last.label, 'Transferencia');
  });

  test('genera el comprobante PDF de una venta', () async {
    final bytes = await SaleReceiptPdfService.build(_saleDetail());

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('construye el payload local de una venta', () {
    final request = SaleOrderRequestDto(
      SaleOrder(
        branchOriginGuid: 'branch-guid',
        orderGuid: 'order-guid',
        statusGuid: 'status-guid',
        clientGuid: 'client-guid',
        orderTypeGuid: 'sale-type-guid',
        folio: 1,
        date: DateTime.utc(2026, 7, 17, 0, 46, 21, 175),
        isCredit: true,
        sync: true,
        sent: false,
        details: const [
          SaleOrderDetail(
            levelGuid: 'level-guid',
            quantity: 2,
            purchasePrice: 100,
            salePrice: 150,
            salePrice2: 150,
            discount: 8,
          ),
        ],
      ),
    ).toJson();

    expect(request['pedidoGuid'], 'order-guid');
    expect(request['folio'], 1);
    expect(request['esCredito'], isTrue);
    expect(request['sync'], isTrue);
    final detail = (request['pedidoDetalle'] as List).single as Map;
    expect(detail['nivelGuid'], 'level-guid');
    expect(detail['precioCompra'], 100);
    expect(detail['descuento'], 8);
    expect(detail['trasladoIVA'], 0);
    expect(detail['tasaIVA'], 0);
    expect(detail['retencionISR'], 0);
    expect(detail['tasaISR'], 0);
  });

  test('la compra usa precio de compra y los GUID configurados', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const product = InventoryItem(
      code: 'P-001',
      description: 'Producto',
      packageLevel: 'PIEZA',
      barcode: '',
      purchasePrice: 50,
      salePrice: 80,
      discountPercentage: 10,
      stock: 0,
      lineName: 'GENERAL',
      brandName: 'MARCA',
      levelGuid: 'level-guid',
      productGuid: 'product-guid',
      packageGuid: 'package-guid',
    );

    final added = container
        .read(purchaseCartControllerProvider.notifier)
        .add(product, 5);

    expect(added, isTrue);
    expect(container.read(purchaseCartTotalProvider), 250);
    expect(
      SalesLocalDataSource.publicCustomerGuid,
      '550e8400-e29b-41d4-a716-446655440000',
    );
    expect(
      SalesLocalDataSource.purchaseOrderTypeGuid,
      'c82164a9-616c-4148-80fd-c4702d8a7cca',
    );
  });

  test('mapea un método de pago SAT', () {
    final method = PaymentMethodDto.fromJson({
      'id': 1,
      'clave': 'PUE',
      'descripcion': 'PAGO EN UNA SOLA EXHIBICIÓN',
      'isActive': false,
      'guid': '9fd94ce1-304e-4706-966c-23966dfbc702',
      'createdAt': '2026-07-07T13:43:46.004627',
      'updatedAt': '0001-01-01T00:00:00',
      'deletedAt': null,
    });

    expect(method.key, 'PUE');
    expect(method.description, 'PAGO EN UNA SOLA EXHIBICIÓN');
    expect(method.guid, '9fd94ce1-304e-4706-966c-23966dfbc702');
    expect(method.isActive, isFalse);
    expect(method.updatedAt, isNull);
  });

  test('mapea un usuario sin conservar el password remoto', () {
    final user = UserCatalogDto.fromJson({
      'id': 1,
      'perfilId': 1,
      'nombre': 'Super administrador',
      'telefono': '',
      'correoElectronico': 'superadmin@softi.digital',
      'correoConfirmado': true,
      'password': r'$2a$11$hash-que-no-debe-persistirse',
      'imgPerfil': null,
      'guid': 'f4cb2081-879e-4494-9bd1-121df5a6e5e6',
      'createdAt': '2026-07-09T23:15:06.994415',
      'updatedAt': '2026-07-09T23:15:06.994416',
      'deletedAt': null,
    });

    expect(user.id, 1);
    expect(user.profileId, 1);
    expect(user.name, 'Super administrador');
    expect(user.email, 'superadmin@softi.digital');
    expect(user.emailConfirmed, isTrue);
    expect(user.guid, 'f4cb2081-879e-4494-9bd1-121df5a6e5e6');
  });

  test('mapea un cliente descargado desde el catálogo', () {
    final client = ClientResponseDto.fromJson({
      'id': 1,
      'razonSocial': 'Público General',
      'rfc': 'XAXA010101000',
      'correo': 'clientes@softi.digital',
      'telefono': '',
      'creditoMaximo': 0,
      'diasCredito': 0,
      'guid': '550e8400-e29b-41d4-a716-446655440000',
      'createdAt': '2026-07-09T23:15:06.811422',
      'updatedAt': '2026-07-09T23:15:06.811422',
      'deletedAt': null,
    });

    expect(client.name, 'Público General');
    expect(client.rfc, 'XAXA010101000');
    expect(client.guid, '550e8400-e29b-41d4-a716-446655440000');
    expect(client.isActive, isTrue);
  });

  test('mapea un estatus remoto y conserva su GUID', () {
    final status = StatusCatalogDto.fromJson({
      'id': 12,
      'nombre': 'En proceso',
      'guid': '8d9f1a8d-7c79-4d6a-a2fd-6a8e7f1d2c41',
      'createdAt': '2026-07-09T23:15:06.81185',
      'updatedAt': '2026-07-09T23:15:06.81185',
      'deletedAt': null,
    });

    expect(status.id, 12);
    expect(status.name, 'En proceso');
    expect(status.guid, '8d9f1a8d-7c79-4d6a-a2fd-6a8e7f1d2c41');
    expect(status.createdAt?.year, 2026);
    expect(status.deletedAt, isNull);
  });

  test('serializa el contrato de clientes para la API', () {
    final json = ClientRequestDto(
      draft: const ClientDraft(
        name: 'Abarrotes del Centro',
        rfc: 'abc090101xyz',
        email: 'CLIENTE@KOMMERZE.COM',
        phone: '9931234567',
        creditAmount: 15000,
        creditDays: 30,
      ),
    ).toJson();

    expect(json.keys.toSet(), {
      'razonSocial',
      'rfc',
      'correo',
      'telefono',
      'creditoMaximo',
      'diasCredito',
    });
    expect(json['razonSocial'], 'Abarrotes del Centro');
    expect(json['rfc'], 'ABC090101XYZ');
    expect(json['creditoMaximo'], 15000);
    expect(json['diasCredito'], 30);
  });

  test('mapea un cliente local con crédito y GUID', () {
    final client = Client.fromMap({
      'guid': 'client-guid',
      'nombre': 'Abarrotes del Centro',
      'rfc': 'ABC090101XYZ',
      'correo': 'cliente@kommerze.com',
      'telefono': '9931234567',
      'monto_credito': 15000,
      'dias_credito': 30,
      'activo': 1,
      'created_at': '2026-07-15T14:45:00Z',
      'updated_at': '2026-07-15T14:45:00Z',
    });

    expect(client.guid, 'client-guid');
    expect(client.creditAmount, 15000);
    expect(client.creditDays, 30);
    expect(client.isActive, isTrue);
  });

  test('mapea una operación de sucursal activa', () {
    final operation = BranchOperation.fromMap({
      'usuario_apertura_id': 1,
      'usuario_apertura_guid': 'user-opening-guid',
      'usuario_apertura_nombre': 'Usuario de apertura',
      'sucursal_id': 8,
      'estatus_id': 1,
      'fecha_inicio': '2026-07-15T14:45:00Z',
      'valor_inicial_inventario': 623278.93,
      'monto_inicial_caja': 500,
      'guid': 'operation-guid',
    });

    expect(operation.statusId, 1);
    expect(operation.endDate, isNull);
    expect(operation.initialInventoryValue, 623278.93);
    expect(operation.initialCashAmount, 500);
    expect(operation.openingUserGuid, 'user-opening-guid');
    expect(operation.openingUserName, 'Usuario de apertura');
  });

  test('separa la fotografía de perfil por usuario', () {
    expect(
      profilePhotoPreferenceKeyFor('USER-A'),
      'profile_photo_base64_user-a',
    );
    expect(
      profilePhotoPreferenceKeyFor('USER-A'),
      isNot(profilePhotoPreferenceKeyFor('USER-B')),
    );
  });

  test('inicializa precios sin existencia y recupera el respaldo', () {
    final price = InventoryDto.fromPrice({
      'codigo': '31211509',
      'nivelEmpaque': 'LITRO',
      'imgReferencia': '/uploads/productos/31211509.png',
      'precioCompra': 150,
      'precioVenta': 210,
      'porcentajeDescuento': 8,
      'existencia': 99,
      'nivelGuid': 'nivel-guid',
      'productoGuid': 'producto-guid',
    });
    final backup = InventoryDto.fromBackup({
      'codigo': '31211509',
      'nombreEmpaque': 'LITRO',
      'precioVenta': 210,
      'existencia': 33,
      'nivelGuid': 'nivel-guid',
      'productoGuid': 'producto-guid',
    });

    expect(price.stock, 0);
    expect(price.purchasePrice, 150);
    expect(price.discountPercentage, 8);
    expect(price.imagePath, '/uploads/productos/31211509.png');
    expect(backup.stock, 33);
    expect(price.levelGuid, backup.levelGuid);
  });

  test('mapea sucursal y firma de la activación', () {
    final result = LicenseActivationResponseDto.fromJson({
      'success': true,
      'mensaje': 'Licencia activada exitosamente',
      'data': {
        'sucursal': {
          'id': 8,
          'empresaId': 1,
          'listaPrecioId': null,
          'licenciaId': 1,
          'licencia': {
            'id': 1,
            'nombreDispositivo': 'Mobile',
            'licenciaKey': 'KMZ-STD-DVGR-GCWO',
            'appVersion': '1.0.0',
            'machineId': 'ieieieieie',
            'numMesesVigencia': 12,
            'fechaActivacion': '2026-07-15T21:22:43.1915237Z',
            'fechaExpiracion': '2027-07-15T21:22:43.1914577Z',
            'guid': 'license-guid',
          },
          'clave': 'C007',
          'nombreSucursal': 'OCUILTZAPOTLAN',
          'calle': 'MARIANO ABASOLO ESQ. ALDAMA',
          'exterior': 'SN',
          'interior': null,
          'colonia': 'OCUILTZAPOTLAN',
          'ciudad': 'VILLAHERMOSA, CENTRO',
          'estado': 'TABASCO',
          'codigoPostal': '86270',
          'telefono': '9933170552',
          'correo': 'ocuitlzapotlan@pbb-sayer.com.mx',
          'serieCfdi': 'H',
          'comisionVentas': 50,
          'valorInventario': 0,
          'guid': 'branch-guid',
        },
        'signature': 'signed-value',
      },
    });

    expect(result.success, isTrue);
    expect(result.signature, 'signed-value');
    expect(result.branch?.name, 'OCUILTZAPOTLAN');
    expect(result.branch?.license.expirationDate?.year, 2027);
  });

  test('restaura una licencia almacenada localmente', () {
    final license = StoredLicense.fromMap({
      'machine_id': 'machine-01',
      'device_name': 'Caja principal',
      'license_key_hint': '••••1234',
      'is_active': 1,
      'activated_at': '2026-07-15T12:00:00.000Z',
    });

    expect(license.isActive, isTrue);
    expect(license.machineId, 'machine-01');
    expect(license.licenseKeyHint, '••••1234');
  });

  test('serializa el contrato de activación de licencia', () {
    const request = LicenseActivationRequestDto(
      machineId: 'machine-01',
      licenseKey: 'LICENSE-KEY',
      deviceName: 'Caja principal',
    );

    expect(request.toJson(), {
      'machineId': 'machine-01',
      'licenseKey': 'LICENSE-KEY',
      'nombreDispositivo': 'Caja principal',
    });
  });

  test('mapea la respuesta real del login', () {
    final user = UsuarioDto.fromLoginResponse({
      'success': true,
      'mensaje': 'Login exitoso',
      'httpCode': 200,
      'data': {
        'token': 'jwt-token',
        'email': 'superadmin@softi.digital',
        'nombreCompleto': 'Super administrador',
        'perfil': 'Super Admin',
        'usuarioGuid': 'f4cb2081-879e-4494-9bd1-121df5a6e5e6',
      },
    });

    expect(user.accessToken, 'jwt-token');
    expect(user.name, 'Super administrador');
    expect(user.profile, 'Super Admin');
    expect(user.userGuid, 'f4cb2081-879e-4494-9bd1-121df5a6e5e6');
    expect(user.toJson().containsKey('accessToken'), isFalse);
  });

  testWidgets('muestra la bienvenida', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a Kommerze'), findsOneWidget);
    expect(find.text('Módulos principales'), findsOneWidget);
  });

  testWidgets('guarda la preferencia del menú', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: WelcomeScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.view_quilt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjetas'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('welcome_menu_layout'), 'grid');
  });

  testWidgets('muestra las secciones del perfil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Información personal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Seguridad'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Seguridad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Preferencias'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Preferencias'), findsOneWidget);
  });

  testWidgets('muestra el formulario de activación de licencia', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licenseDetailsProvider.overrideWith((ref) async => null),
          deviceIdentityServiceProvider.overrideWithValue(
            const _FakeDeviceIdentityService(),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: 40)),
            child: LicenseScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activar licencia'), findsOneWidget);
    expect(find.text('ID del Dispositivo:'), findsOneWidget);
    expect(find.text('Clave de licencia:'), findsOneWidget);
    expect(find.text('Nombre del dispositivo:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra la licencia activa y su sucursal', (tester) async {
    final details = LicenseDetails(
      license: StoredLicense(
        machineId: 'device-01',
        deviceName: 'Mobile',
        licenseKeyHint: '••••GCWO',
        apiId: 1,
        guid: 'license-guid',
        appVersion: '1.0.0',
        validityMonths: 12,
        isActive: true,
        activatedAt: DateTime.utc(2026, 7, 15),
        expiresAt: DateTime.utc(2027, 7, 15),
      ),
      branch: const StoredBranch(
        id: 8,
        code: 'C007',
        name: 'OCUILTZAPOTLAN',
        address: 'MARIANO ABASOLO SN',
        city: 'VILLAHERMOSA, CENTRO',
        state: 'TABASCO',
        postalCode: '86270',
        phone: '9933170552',
        email: 'sucursal@kommerze.com',
        cfdiSeries: 'H',
        guid: 'branch-guid',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licenseDetailsProvider.overrideWith((ref) async => details),
        ],
        child: const MaterialApp(home: LicenseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Licencia activa'), findsOneWidget);
    expect(find.text('Datos de la licencia'), findsOneWidget);
    expect(find.text('OCUILTZAPOTLAN'), findsOneWidget);
  });

  testWidgets('muestra la pantalla Sync y sus catálogos', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogSyncControllerProvider.overrideWith(
            _FakeCatalogSyncController.new,
          ),
        ],
        child: const MaterialApp(home: CatalogSyncScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Formas de pago'), findsOneWidget);
    expect(find.text('Perfiles'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Clientes'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Clientes'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tipo de pedido'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Tipo de pedido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra una venta en el historial', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesHistoryProvider.overrideWith(
            (ref) async => [
              _historyItem(folio: 58, total: 1250, isCredit: false),
            ],
          ),
        ],
        child: const MaterialApp(
          locale: Locale('es', 'MX'),
          supportedLocales: [Locale('es', 'MX')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SalesHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Historial de ventas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Folio: VTA-000058'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Folio: VTA-000058'), findsOneWidget);
    expect(find.text('Abarrotes del Centro'), findsOneWidget);
    expect(find.text(r'$1,250.00'), findsWidgets);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('16 jul 2026 10:30 a.m.  •  2 artículos'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar fecha de venta'), findsOneWidget);
    expect(find.text('Todas las fechas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra artículos y pagos en el detalle de venta', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleDetailProvider(
            'order-58',
          ).overrideWith((ref) async => _saleDetail()),
        ],
        child: const MaterialApp(home: SaleDetailScreen(orderGuid: 'order-58')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalle de venta'), findsOneWidget);
    expect(find.text('VTA-000058'), findsOneWidget);
    expect(find.text('Artículos vendidos'), findsOneWidget);
    expect(find.text('Producto de prueba'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pagos realizados'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Pagos realizados'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Transferencia'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Compartir'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SaleDetail _saleDetail() => SaleDetail(
  orderGuid: 'order-58',
  folio: 58,
  date: DateTime(2026, 7, 16, 10, 30),
  isCredit: false,
  sent: false,
  clientName: 'Abarrotes del Centro',
  clientRfc: 'ABC090101XYZ',
  statusName: 'Confirmado',
  orderTypeName: 'Venta',
  branchName: 'Sucursal Centro',
  items: const [
    SaleDetailItem(
      levelGuid: 'level-1',
      code: 'P-001',
      name: 'Producto de prueba',
      barcode: '750100000001',
      quantity: 2,
      unitPrice: 150,
      discountPercentage: 10,
    ),
  ],
  payments: [
    SaleDetailPayment(
      guid: 'payment-1',
      paymentFormKey: '01',
      paymentFormDescription: 'EFECTIVO',
      paidAt: DateTime(2026, 7, 16, 10, 30),
      amount: 200,
      isCredit: false,
    ),
    SaleDetailPayment(
      guid: 'payment-2',
      paymentFormKey: '03',
      paymentFormDescription: 'TRANSFERENCIA ELECTRÓNICA DE FONDOS',
      paidAt: DateTime(2026, 7, 16, 10, 31),
      amount: 70,
      isCredit: false,
    ),
  ],
);

SaleHistoryItem _historyItem({
  required int folio,
  required double total,
  required bool isCredit,
}) => SaleHistoryItem(
  orderGuid: 'order-$folio',
  folio: folio,
  date: DateTime(2026, 7, 16, 10, 30),
  isCredit: isCredit,
  sent: false,
  clientName: 'Abarrotes del Centro',
  statusName: 'Confirmado',
  orderTypeName: 'Venta',
  total: total,
  units: 2,
  collectedAmount: isCredit ? 0 : total,
  creditAmount: isCredit ? total : 0,
  paymentForms: [
    SalePaymentIdentifier(
      key: isCredit ? '99' : '01',
      description: isCredit ? 'POR DEFINIR' : 'EFECTIVO',
    ),
  ],
);

class _FakeCatalogSyncController extends CatalogSyncController {
  @override
  Future<void> restoreLocalStatus() async {}
}

class _FakeDeviceIdentityService implements DeviceIdentityService {
  const _FakeDeviceIdentityService();

  @override
  Future<DeviceIdentity> load() async {
    return const DeviceIdentity(id: 'device-01', name: 'Mobile');
  }
}
