class UrlBuilder {
  const UrlBuilder._();

  static String withTrailingSlash(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return normalized.isEmpty ? '' : '$normalized/';
  }

  static String join(String baseUrl, String path) {
    final trimmedPath = path
        .trim()
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^~/+'), '');
    if (trimmedPath.startsWith('http://') ||
        trimmedPath.startsWith('https://')) {
      return trimmedPath;
    }
    if (trimmedPath.startsWith('//')) {
      final scheme = Uri.tryParse(baseUrl)?.scheme;
      return '${scheme == 'http' ? 'http' : 'https'}:$trimmedPath';
    }
    final base = withTrailingSlash(baseUrl);
    if (base.isEmpty) return '';
    return '$base${trimmedPath.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
