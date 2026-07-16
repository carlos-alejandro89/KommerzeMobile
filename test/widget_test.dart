import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kommerze_mobile/core/storage/shared_prefs_provider.dart';
import 'package:kommerze_mobile/core/device/device_identity_service.dart';
import 'package:kommerze_mobile/features/welcome/presentation/screens/welcome_screen.dart';
import 'package:kommerze_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:kommerze_mobile/features/auth/data/models/usuario_dto.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_request_dto.dart';
import 'package:kommerze_mobile/features/license/presentation/screens/license_screen.dart';
import 'package:kommerze_mobile/features/license/presentation/controllers/license_activation_controller.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_license.dart';
import 'package:kommerze_mobile/features/license/domain/entities/license_details.dart';
import 'package:kommerze_mobile/features/license/domain/entities/stored_branch.dart';
import 'package:kommerze_mobile/features/license/data/models/license_activation_response_dto.dart';
import 'package:kommerze_mobile/features/inventory/data/models/inventory_dto.dart';
import 'package:kommerze_mobile/features/branch_operation/domain/entities/branch_operation.dart';
import 'package:kommerze_mobile/features/clients/domain/entities/client.dart';
import 'package:kommerze_mobile/features/clients/data/models/client_request_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('serializa el contrato de clientes para la API', () {
    final json = ClientRequestDto(
      guid: 'client-guid',
      draft: const ClientDraft(
        name: 'Abarrotes del Centro',
        rfc: 'abc090101xyz',
        email: 'CLIENTE@KOMMERZE.COM',
        phone: '9931234567',
        creditAmount: 15000,
        creditDays: 30,
      ),
    ).toJson();

    expect(json['guid'], 'client-guid');
    expect(json['rfc'], 'ABC090101XYZ');
    expect(json['montoCredito'], 15000);
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
  });

  test('inicializa precios sin existencia y recupera el respaldo', () {
    final price = InventoryDto.fromPrice({
      'codigo': '31211509',
      'nivelEmpaque': 'LITRO',
      'precioVenta': 210,
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
}

class _FakeDeviceIdentityService implements DeviceIdentityService {
  const _FakeDeviceIdentityService();

  @override
  Future<DeviceIdentity> load() async {
    return const DeviceIdentity(id: 'device-01', name: 'Mobile');
  }
}
