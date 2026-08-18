import 'package:flutter_test/flutter_test.dart';
import 'package:kommerze_mobile/features/collections/data/models/collection_sync_batch.dart';

void main() {
  test('conserva los GUID de referencias en el payload de cobranza', () {
    const batch = CollectionSyncBatch(
      accounts: [
        {
          'cuentaGuid': 'cuenta-guid',
          'pedidoGuid': 'pedido-guid',
          'clienteGuid': 'cliente-guid',
          'estatusGuid': 'estatus-guid',
        },
      ],
      collections: [
        {'cobroGuid': 'cobro-guid', 'usuarioGuid': 'usuario-guid'},
      ],
      paymentForms: [],
      applications: [],
    );

    final json = batch.toJson();
    final account = (json['cuentasPorCobrar']! as List).single as Map;
    final collection = (json['cobros']! as List).single as Map;

    expect(account['estatusGuid'], 'estatus-guid');
    expect(collection['usuarioGuid'], 'usuario-guid');
    expect(json.containsKey('formasPago'), isTrue);
    expect(json.containsKey('aplicaciones'), isTrue);
  });

  test('lee los GUID confirmados por el API', () {
    final result = CollectionSyncResult.fromJson({
      'cuentasPorCobrar': ['cuenta-guid'],
      'cobros': ['cobro-guid'],
      'formasPago': ['forma-guid'],
      'aplicaciones': ['aplicacion-guid'],
    });

    expect(result.length, 4);
    expect(result.accounts, ['cuenta-guid']);
    expect(result.collections, ['cobro-guid']);
  });

  test('mapea el snapshot de cobranza recuperado por sucursal', () {
    final snapshot = CollectionSyncBatch.fromJson({
      'cuentasPorCobrar': [
        {'cuentaGuid': 'cuenta-guid', 'estatusGuid': 'estatus-guid'},
      ],
      'cobros': [
        {'cobroGuid': 'cobro-guid', 'usuarioGuid': 'usuario-guid'},
      ],
      'formasPago': [
        {'pagoCobroGuid': 'forma-guid'},
      ],
      'aplicaciones': [
        {'aplicacionGuid': 'aplicacion-guid'},
      ],
    });

    expect(snapshot.length, 4);
    expect(snapshot.accounts.single['estatusGuid'], 'estatus-guid');
    expect(snapshot.collections.single['usuarioGuid'], 'usuario-guid');
  });
}
