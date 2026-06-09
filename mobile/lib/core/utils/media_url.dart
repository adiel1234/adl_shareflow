import '../config/app_config.dart';

/// Resolves relative upload paths from the API to absolute URLs.
String resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final origin = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api$'), '');
  final path = url.startsWith('/') ? url : '/$url';
  return '$origin$path';
}
