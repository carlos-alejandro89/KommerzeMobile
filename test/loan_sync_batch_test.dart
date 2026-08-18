import 'package:flutter_test/flutter_test.dart';
import 'package:kommerze_mobile/features/loans/data/models/loan_sync_batch.dart';

void main() {
  test('conserva los GUID de préstamos y aplicaciones en el payload', () {
    const batch = LoanSyncBatch(
      loans: [
        {
          'prestamoGuid': 'prestamo-guid',
          'sucursalGuid': 'sucursal-guid',
          'clienteGuid': 'cliente-guid',
          'usuarioGuid': 'usuario-guid',
        },
      ],
      applications: [
        {
          'aplicacionGuid': 'aplicacion-guid',
          'cobroGuid': 'cobro-guid',
          'prestamoGuid': 'prestamo-guid',
        },
      ],
    );

    final json = batch.toJson();
    final loan = (json['prestamos']! as List).single as Map;
    final application = (json['aplicaciones']! as List).single as Map;

    expect(loan['sucursalGuid'], 'sucursal-guid');
    expect(loan['usuarioGuid'], 'usuario-guid');
    expect(application['cobroGuid'], 'cobro-guid');
    expect(application['prestamoGuid'], 'prestamo-guid');
  });

  test('mapea el resultado y snapshot devueltos por Cloud', () {
    final result = LoanSyncResult.fromJson({
      'prestamos': ['prestamo-guid'],
      'aplicaciones': ['aplicacion-guid'],
    });
    final snapshot = LoanSyncBatch.fromJson({
      'Prestamos': [
        {'PrestamoGuid': 'prestamo-guid'},
      ],
      'Aplicaciones': [
        {'AplicacionGuid': 'aplicacion-guid'},
      ],
    });

    expect(result.length, 2);
    expect(snapshot.length, 2);
    expect(snapshot.loans.single['PrestamoGuid'], 'prestamo-guid');
  });
}
