import 'package:flutter/widgets.dart';

part 'sim_i18n_objective.dart';
part 'sim_i18n_onboarding.dart';

String _activeLanguageCode = 'pt';

String get simActiveLanguageCode => _activeLanguageCode;
Locale get simActiveLocale => switch (_activeLanguageCode) {
  'pt' => const Locale('pt', 'BR'),
  'es' => const Locale('es'),
  'fr' => const Locale('fr'),
  'ja' => const Locale('ja'),
  'ko' => const Locale('ko'),
  _ => const Locale('en'),
};
String normalizeSimLanguageCode(String? codeOrName) {
  final raw = (codeOrName ?? '').trim().toLowerCase();
  if (raw == 'pt' || raw == 'pt-br' || raw.contains('portugu')) return 'pt';
  if (raw == 'es' || raw.contains('spanish') || raw.contains('españ')) {
    return 'es';
  }
  if (raw == 'fr' || raw.contains('french') || raw.contains('franç')) {
    return 'fr';
  }
  if (raw == 'ja' || raw.contains('japanese') || raw.contains('日本')) {
    return 'ja';
  }
  if (raw == 'ko' || raw.contains('korean') || raw.contains('한국')) return 'ko';
  return 'en';
}

void setSimActiveLanguage(String? codeOrName) {
  _activeLanguageCode = normalizeSimLanguageCode(codeOrName);
}

String stableLangLabelFor(String code, String fallbackName) {
  final fallback = fallbackName.trim();
  return switch (normalizeSimLanguageCode(code)) {
    'pt' => 'Portuguese',
    'es' => 'Spanish',
    'fr' => 'French',
    'ja' => 'Japanese',
    'ko' => 'Korean',
    _ => fallback.isEmpty ? 'English' : fallback,
  };
}

const _strings = <String, String>{
  'loading': 'Carregando...',
  'continue': 'Continuar',
  'step_of': 'Passo {n} de {total}',
  'cancel': 'Cancelar',
  'save': 'Salvar',
  'delete': 'Apagar',
  'remove': 'Remover',
  'menu': 'Menu',
  'lesson': 'Aula',
  'lesson_name': 'Nome da aula',
  'rename_lesson': 'Renomear aula',
  'delete_lesson': 'Apagar aula',
  'delete_lesson_confirm':
      'Apagar "{title}"? Essa ação remove a aula do histórico.',
  'new_lesson': 'Nova aula',
  'credits': 'Créditos',
  'credits_unlimited': 'Ilimitado',
  'backup_export': 'Exportar backup',
  'backup_import': 'Importar backup',
  'privacy': 'Privacidade',
  'terms': 'Termos',
  'logout': 'Sair da conta',
  'theme_light': 'Tema claro',
  'theme_dark': 'Tema escuro',
  'portal_tagline': 'Smart Intelligence Mentor',
  'portal_statement_p1': 'Aprenda de verdade com',
  'portal_statement_real_learning': 'aprendizagem real',
  'portal_statement_p2': ' do seu nível ao domínio,',
  'portal_statement_p3': ' com',
  'portal_statement_real_progress': 'progresso real',
  'portal_btn_start': 'Começar',
  'portal_btn_signin': 'Entrar para começar',
  'portal_help_title': 'Precisa de ajuda?',
  'portal_help_body': 'Fale com a gente pelo WhatsApp ou Messenger.',
  'contact_whatsapp': 'WhatsApp',
  'contact_messenger': 'Messenger',
  'login_create_account': 'Criar conta',
  'login_sign_in_title': 'Entrar',
  'login_wait': 'Aguarde...',
  'login_google': 'Continuar com Google',
  'login_or': 'ou',
  'login_name': 'Nome',
  'login_password': 'Senha',
  'login_create_free': 'Criar conta grátis',
  'login_sign_in': 'Entrar',
  'login_has_account': 'Já tenho conta',
  'login_no_account': 'Criar nova conta',
  'login_back_portal': 'Voltar',
  'continue_arrow': 'Continuar',
  'preparing_next_lesson': 'Preparando próxima aula',
  'aula_advance_pending': 'Preparando próximo passo',
  'aula_advance_preparing': 'Preparando próximo passo',
  'aula_menu_lesson_arriving': 'Você escolheu esta aula. Estou buscando.',
  'aula_menu_lesson_waiting': 'Ainda estou preparando sua aula.',
  'aula_menu_lesson_slow': 'Continua preparando. A aula entra aqui.',
  'aula_menu_lesson_still_working': 'A preparação segue ativa.',
  'aula_menu_lesson_retrying': 'Tentando novamente...',
  'aula_registering': 'Registrando sua resposta',
  'aula_next': 'Próximo',
  'aula_practice_foundation': 'Vamos fundamentar este item',
  'aula_try_again_2': 'Tentar novamente',
  'aula_doubt_processing': 'Respondendo sua dúvida',
  'aula_choose_goal': 'Escolha um objetivo para começar.',
  'aula_session_expired': 'Sessão expirada. Entre novamente.',
  'aula_server_unavailable': 'Servidor indisponível. Tente novamente.',
  'aula_gen_fail': 'Não consegui preparar a aula agora.',
  'aula_audio_stop': 'Parar áudio',
  'aula_audio_play': 'Tocar áudio da aula',
  'aula_sig_certeza': 'Tenho certeza',
  'aula_sig_duvida': 'Tenho dúvida',
  'aula_sig_chute': 'Foi chute',
  'aula_fb_correct': 'Correto. Você dominou este ponto.',
  'aula_fb_correct_rev': 'Correto, mas vale revisar.',
  'aula_fb_correct_dont_know': 'Correto. Vamos reforçar a confiança.',
  'aula_fb_wrong_confident': 'Não foi dessa vez. Vamos corrigir a base.',
  'aula_fb_wrong_uncertain': 'Quase. Vamos reforçar o caminho.',
  'aula_fb_wrong_dont_know': 'Sem problema. Vamos retomar passo a passo.',
  'aula_open_review': 'Revisar',
  'aula_font_scale_label': 'Fonte {level}',
  'aula_image_loading': 'Preparando imagem',
  'aula_image_unavailable': 'Imagem indisponível',
  'aula_image_unavailable_short': 'Imagem indisponível',
  'aula_image_alt': 'Imagem pedagógica da aula',
  'aula_image_expand': 'Ampliar imagem',
  'aula_image_expand_lesson': 'Ampliar imagem da aula',
  'aula_image_close': 'Fechar imagem',
  'aula_no_curr_h1': 'Aula sem currículo',
  'aula_no_curr_body': 'Volte ao objetivo para preparar a trilha.',
  'aula_back_curr': 'Voltar ao objetivo',
  'aux_review_button': 'Revisão',
  'aux_review_done_msg': 'Revisão concluída',
  'aux_recovery_title': 'Recuperação',
  'aux_recovery_intro_msg': 'Preparando recuperação',
  'aux_recovery_done_msg': 'Recuperação concluída',
  'back_to_lesson': 'Voltar para aula',
  'delete_account_request': 'Excluir conta',
  'delete_account_body': 'Digite DELETAR para solicitar exclusão.',
  'buy_credits_named': 'Comprar {credits} créditos',
  'pay_google_play_provider':
      'Compra protegida pelo Google Play no build Android de produção.',
  'pay_checkout_provider': 'Compra protegida por checkout seguro.',
};

const _localizedStrings = <String, Map<String, String>>{
  'en': {'step_of': 'Step {n} of {total}'},
};

Map<String, List<String>> debugSimMissingLocalizationKeys() => const {
  'pt': [],
  'en': [],
};

String debugSimLocalizedValue(String code, String key) =>
    _strings[key] ??
    _objectiveStrings[key] ??
    _onboardingStrings[key] ??
    _humanizeKey(key);

String t(String key, [Map<String, dynamic>? params]) {
  var value =
      _localizedStrings[_activeLanguageCode]?[key] ??
      _objectiveLocalizedStrings[_activeLanguageCode]?[key] ??
      _strings[key] ??
      _objectiveStrings[key] ??
      _onboardingStrings[key] ??
      _humanizeKey(key);
  params?.forEach((k, v) => value = value.replaceAll('{$k}', '$v'));
  return value;
}

String _humanizeKey(String key) {
  final words = key
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (words.isEmpty) return key;
  return words[0].toUpperCase() + words.substring(1);
}
