import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _databaseName = 'kommerze_mobile.db';
  // Línea base consolidada. Se conserva el número para abrir sin pérdida de
  // datos las instalaciones que ya alcanzaron este esquema.
  static const _databaseVersion = 18;

  Database? _database;

  Future<Database> get instance async {
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    return openDatabase(
      path.join(directory, _databaseName),
      version: _databaseVersion,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onOpen: _ensureCurrentSchema,
      onCreate: (database, version) async {
        await _createLicensesTable(database);
        await _createBranchesTable(database);
        await _createInventoryTable(database);
        await _createBranchOperationsTable(database);
        await _createClientsTable(database);
        await _createPaymentFormsTable(database);
        await _createPaymentMethodsTable(database);
        await _createProfilesTable(database);
        await _createOrderTypesTable(database);
        await _createStatusesTable(database);
        await _createUsersTable(database);
        await _createSalesTables(database);
        await _createSalePaymentsTable(database);
        await _createCollectionsTables(database);
      },
    );
  }

  Future<void> _createLicensesTable(Database database) {
    return database.execute('''
      CREATE TABLE licenses (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        machine_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        license_key_hint TEXT NOT NULL,
        license_guid TEXT,
        license_api_id INTEGER,
        validity_months INTEGER,
        app_version TEXT,
        expires_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        activated_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBranchesTable(Database database) {
    return database.execute('''
      CREATE TABLE sucursales (
        id INTEGER PRIMARY KEY,
        empresa_id INTEGER NOT NULL,
        lista_precio_id INTEGER,
        licencia_id INTEGER NOT NULL,
        clave TEXT NOT NULL,
        nombre_sucursal TEXT NOT NULL,
        calle TEXT,
        exterior TEXT,
        interior TEXT,
        colonia TEXT,
        ciudad TEXT,
        estado TEXT,
        codigo_postal TEXT,
        telefono TEXT,
        correo TEXT,
        serie_cfdi TEXT,
        comision_ventas REAL NOT NULL DEFAULT 0,
        valor_inventario REAL NOT NULL DEFAULT 0,
        guid TEXT NOT NULL UNIQUE,
        signature TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createInventoryTable(Database database) {
    return database.execute('''
      CREATE TABLE inventario (
        nivel_guid TEXT PRIMARY KEY,
        producto_guid TEXT NOT NULL,
        empaque_guid TEXT,
        codigo TEXT NOT NULL,
        descripcion TEXT,
        nivel_empaque TEXT NOT NULL,
        codigo_barras TEXT NOT NULL DEFAULT '',
        img_referencia TEXT NOT NULL DEFAULT '',
        precio_compra REAL NOT NULL DEFAULT 0,
        precio_venta REAL NOT NULL DEFAULT 0,
        porcentaje_descuento REAL NOT NULL DEFAULT 0,
        existencia REAL NOT NULL DEFAULT 0,
        nombre_linea TEXT NOT NULL DEFAULT 'SIN LINEA',
        nombre_marca TEXT NOT NULL DEFAULT 'SIN MARCA',
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBranchOperationsTable(Database database) {
    return database.execute('''
      CREATE TABLE operaciones_sucursal (
        guid TEXT PRIMARY KEY,
        usuario_apertura_id INTEGER NOT NULL,
        usuario_apertura_guid TEXT,
        usuario_apertura_nombre TEXT,
        usuario_cierre_id INTEGER,
        sucursal_id INTEGER NOT NULL,
        estatus_id INTEGER NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT,
        valor_inicial_inventario REAL NOT NULL DEFAULT 0,
        valor_compras REAL NOT NULL DEFAULT 0,
        valor_ventas REAL NOT NULL DEFAULT 0,
        descuentos_aplicados REAL NOT NULL DEFAULT 0,
        ajuste_inventario REAL NOT NULL DEFAULT 0,
        valor_final_inventario REAL NOT NULL DEFAULT 0,
        ingreso_efectivo REAL NOT NULL DEFAULT 0,
        ingreso_tarjetas REAL NOT NULL DEFAULT 0,
        ingreso_cheques REAL NOT NULL DEFAULT 0,
        ingreso_transferencia REAL NOT NULL DEFAULT 0,
        ingreso_otros REAL NOT NULL DEFAULT 0,
        creditos REAL NOT NULL DEFAULT 0,
        vales_salida REAL NOT NULL DEFAULT 0,
        vales_entrantes REAL NOT NULL DEFAULT 0,
        cfdi_efectivo INTEGER NOT NULL DEFAULT 0,
        cfdi_tarjetas INTEGER NOT NULL DEFAULT 0,
        cfdi_cheques INTEGER NOT NULL DEFAULT 0,
        cfdi_transferencia INTEGER NOT NULL DEFAULT 0,
        cfdi_otros INTEGER NOT NULL DEFAULT 0,
        bajas_mercancia REAL NOT NULL DEFAULT 0,
        monto_inicial_caja REAL NOT NULL DEFAULT 0,
        observaciones TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createClientsTable(Database database) {
    return database.execute('''
      CREATE TABLE clientes (
        guid TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        rfc TEXT NOT NULL,
        correo TEXT NOT NULL DEFAULT '',
        telefono TEXT NOT NULL DEFAULT '',
        monto_credito REAL NOT NULL DEFAULT 0,
        dias_credito INTEGER NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        synced_at TEXT
      )
    ''');
  }

  Future<void> _createPaymentFormsTable(Database database) {
    return database.execute('''
      CREATE TABLE formas_pago (
        guid TEXT PRIMARY KEY,
        api_id INTEGER NOT NULL,
        clave TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPaymentMethodsTable(Database database) {
    return database.execute('''
      CREATE TABLE metodos_pago (
        guid TEXT PRIMARY KEY,
        api_id INTEGER NOT NULL,
        clave TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createProfilesTable(Database database) {
    return database.execute('''
      CREATE TABLE perfiles (
        guid TEXT PRIMARY KEY,
        api_id INTEGER NOT NULL,
        nombre_perfil TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createOrderTypesTable(Database database) {
    return database.execute('''
      CREATE TABLE tipos_pedido (
        guid TEXT PRIMARY KEY,
        api_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        icon TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createStatusesTable(Database database) {
    return database.execute('''
      CREATE TABLE estatus (
        guid TEXT PRIMARY KEY,
        api_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createUsersTable(Database database) {
    return database.execute('''
      CREATE TABLE usuarios (
        guid TEXT PRIMARY KEY,
        api_id INTEGER NOT NULL,
        perfil_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL DEFAULT '',
        correo_electronico TEXT NOT NULL,
        correo_confirmado INTEGER NOT NULL DEFAULT 0,
        img_perfil TEXT,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSalesTables(Database database) async {
    await database.execute('''
      CREATE TABLE pedidos (
        pedido_guid TEXT PRIMARY KEY,
        sucursal_origen_guid TEXT NOT NULL,
        estatus_guid TEXT NOT NULL,
        cliente_guid TEXT NOT NULL,
        tipo_pedido_guid TEXT NOT NULL,
        folio INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        es_credito INTEGER NOT NULL DEFAULT 0,
        sync INTEGER NOT NULL DEFAULT 1,
        enviado INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (tipo_pedido_guid, folio)
      )
    ''');
    await database.execute('''
      CREATE TABLE pedido_detalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pedido_guid TEXT NOT NULL,
        nivel_guid TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_compra REAL NOT NULL DEFAULT 0,
        precio_venta REAL NOT NULL DEFAULT 0,
        precio_venta_2 REAL NOT NULL DEFAULT 0,
        descuento REAL NOT NULL DEFAULT 0,
        traslado_iva REAL NOT NULL DEFAULT 0,
        tasa_iva REAL NOT NULL DEFAULT 0,
        retencion_isr REAL NOT NULL DEFAULT 0,
        tasa_isr REAL NOT NULL DEFAULT 0,
        info_adicional TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (pedido_guid) REFERENCES pedidos(pedido_guid)
          ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_pedido_detalle_pedido ON pedido_detalle(pedido_guid)',
    );
    await database.execute(
      'CREATE INDEX idx_pedidos_pendientes ON pedidos(enviado, fecha)',
    );
  }

  Future<void> _createSalePaymentsTable(Database database) async {
    await database.execute('''
      CREATE TABLE pagos_venta (
        pago_guid TEXT PRIMARY KEY,
        forma_pago_guid TEXT NOT NULL,
        pedido_guid TEXT NOT NULL,
        fecha_pago TEXT NOT NULL,
        monto REAL NOT NULL,
        es_credito INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (pedido_guid) REFERENCES pedidos(pedido_guid)
          ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_pagos_venta_pedido ON pagos_venta(pedido_guid)',
    );
    await database.execute(
      'CREATE INDEX idx_pagos_venta_fecha ON pagos_venta(fecha_pago)',
    );
    await database.execute(
      'CREATE INDEX idx_pagos_venta_forma ON pagos_venta(forma_pago_guid)',
    );
  }

  Future<void> _ensureCurrentSchema(Database database) async {
    await _createCollectionsTables(database);
  }

  Future<void> _createCollectionsTables(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cuentas_por_cobrar (
        cuenta_guid TEXT PRIMARY KEY,
        cliente_guid TEXT NOT NULL,
        pedido_guid TEXT NOT NULL UNIQUE,
        importe_original REAL NOT NULL,
        fecha_emision TEXT NOT NULL,
        fecha_vencimiento TEXT NOT NULL,
        estatus_guid TEXT NOT NULL,
        bloqueada INTEGER NOT NULL DEFAULT 0,
        sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cliente_guid) REFERENCES clientes(guid),
        FOREIGN KEY (pedido_guid) REFERENCES pedidos(pedido_guid)
          ON DELETE CASCADE,
        FOREIGN KEY (estatus_guid) REFERENCES estatus(guid)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cobros_cliente (
        cobro_guid TEXT PRIMARY KEY,
        sucursal_guid TEXT NOT NULL,
        cliente_guid TEXT NOT NULL,
        fecha TEXT NOT NULL,
        monto_total REAL NOT NULL,
        saldo_disponible REAL NOT NULL DEFAULT 0,
        referencia TEXT,
        usuario_guid TEXT,
        usuario_nombre TEXT,
        cancelado INTEGER NOT NULL DEFAULT 0,
        fecha_cancelacion TEXT,
        motivo_cancelacion TEXT,
        sync INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cliente_guid) REFERENCES clientes(guid)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS cobro_formas_pago (
        pago_cobro_guid TEXT PRIMARY KEY,
        cobro_guid TEXT NOT NULL,
        forma_pago_guid TEXT NOT NULL,
        monto REAL NOT NULL,
        referencia TEXT,
        FOREIGN KEY (cobro_guid) REFERENCES cobros_cliente(cobro_guid)
          ON DELETE CASCADE,
        FOREIGN KEY (forma_pago_guid) REFERENCES formas_pago(guid)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS aplicaciones_cobro (
        aplicacion_guid TEXT PRIMARY KEY,
        cobro_guid TEXT NOT NULL,
        cuenta_guid TEXT NOT NULL,
        monto_aplicado REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (cobro_guid) REFERENCES cobros_cliente(cobro_guid)
          ON DELETE CASCADE,
        FOREIGN KEY (cuenta_guid) REFERENCES cuentas_por_cobrar(cuenta_guid)
          ON DELETE CASCADE
      )
    ''');
    await _ensureReceivableStatusReference(database);
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_cxc_cliente ON cuentas_por_cobrar(cliente_guid, fecha_vencimiento)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_cxc_pedido ON cuentas_por_cobrar(pedido_guid)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_cxc_estatus ON cuentas_por_cobrar(estatus_guid)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_cobros_cliente ON cobros_cliente(cliente_guid, fecha)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_cobros_fecha ON cobros_cliente(fecha, cancelado)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_aplicaciones_cuenta ON aplicaciones_cobro(cuenta_guid)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_aplicaciones_cobro ON aplicaciones_cobro(cobro_guid)',
    );
  }

  Future<void> _ensureReceivableStatusReference(
    DatabaseExecutor database,
  ) async {
    final columns = await database.rawQuery(
      'PRAGMA table_info(cuentas_por_cobrar)',
    );
    final names = columns.map((row) => row['name']?.toString()).toSet();
    if (!names.contains('estatus_guid')) {
      await database.execute(
        'ALTER TABLE cuentas_por_cobrar ADD COLUMN estatus_guid TEXT REFERENCES estatus(guid)',
      );
    }
    if (names.contains('estatus')) {
      await database.rawUpdate('''
        UPDATE cuentas_por_cobrar
        SET estatus_guid = (
          SELECT e.guid
          FROM estatus e
          WHERE LOWER(e.nombre) = CASE LOWER(cuentas_por_cobrar.estatus)
            WHEN 'cancelada' THEN 'cancelado'
            ELSE LOWER(cuentas_por_cobrar.estatus)
          END
          LIMIT 1
        )
        WHERE estatus_guid IS NULL
      ''');
    }
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_cxc_estatus ON cuentas_por_cobrar(estatus_guid)',
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
