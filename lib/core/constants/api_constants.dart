class ApiConstants {
  ApiConstants._();

  static const baseUrl = 'https://kommerze-cloud-api.developers-lab.com';
  static const loginPath = '/auth/login';
  static const licenseActivationPath = '/api/v1/licencias/activacion';
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);
}
