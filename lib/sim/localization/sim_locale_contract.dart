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

class SimLocaleContract {
  const SimLocaleContract({
    required this.interfaceLocale,
    required this.learningLocale,
    required this.explanationLanguage,
    this.targetLanguage,
  });

  final String interfaceLocale;
  final String learningLocale;
  final String explanationLanguage;
  final String? targetLanguage;

  Map<String, dynamic> toJson() => {
    'interfaceLocale': interfaceLocale,
    'learningLocale': learningLocale,
    'explanationLanguage': explanationLanguage,
    if (targetLanguage != null && targetLanguage!.trim().isNotEmpty)
      'targetLanguage': targetLanguage,
  };
}

class SimLocaleSettings {
  const SimLocaleSettings({
    this.followDeviceInterface = true,
    this.manualInterfaceLocale,
    this.learningLocale = simDefaultLearningLocaleTag,
    this.targetLanguage,
  });

  static const interfaceModePrefsKey = 'sim.locale.interface.mode';
  static const interfaceLocalePrefsKey = 'sim.locale.interface.locale';
  static const learningLocalePrefsKey = 'sim.locale.learning.locale';
  static const targetLanguagePrefsKey = 'sim.locale.learning.target';

  final bool followDeviceInterface;
  final String? manualInterfaceLocale;
  final String learningLocale;
  final String? targetLanguage;

  String resolveInterfaceLocale([Locale? deviceLocale]) {
    if (!followDeviceInterface) {
      return normalizeSimLocaleTag(manualInterfaceLocale);
    }
    return normalizeSimLocaleTag(_deviceLocaleTag(deviceLocale));
  }

  SimLocaleContract contract([Locale? deviceLocale]) {
    final learning = normalizeSimLocaleTag(learningLocale);
    return SimLocaleContract(
      interfaceLocale: resolveInterfaceLocale(deviceLocale),
      learningLocale: learning,
      explanationLanguage: simLanguageNameForLocale(learning),
      targetLanguage: targetLanguage?.trim().isEmpty ?? true
          ? null
          : normalizeSimTargetLanguage(targetLanguage),
    );
  }

  SimLocaleSettings copyWith({
    bool? followDeviceInterface,
    String? manualInterfaceLocale,
    String? learningLocale,
    String? targetLanguage,
  }) {
    return SimLocaleSettings(
      followDeviceInterface:
          followDeviceInterface ?? this.followDeviceInterface,
      manualInterfaceLocale:
          manualInterfaceLocale ?? this.manualInterfaceLocale,
      learningLocale: learningLocale ?? this.learningLocale,
      targetLanguage: targetLanguage ?? this.targetLanguage,
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
