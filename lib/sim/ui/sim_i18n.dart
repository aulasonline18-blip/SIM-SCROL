import 'package:flutter/widgets.dart';

import '../localization/sim_locale_contract.dart';

part 'sim_i18n_objective.dart';
part 'sim_i18n_onboarding.dart';
part 'sim_i18n_core_strings.dart';

String _activeLanguageCode = 'pt';
bool _debugStrictMissingLocalization = false;
final Set<String> _debugMissingLocalizationKeys = <String>{};

const List<String> simReadyUiLanguageCodes = ['pt', 'en', 'es'];
const Map<String, String> simUiFallbackLanguageCodes = {
  'fr': 'en',
  'de': 'en',
  'it': 'en',
};

String get simActiveLanguageCode => _activeLanguageCode;
Locale get simActiveLocale => switch (_activeLanguageCode) {
  'pt' => const Locale('pt', 'BR'),
  'es' => const Locale('es'),
  _ => const Locale('en'),
};
String normalizeSimLanguageCode(String? codeOrName) {
  final code = simUiCodeForLocaleTag(normalizeSimLocaleTag(codeOrName));
  if (simReadyUiLanguageCodes.contains(code)) return code;
  return simUiFallbackLanguageCodes[code] ?? 'en';
}

void setSimActiveLanguage(String? codeOrName) {
  _activeLanguageCode = normalizeSimLanguageCode(codeOrName);
}

String stableLangLabelFor(String code, String fallbackName) {
  final fallback = fallbackName.trim();
  if (code == 'other' && fallback.isNotEmpty) return fallback;
  return simLanguageNameForLocale(code);
}

Map<String, List<String>> debugSimMissingLocalizationKeys({
  Iterable<String> locales = simReadyUiLanguageCodes,
}) {
  final base = _baseLocalizationKeys();
  return {
    for (final locale in locales)
      normalizeSimLanguageCode(locale): _missingKeysFor(
        normalizeSimLanguageCode(locale),
        base,
      ).toList()..sort(),
  };
}

Map<String, Object> debugSimLocalizationCoverage({
  Iterable<String> locales = simReadyUiLanguageCodes,
}) {
  final base = _baseLocalizationKeys();
  return {
    'baseKeyCount': base.length,
    'readyLocales': simReadyUiLanguageCodes,
    'fallbackLocales': simUiFallbackLanguageCodes,
    'missing': debugSimMissingLocalizationKeys(locales: locales),
    'runtimeMissing': _debugMissingLocalizationKeys.toList()..sort(),
  };
}

void debugAssertSimLocalizationComplete({
  Iterable<String> locales = simReadyUiLanguageCodes,
}) {
  final missing = debugSimMissingLocalizationKeys(locales: locales);
  final failures = missing.entries
      .where((entry) => entry.value.isNotEmpty)
      .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
      .join('\n');
  if (failures.isNotEmpty) {
    throw FlutterError('Missing SIM localization keys:\n$failures');
  }
}

void debugSetSimStrictLocalization(bool value) {
  _debugStrictMissingLocalization = value;
}

void debugClearSimMissingLocalizationLog() {
  _debugMissingLocalizationKeys.clear();
}

List<String> debugSimRuntimeMissingLocalizationKeys() =>
    _debugMissingLocalizationKeys.toList()..sort();

Set<String> _baseLocalizationKeys() => {
  ..._strings.keys,
  ..._objectiveStrings.keys,
  ..._onboardingStrings.keys,
};

bool debugSimHasLocalizationKey(String key) =>
    _baseLocalizationKeys().contains(key);

Iterable<String> _missingKeysFor(String locale, Set<String> base) sync* {
  if (locale == 'pt') return;
  final localized = {
    if (_localizedStrings[locale] != null) ..._localizedStrings[locale]!.keys,
    if (_objectiveLocalizedStrings[locale] != null)
      ..._objectiveLocalizedStrings[locale]!.keys,
    if (_onboardingLocalizedStrings[locale] != null)
      ..._onboardingLocalizedStrings[locale]!.keys,
  };
  for (final key in base) {
    if (!localized.contains(key)) yield key;
  }
}

String debugSimLocalizedValue(String code, String key) =>
    _localizedValue(normalizeSimLanguageCode(code), key) ??
    _missingLocalizationValue(key);

String t(String key, [Map<String, dynamic>? params]) {
  var value =
      _localizedValue(_activeLanguageCode, key) ??
      _missingLocalizationValue(key);
  params?.forEach((k, v) => value = value.replaceAll('{$k}', '$v'));
  return value;
}

String? _localizedValue(String locale, String key) {
  if (locale == 'pt') {
    return _strings[key] ?? _objectiveStrings[key] ?? _onboardingStrings[key];
  }
  return _localizedStrings[locale]?[key] ??
      _objectiveLocalizedStrings[locale]?[key] ??
      _onboardingLocalizedStrings[locale]?[key];
}

String _missingLocalizationValue(String key) {
  _debugMissingLocalizationKeys.add('$simActiveLanguageCode:$key');
  if (_debugStrictMissingLocalization) {
    throw FlutterError(
      'Missing SIM localization key "$key" for "$simActiveLanguageCode".',
    );
  }
  return '[$key]';
}
