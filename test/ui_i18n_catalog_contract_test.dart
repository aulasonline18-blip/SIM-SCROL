import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() {
    debugSetSimStrictLocalization(false);
    debugClearSimMissingLocalizationLog();
    setSimActiveLanguage('pt-BR');
  });

  test('catalogos pt en es cobrem as chaves visiveis da L2', () {
    final missing = debugSimMissingLocalizationKeys();

    expect(missing['pt'], isEmpty);
    expect(missing['en'], isEmpty);
    expect(missing['es'], isEmpty);
    expect(() => debugAssertSimLocalizationComplete(), returnsNormally);
  });

  test('chave ausente nao vira texto humanizado silencioso', () {
    setSimActiveLanguage('en');

    expect(t('missing_l2_key'), '[missing_l2_key]');
    expect(debugSimRuntimeMissingLocalizationKeys(), ['en:missing_l2_key']);

    debugSetSimStrictLocalization(true);
    expect(() => t('another_missing_l2_key'), throwsA(isA<FlutterError>()));
  });

  test('idiomas sem catalogo pronto caem para fallback de UI auditavel', () {
    setSimActiveLanguage('fr');
    expect(simActiveLanguageCode, 'en');
    expect(simActiveLocale, const Locale('en'));
    expect(simUiFallbackLanguageCodes, containsPair('fr', 'en'));
    expect(simUiFallbackLanguageCodes, containsPair('de', 'en'));
    expect(simUiFallbackLanguageCodes, containsPair('it', 'en'));
  });

  test('valores basicos traduzem sem alterar chave tecnica', () {
    expect(debugSimLocalizedValue('en', 'aula_try_again_2'), 'Try again');
    expect(
      debugSimLocalizedValue('es', 'aula_try_again_2'),
      'Intentar de nuevo',
    );
    expect(
      debugSimLocalizedValue('es', 'objective_screen_title'),
      '¿Qué quieres estudiar?',
    );
  });
}
