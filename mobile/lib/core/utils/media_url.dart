import '../config/app_config.dart';

/// Resolves relative upload paths from the API to absolute URLs.
String resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';

  var resolved = url;
  if (resolved.contains('/api/uploads/')) {
    resolved = resolved.replaceFirst('/api/uploads/', '/uploads/');
  }

  if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
    return resolved;
  }

  var origin = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  if (origin.endsWith('/api')) {
    origin = origin.substring(0, origin.length - 4);
  }
  final path = resolved.startsWith('/') ? resolved : '/$resolved';
  return '$origin$path';
}
