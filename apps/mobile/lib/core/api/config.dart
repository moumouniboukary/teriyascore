import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.body});

  final String message;
  final int status;
  final dynamic body;

  bool get isOffline => status == 0;
  bool get isServerError => status >= 500;

  @override
  String toString() => message;
}

/// API cloud TeriyaScore (DigiCoop) — jamais NeoForma.
const String kCloudApiBase = 'https://teriyascore-api.onrender.com';

/// Local uniquement : `--dart-define=API_BASE=http://10.0.2.2:3001`
String resolveApiBase() {
  const fromEnv = String.fromEnvironment('API_BASE');
  final base = fromEnv.replaceAll(RegExp(r'/$'), '');
  if (_isLocalDevApi(base)) return base;
  if (base.contains('neoforma')) return kCloudApiBase;
  if (base.startsWith('https://') && base.contains('teriyascore')) return base;
  return kCloudApiBase;
}

bool _isLocalDevApi(String base) {
  if (base.isEmpty || !base.startsWith('http://')) return false;
  final host = Uri.tryParse(base)?.host ?? '';
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (host.startsWith('10.')) return true;
  if (host.startsWith('192.168.')) return true;
  return false;
}
