import 'package:flutter_test/flutter_test.dart';
import 'package:teriyascore/core/api/config.dart';

void main() {
  group('ApiException', () {
    test('status 0 = hors ligne', () {
      final e = ApiException('Hors ligne', status: 0);
      expect(e.isOffline, isTrue);
      expect(e.isServerError, isFalse);
    });

    test('status >= 500 = erreur serveur (déclenche file hors ligne)', () {
      expect(ApiException('boom', status: 500).isServerError, isTrue);
      expect(ApiException('boom', status: 503).isServerError, isTrue);
      expect(ApiException('nope', status: 400).isServerError, isFalse);
    });
  });

  group('resolveApiBase', () {
    test('valeur par défaut = API cloud NeoForma', () {
      expect(resolveApiBase(), kCloudApiBase);
    });
  });
}
