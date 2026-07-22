import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

const List<String> simSupportedLocaleTags = [
  'pt-BR',
  'en',
  'es',
  'fr',
  'de',
  'it',
];
const String simDefaultInterfaceLocaleTag = 'pt-BR';
const String simDefaultLearningLocaleTag = 'pt-BR';
const int simLocaleContractVersion = 1;

enum SimLocaleSource {
  userSelected,
  userSelectedSingleLanguage,
  migrated,
  fallback,
  systemDefault,
}

String _sourceName(SimLocaleSource source) => switch (source) {
  SimLocaleSource.userSelected => 'user_selected',
  SimLocaleSource.userSelectedSingleLanguage => 'user_selected_single_language',
  SimLocaleSource.migrated => 'migrated',
  SimLocaleSource.fallback => 'fallback',
  SimLocaleSource.systemDefault => 'system_default',
};

SimLocaleSource _sourceFromName(Object? raw) {
  final value = (raw ?? '').toString().trim();
  return SimLocaleSource.values.firstWhere(
    (source) => _sourceName(source) == value,
    orElse: () => SimLocaleSource.fallback,
  );
}

class SimLocaleContract {
  const SimLocaleContract({
    required this.interfaceLocale,
    required this.learningLocale,
    required this.explanationLanguage,
    required this.mediaTextLanguage,
    required this.source,
    this.version = simLocaleContractVersion,
    this.targetLanguage,
  });

  final String interfaceLocale;
  final String learningLocale;
  final String explanationLanguage;
  final String mediaTextLanguage;
  final SimLocaleSource source;
  final int version;
  final String? targetLanguage;

  Map<String, dynamic> toJson() => {
    'version': version,
    'interfaceLocale': interfaceLocale,
    'learningLocale': learningLocale,
    'explanationLanguage': explanationLanguage,
    'mediaTextLanguage': mediaTextLanguage,
    'source': _sourceName(source),
    if (targetLanguage != null && targetLanguage!.trim().isNotEmpty)
      'targetLanguage': targetLanguage,
  };

  factory SimLocaleContract.fromUserSelection({
    required String interfaceLocale,
    required String learningLocale,
    String? explanationLanguage,
    String? targetLanguage,
    String? mediaTextLanguage,
    SimLocaleSource source = SimLocaleSource.userSelected,
  }) {
    final rawLearning = learningLocale.trim();
    final learningKnown = isSupportedSimLocale(rawLearning);
    final learning = normalizeSimLocaleTag(learningLocale);
    final explicitExplanation = normalizeSimTargetLanguage(explanationLanguage);
    final explanation = explicitExplanation.trim().isEmpty
        ? learningKnown
              ? simLanguageNameForLocale(learning)
              : rawLearning
        : explicitExplanation;
    final explicitTarget = normalizeNullableTargetLanguage(targetLanguage);
    return SimLocaleContract(
      interfaceLocale: normalizeSimLocaleTag(interfaceLocale),
      learningLocale: learning,
      explanationLanguage: explanation,
      targetLanguage:
          explicitTarget ??
          (learningKnown ? null : normalizeSimTargetLanguage(rawLearning)),
      mediaTextLanguage: normalizeSimTargetLanguage(
        mediaTextLanguage?.trim().isNotEmpty == true
            ? mediaTextLanguage
            : explanation,
      ),
      source: source,
    ).normalized();
  }

  factory SimLocaleContract.fromLegacyState(Map<String, dynamic> json) {
    final direct = json['localeContract'];
    if (direct is Map) {
      return SimLocaleContract.fromJson(
        direct.map((key, value) => MapEntry(key.toString(), value)),
      ).copyWith(source: SimLocaleSource.migrated).normalized();
    }
    final profile = json['profile'] is Map
        ? (json['profile'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          )
        : const <String, dynamic>{};
    final extra = {
      ...json,
      ...profile,
      if (profile['extra'] is Map)
        ...(profile['extra'] as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
    };
    final learning =
        extra['learningLocale'] ??
        extra['lesson_locale'] ??
        extra['language'] ??
        extra['idioma'] ??
        extra['stableLang'];
    final explanation =
        extra['explanationLanguage'] ??
        extra['stable_lang'] ??
        extra['stableLang'] ??
        extra['STABLE_LANG'] ??
        extra['idioma'] ??
        extra['language'];
    final interfaceLocale =
        extra['interfaceLocale'] ?? extra['app_locale'] ?? learning;
    final target = extra['targetLanguage'] ?? extra['target_language'];
    if (interfaceLocale == null && learning == null && explanation == null) {
      return fallbackForDevelopment();
    }
    return SimLocaleContract.fromUserSelection(
      interfaceLocale:
          interfaceLocale?.toString() ?? simDefaultInterfaceLocaleTag,
      learningLocale: learning?.toString() ?? simDefaultLearningLocaleTag,
      explanationLanguage: explanation?.toString(),
      targetLanguage: target?.toString(),
      mediaTextLanguage: extra['mediaTextLanguage']?.toString(),
      source: SimLocaleSource.migrated,
    );
  }

  factory SimLocaleContract.fromJson(Map<String, dynamic> json) {
    return SimLocaleContract(
      version: (json['version'] as num?)?.toInt() ?? simLocaleContractVersion,
      interfaceLocale: normalizeSimLocaleTag(
        json['interfaceLocale']?.toString(),
      ),
      learningLocale: normalizeSimLocaleTag(json['learningLocale']?.toString()),
      explanationLanguage: normalizeSimTargetLanguage(
        json['explanationLanguage']?.toString(),
      ),
      targetLanguage: normalizeNullableTargetLanguage(
        json['targetLanguage']?.toString(),
      ),
      mediaTextLanguage: normalizeSimTargetLanguage(
        json['mediaTextLanguage']?.toString(),
      ),
      source: _sourceFromName(json['source']),
    ).normalized();
  }

  static SimLocaleContract fallbackForDevelopment() => SimLocaleContract(
    interfaceLocale: simDefaultInterfaceLocaleTag,
    learningLocale: simDefaultLearningLocaleTag,
    explanationLanguage: simLanguageNameForLocale(simDefaultLearningLocaleTag),
    mediaTextLanguage: simLanguageNameForLocale(simDefaultLearningLocaleTag),
    source: SimLocaleSource.fallback,
  );

  SimLocaleContract copyWith({
    String? interfaceLocale,
    String? learningLocale,
    String? explanationLanguage,
    String? targetLanguage,
    String? mediaTextLanguage,
    SimLocaleSource? source,
    int? version,
  }) {
    return SimLocaleContract(
      interfaceLocale: interfaceLocale ?? this.interfaceLocale,
      learningLocale: learningLocale ?? this.learningLocale,
      explanationLanguage: explanationLanguage ?? this.explanationLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      mediaTextLanguage: mediaTextLanguage ?? this.mediaTextLanguage,
      source: source ?? this.source,
      version: version ?? this.version,
    );
  }

  SimLocaleContract normalized() {
    final learning = normalizeSimLocaleTag(learningLocale);
    final explanation = normalizeSimTargetLanguage(explanationLanguage);
    final cleanExplanation = explanation.trim().isEmpty
        ? simLanguageNameForLocale(learning)
        : explanation;
    final media = normalizeSimTargetLanguage(mediaTextLanguage);
    return SimLocaleContract(
      interfaceLocale: normalizeSimLocaleTag(interfaceLocale),
      learningLocale: learning,
      explanationLanguage: cleanExplanation,
      targetLanguage: normalizeNullableTargetLanguage(targetLanguage),
      mediaTextLanguage: media.trim().isEmpty ? cleanExplanation : media,
      source: source,
      version: version <= 0 ? simLocaleContractVersion : version,
    );
  }

  String cacheIdentity() => [
    'locale',
    'v$version',
    learningLocale,
    explanationLanguage,
    targetLanguage ?? '-',
  ].join(':');

  String mediaIdentity({
    String? mediaTextLanguage,
    String? audioLanguage,
    String? voice,
    double? speed,
    String? textHash,
    String? visualTextPolicy,
    String? sourceVersion,
  }) => [
    'media-locale',
    'v$version',
    interfaceLocale,
    learningLocale,
    explanationLanguage,
    normalizeSimTargetLanguage(mediaTextLanguage ?? this.mediaTextLanguage),
    normalizeSimTargetLanguage(audioLanguage),
    targetLanguage ?? '-',
    (voice ?? '-').trim(),
    speed == null ? '-' : speed.toStringAsFixed(2),
    (textHash ?? '-').trim(),
    (visualTextPolicy ?? '-').trim(),
    (sourceVersion ?? '-').trim(),
  ].join(':');

  bool isCompatibleWith(SimLocaleContract other) {
    final a = normalized();
    final b = other.normalized();
    return a.learningLocale == b.learningLocale &&
        a.explanationLanguage == b.explanationLanguage &&
        a.targetLanguage == b.targetLanguage &&
        a.mediaTextLanguage == b.mediaTextLanguage;
  }

  String debugSummary() =>
      'interface=$interfaceLocale learning=$learningLocale explanation=$explanationLanguage target=${targetLanguage ?? '-'} media=$mediaTextLanguage source=${_sourceName(source)} v$version';
}

class SimLocaleSettings {
  const SimLocaleSettings({
    this.followDeviceInterface = true,
    this.manualInterfaceLocale,
    this.learningLocale = simDefaultLearningLocaleTag,
    this.targetLanguage,
    this.source = SimLocaleSource.systemDefault,
  });

  static const interfaceModePrefsKey = 'sim.locale.interface.mode';
  static const interfaceLocalePrefsKey = 'sim.locale.interface.locale';
  static const learningLocalePrefsKey = 'sim.locale.learning.locale';
  static const targetLanguagePrefsKey = 'sim.locale.learning.target';
  static const sourcePrefsKey = 'sim.locale.contract.source';

  final bool followDeviceInterface;
  final String? manualInterfaceLocale;
  final String learningLocale;
  final String? targetLanguage;
  final SimLocaleSource source;

  String resolveInterfaceLocale([Locale? deviceLocale]) {
    if (!followDeviceInterface) {
      return normalizeSimLocaleTag(manualInterfaceLocale);
    }
    return normalizeSimLocaleTag(_deviceLocaleTag(deviceLocale));
  }

  SimLocaleContract contract([Locale? deviceLocale]) {
    final learning = normalizeSimLocaleTag(learningLocale);
    return SimLocaleContract.fromUserSelection(
      interfaceLocale: resolveInterfaceLocale(deviceLocale),
      learningLocale: learning,
      explanationLanguage: simLanguageNameForLocale(learning),
      targetLanguage: targetLanguage?.trim().isEmpty ?? true
          ? null
          : normalizeSimTargetLanguage(targetLanguage),
      source: source,
    );
  }

  SimLocaleSettings copyWith({
    bool? followDeviceInterface,
    String? manualInterfaceLocale,
    String? learningLocale,
    String? targetLanguage,
    SimLocaleSource? source,
  }) {
    return SimLocaleSettings(
      followDeviceInterface:
          followDeviceInterface ?? this.followDeviceInterface,
      manualInterfaceLocale:
          manualInterfaceLocale ?? this.manualInterfaceLocale,
      learningLocale: learningLocale ?? this.learningLocale,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      source: source ?? this.source,
    );
  }

  static SimLocaleSettings load(SharedPreferences? prefs) {
    if (prefs == null) return const SimLocaleSettings();
    final mode = prefs.getString(interfaceModePrefsKey);
    return SimLocaleSettings(
      followDeviceInterface: mode != 'manual',
      manualInterfaceLocale: prefs.getString(interfaceLocalePrefsKey),
      learningLocale: normalizeSimLocaleTag(
        prefs.getString(learningLocalePrefsKey),
      ),
      targetLanguage: prefs.getString(targetLanguagePrefsKey),
      source: _sourceFromName(prefs.getString(sourcePrefsKey)),
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(
      interfaceModePrefsKey,
      followDeviceInterface ? 'system' : 'manual',
    );
    if (manualInterfaceLocale == null || manualInterfaceLocale!.isEmpty) {
      await prefs.remove(interfaceLocalePrefsKey);
    } else {
      await prefs.setString(
        interfaceLocalePrefsKey,
        normalizeSimLocaleTag(manualInterfaceLocale),
      );
    }
    await prefs.setString(
      learningLocalePrefsKey,
      normalizeSimLocaleTag(learningLocale),
    );
    if (targetLanguage == null || targetLanguage!.trim().isEmpty) {
      await prefs.remove(targetLanguagePrefsKey);
    } else {
      await prefs.setString(targetLanguagePrefsKey, targetLanguage!.trim());
    }
    await prefs.setString(sourcePrefsKey, _sourceName(source));
  }
}

String normalizeSimLocaleTag(String? raw) {
  final value = (raw ?? '').trim().toLowerCase().replaceAll('_', '-');
  if (value == 'pt' ||
      value == 'pt-br' ||
      value.contains('portugu') ||
      value.contains('brasil')) {
    return 'pt-BR';
  }
  if (value == 'en' || value.startsWith('en-') || value.contains('english')) {
    return 'en';
  }
  if (value == 'es' ||
      value.startsWith('es-') ||
      value.contains('spanish') ||
      value.contains('español')) {
    return 'es';
  }
  if (value == 'fr' ||
      value.startsWith('fr-') ||
      value.contains('french') ||
      value.contains('français')) {
    return 'fr';
  }
  if (value == 'de' ||
      value.startsWith('de-') ||
      value.contains('german') ||
      value.contains('deutsch')) {
    return 'de';
  }
  if (value == 'it' ||
      value.startsWith('it-') ||
      value.contains('italian') ||
      value.contains('italiano')) {
    return 'it';
  }
  return simDefaultInterfaceLocaleTag;
}

String simLanguageNameForLocale(String? raw) {
  return switch (normalizeSimLocaleTag(raw)) {
    'en' => 'English',
    'es' => 'Spanish',
    'fr' => 'French',
    'de' => 'German',
    'it' => 'Italian',
    _ => 'Portuguese',
  };
}

String normalizeSimTargetLanguage(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  final lower = value.toLowerCase().replaceAll('_', '-');
  if (lower == 'pt' ||
      lower == 'pt-br' ||
      lower.contains('portugu') ||
      lower.contains('brasil')) {
    return 'Portuguese';
  }
  if (lower == 'en' || lower.startsWith('en-') || lower.contains('english')) {
    return 'English';
  }
  if (lower == 'es' ||
      lower.startsWith('es-') ||
      lower.contains('spanish') ||
      lower.contains('español')) {
    return 'Spanish';
  }
  if (lower == 'fr' ||
      lower.startsWith('fr-') ||
      lower.contains('french') ||
      lower.contains('français')) {
    return 'French';
  }
  if (lower == 'de' ||
      lower.startsWith('de-') ||
      lower.contains('german') ||
      lower.contains('deutsch')) {
    return 'German';
  }
  if (lower == 'it' ||
      lower.startsWith('it-') ||
      lower.contains('italian') ||
      lower.contains('italiano')) {
    return 'Italian';
  }
  return value;
}

bool isSupportedSimLocale(String? raw) {
  final value = (raw ?? '').trim().toLowerCase().replaceAll('_', '-');
  if (value.isEmpty) return false;
  return value == 'pt' ||
      value == 'pt-br' ||
      value.contains('portugu') ||
      value.contains('brasil') ||
      value == 'en' ||
      value.startsWith('en-') ||
      value.contains('english') ||
      value == 'es' ||
      value.startsWith('es-') ||
      value.contains('spanish') ||
      value.contains('español') ||
      value == 'fr' ||
      value.startsWith('fr-') ||
      value.contains('french') ||
      value.contains('français') ||
      value == 'de' ||
      value.startsWith('de-') ||
      value.contains('german') ||
      value.contains('deutsch') ||
      value == 'it' ||
      value.startsWith('it-') ||
      value.contains('italian') ||
      value.contains('italiano');
}

String? normalizeNullableTargetLanguage(String? raw) {
  final normalized = normalizeSimTargetLanguage(raw);
  return normalized.trim().isEmpty ? null : normalized;
}

String simUiCodeForLocaleTag(String? raw) {
  return switch (normalizeSimLocaleTag(raw)) {
    'en' => 'en',
    'es' => 'es',
    'fr' => 'fr',
    'de' => 'de',
    'it' => 'it',
    _ => 'pt',
  };
}

String _deviceLocaleTag(Locale? locale) {
  if (locale == null) return simDefaultInterfaceLocaleTag;
  final country = locale.countryCode;
  return country == null || country.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}-$country';
}
