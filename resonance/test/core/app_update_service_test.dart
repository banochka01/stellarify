import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/update/app_update_service.dart';

void main() {
  test('compares semantic client versions numerically', () {
    expect(compareVersions('0.1.8', '0.1.7'), 1);
    expect(compareVersions('1.0.0', '1.0'), 0);
    expect(compareVersions('0.1.7', '0.2.0'), -1);
  });
}
