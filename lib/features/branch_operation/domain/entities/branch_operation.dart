class BranchOperation {
  final int openingUserId;
  final String openingUserGuid;
  final String openingUserName;
  final int? closingUserId;
  final int branchId;
  final int statusId;
  final DateTime startDate;
  final DateTime? endDate;
  final double initialInventoryValue;
  final double purchasesValue;
  final double salesValue;
  final double appliedDiscounts;
  final double inventoryAdjustment;
  final double finalInventoryValue;
  final double cashIncome;
  final double cardIncome;
  final double checkIncome;
  final double transferIncome;
  final double otherIncome;
  final double credits;
  final double outgoingVouchers;
  final double incomingVouchers;
  final int cashCfdi;
  final int cardCfdi;
  final int checkCfdi;
  final int transferCfdi;
  final int otherCfdi;
  final double merchandiseLosses;
  final double initialCashAmount;
  final String? notes;
  final String guid;

  const BranchOperation({
    required this.openingUserId,
    this.openingUserGuid = '',
    this.openingUserName = 'Usuario',
    required this.closingUserId,
    required this.branchId,
    required this.statusId,
    required this.startDate,
    required this.endDate,
    required this.initialInventoryValue,
    required this.purchasesValue,
    required this.salesValue,
    required this.appliedDiscounts,
    required this.inventoryAdjustment,
    required this.finalInventoryValue,
    required this.cashIncome,
    required this.cardIncome,
    required this.checkIncome,
    required this.transferIncome,
    required this.otherIncome,
    required this.credits,
    required this.outgoingVouchers,
    required this.incomingVouchers,
    required this.cashCfdi,
    required this.cardCfdi,
    required this.checkCfdi,
    required this.transferCfdi,
    required this.otherCfdi,
    required this.merchandiseLosses,
    required this.initialCashAmount,
    required this.notes,
    required this.guid,
  });

  factory BranchOperation.fromMap(Map<String, Object?> map) {
    return BranchOperation(
      openingUserId: _integer(map['usuario_apertura_id']),
      openingUserGuid: map['usuario_apertura_guid']?.toString() ?? '',
      openingUserName: map['usuario_apertura_nombre']?.toString() ?? 'Usuario',
      closingUserId: _nullableInteger(map['usuario_cierre_id']),
      branchId: _integer(map['sucursal_id']),
      statusId: _integer(map['estatus_id']),
      startDate: DateTime.parse(map['fecha_inicio'].toString()),
      endDate: DateTime.tryParse(map['fecha_fin']?.toString() ?? ''),
      initialInventoryValue: _decimal(map['valor_inicial_inventario']),
      purchasesValue: _decimal(map['valor_compras']),
      salesValue: _decimal(map['valor_ventas']),
      appliedDiscounts: _decimal(map['descuentos_aplicados']),
      inventoryAdjustment: _decimal(map['ajuste_inventario']),
      finalInventoryValue: _decimal(map['valor_final_inventario']),
      cashIncome: _decimal(map['ingreso_efectivo']),
      cardIncome: _decimal(map['ingreso_tarjetas']),
      checkIncome: _decimal(map['ingreso_cheques']),
      transferIncome: _decimal(map['ingreso_transferencia']),
      otherIncome: _decimal(map['ingreso_otros']),
      credits: _decimal(map['creditos']),
      outgoingVouchers: _decimal(map['vales_salida']),
      incomingVouchers: _decimal(map['vales_entrantes']),
      cashCfdi: _integer(map['cfdi_efectivo']),
      cardCfdi: _integer(map['cfdi_tarjetas']),
      checkCfdi: _integer(map['cfdi_cheques']),
      transferCfdi: _integer(map['cfdi_transferencia']),
      otherCfdi: _integer(map['cfdi_otros']),
      merchandiseLosses: _decimal(map['bajas_mercancia']),
      initialCashAmount: _decimal(map['monto_inicial_caja']),
      notes: map['observaciones']?.toString(),
      guid: map['guid']?.toString() ?? '',
    );
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static int? _nullableInteger(Object? value) =>
      value == null ? null : _integer(value);
  static double _decimal(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
