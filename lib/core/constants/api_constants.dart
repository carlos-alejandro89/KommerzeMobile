class ApiConstants {
  ApiConstants._();

  static const pulsePath = 'pulse';
  static const loginPath = 'auth/login';
  static const changePasswordPath = 'auth/password';
  static const profilePicturePath = 'auth/profile/picture';
  static const licenseActivationPath = 'api/v1/licencias/activacion';
  static const paymentFormsPath = 'catalogos/sat/formas-pago/get';
  static const paymentMethodsPath = 'catalogos/sat/metodos-pago/get';
  static const profilesPath = 'catalogos/perfiles/get';
  static const orderTypesPath = 'catalogos/tipos-pedido/get';
  static const statusesPath = 'catalogos/estatus/get';
  static const clientsListPath = 'clientes/listar';
  static const usersPath = 'catalogos/usuarios/get';
  static const salesRegisterPath = 'pedidos/registrar';
  static const branchOperationStartPath = 'sucursales/operaciones/iniciar';
  static const branchOperationFinishPath = 'sucursales/operaciones/finalizar';
  static const cashierShiftStartPath = 'sucursales/cajeros/turno/iniciar';
  static const cashierShiftFinishPath = 'sucursales/cajeros/turno/finalizar';
  static String inventoryValidationPath(String branchGuid) =>
      'sucursales/inventario/validar/$branchGuid';
  static const collectionsSyncPath = 'cobranza/sincronizar';
  static String collectionsByBranchPath(String branchGuid) =>
      'cobranza/sucursal/$branchGuid';
  static const loansSyncPath = 'prestamos/sincronizar';
  static String loansByBranchPath(String branchGuid) =>
      'prestamos/sucursal/$branchGuid';
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);
}
