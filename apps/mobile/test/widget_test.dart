import 'package:flutter_test/flutter_test.dart';
import 'package:teriyascore/core/api/config.dart';

void main() {
  test('resolveApiBase defaults to TeriyaScore cloud API', () {
    expect(resolveApiBase(), kCloudApiBase);
  });
}
