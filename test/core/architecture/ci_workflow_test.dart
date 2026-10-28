import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('GitHub workflow parses with least privilege and bounded jobs', () {
    final workflow = loadYaml(
      File('.github/workflows/flutter-ci.yml').readAsStringSync(),
    ) as YamlMap;

    expect(workflow['name'], 'Flutter CI');
    expect(workflow['on'], isA<YamlMap>());
    expect(workflow['permissions'], {'contents': 'read'});
    expect((workflow['concurrency'] as YamlMap)['cancel-in-progress'], isTrue);

    final jobs = workflow['jobs'] as YamlMap;

    const timeouts = {
      'analyze-test': 30,
      'android-integration': 45,
      'ios-integration': 45,
      'android-debug': 30,
      'ios-debug': 30,
      'backend-contracts': 20,
    };
    for (final entry in timeouts.entries) {
      final job = jobs[entry.key] as YamlMap?;
      expect(job, isNotNull, reason: 'Missing ${entry.key} job');
      expect(job!['timeout-minutes'], entry.value);
      expect(job['runs-on'], isNotEmpty);
    }

    final androidIntegration = jobs['android-integration'] as YamlMap;
    final matrix = androidIntegration['strategy'] as YamlMap;
    final includes = (matrix['matrix'] as YamlMap)['include'] as YamlList;
    final providerModes = {
      for (final item in includes.cast<YamlMap>())
        item['api-level']: item['provider-mode'],
    };
    expect(providerModes, {33: 'unavailable', 35: 'available'});

    final runner = androidIntegration['steps'].cast<YamlMap>().firstWhere(
      (step) => step['name'] == 'Run integration tests on Android emulator',
    );
    final script = (runner['with'] as YamlMap)['script'] as String;
    expect(
      script,
      contains('--dart-define=VERIFY_HEALTH_CONNECT_UNAVAILABLE=true'),
    );
    expect(script, contains('--dart-define=VERIFY_HEALTH_CONNECT=true'));
  });
}
