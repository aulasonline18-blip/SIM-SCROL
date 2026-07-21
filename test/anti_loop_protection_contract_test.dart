import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lei anti-loop existe e declara protecao constitucional', () {
    final law = File(
      'docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md',
    ).readAsStringSync();

    expect(law, contains('Codigo: LPTAL-1'));
    expect(law, contains('tao protegidas quanto prompts, T00, T02 e contrato N3'));
    expect(law, contains('anti-loop-protection'));
    expect(law, contains('AUDIO_ALREADY_RUNNING'));
    expect(law, contains('DOPAMINE_WINDOW_REQUEST_CAPPED'));
    expect(law, contains('.data/ai-usage-daily.json'));
  });

  test('travas anti-loop do app continuam presentes', () {
    final dopamine = File(
      'lib/sim/lesson/dopamine_ready_window_engine.dart',
    ).readAsStringSync();
    final media = File(
      'lib/sim/media/student_lesson_media_service.dart',
    ).readAsStringSync();
    final readyWindowTest = File(
      'test/first_lesson_ready_window_test.dart',
    ).readAsStringSync();

    expect(dopamine, contains('const int offlineWarmCacheSize = 15'));
    expect(dopamine, contains('const int localLessonTraySize = offlineWarmCacheSize'));
    expect(dopamine, contains('DOPAMINE_WINDOW_REQUEST_CAPPED'));
    expect(dopamine, contains('_boundedWindowLimit'));
    expect(dopamine, contains('_slotMediaAlreadyRequested'));
    expect(dopamine, contains('status != \'queued\' && status != \'running\''));
    expect(dopamine, contains('mediaType'));
    expect(media, contains('mediaType: SlotMediaType.audio'));
    expect(readyWindowTest, contains('maxSlots: 50'));
    expect(readyWindowTest, contains('DOPAMINE_WINDOW_REQUEST_CAPPED'));
    expect(readyWindowTest, contains('expect(t02.calls, localLessonTraySize)'));
  });

  test('travas anti-loop do servidor continuam presentes', () {
    final audio = File(
      '/root/sim-work/sim-api/src/media/audio-controller.js',
    ).readAsStringSync();
    final router = File('/root/sim-work/sim-api/src/app/router.js')
        .readAsStringSync();
    final manifest = File(
      '/root/sim-work/sim-api/docs/migracao-sim-nv/protected-files.manifest.json',
    ).readAsStringSync();
    final serverTest = File(
      '/root/sim-work/sim-api/test/media_visual_n3_contract.test.js',
    ).readAsStringSync();

    expect(audio, contains('AUDIO_ALREADY_RUNNING'));
    expect(audio, contains("status === 'running'"));
    expect(router, contains('ai-usage-daily.json'));
    expect(router, contains('recordAiUsageDaily'));
    expect(router, contains('routeClass === \'audio\''));
    expect(manifest, contains('"id": "anti-loop-protection"'));
    expect(manifest, contains('/root/SIM-SCROL/lib/sim/lesson/dopamine_ready_window_engine.dart'));
    expect(serverTest, contains('AUDIO_ALREADY_RUNNING'));
  });
}
