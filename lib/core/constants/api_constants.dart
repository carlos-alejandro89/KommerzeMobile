class ApiConstants {
  ApiConstants._();

  static const baseUrl = 'https://kommerze-cloud-api.developers-lab.com';
  static const loginPath = '/auth/login';
  static const licenseActivationPath = '/api/v1/licencias/activacion';
  static const paymentFormsPath = '/catalogos/sat/formas-pago/get';
  static const paymentMethodsPath = '/catalogos/sat/metodos-pago/get';
  static const profilesPath = '/catalogos/perfiles/get';
  static const orderTypesPath = '/catalogos/tipos-pedido/get';
  static const statusesPath = '/catalogos/estatus/get';
  static const clientsListPath = '/clientes/listar';
  static const usersPath = '/catalogos/usuarios/get';
  static const salesRegisterPath = '/pedidos/registrar';
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);
}
