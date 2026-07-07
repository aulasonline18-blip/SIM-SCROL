import 'sim_school_routes.dart';
import '../ui/sim_i18n.dart';

enum SimDoorKind {
  navigation,
  action,
  serverCall,
  externalLink,
  stateWrite,
  modal,
}

class SimSchoolDoor {
  const SimSchoolDoor({
    required this.id,
    required this.kind,
    this.destination,
    this.calls = const [],
    this.writes = const [],
    this.requiresAuth = false,
    this.serverOnly = false,
  });

  final String id;
  final SimDoorKind kind;
  final String? destination;
  final List<String> calls;
  final List<String> writes;
  final bool requiresAuth;
  final bool serverOnly;

  String get label => t('school_door_$id');
}

class SimSchoolEnvironment {
  const SimSchoolEnvironment({
    required this.id,
    required this.name,
    required this.route,
    required this.purpose,
    required this.doors,
    this.live = true,
  });

  final String id;
  final String name;
  final String route;
  final String purpose;
  final List<SimSchoolDoor> doors;
  final bool live;
}

const simSchoolEnvironments = <SimSchoolEnvironment>[
  SimSchoolEnvironment(
    id: 'portal',
    name: 'Entrada',
    route: '/',
    purpose:
        'Primeiro ambiente: início, créditos, menu e contato com desenvolvedores.',
    doors: [
      SimSchoolDoor(id: 'portal_menu', kind: SimDoorKind.modal),
      SimSchoolDoor(
        id: 'portal_credits',
        kind: SimDoorKind.navigation,
        destination: '/creditos',
      ),
      SimSchoolDoor(
        id: 'portal_login',
        kind: SimDoorKind.navigation,
        destination: '/login',
      ),
      SimSchoolDoor(
        id: 'portal_start',
        kind: SimDoorKind.navigation,
        destination: '/cyber/idioma',
        requiresAuth: true,
      ),
      SimSchoolDoor(
        id: 'portal_whatsapp',
        kind: SimDoorKind.externalLink,
        destination: 'https://wa.me/message/RLCYEXAYFUIIA1',
      ),
      SimSchoolDoor(
        id: 'portal_messenger',
        kind: SimDoorKind.externalLink,
        destination: 'https://m.me/61557707493807',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'login',
    name: 'Identificação',
    route: '/login',
    purpose: 'Autentica o aluno com Google/Supabase e devolve ao returnTo.',
    doors: [
      SimSchoolDoor(
        id: 'login_google',
        kind: SimDoorKind.serverCall,
        calls: ['supabase.auth.signInWithOAuth'],
      ),
      SimSchoolDoor(
        id: 'login_home',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
      SimSchoolDoor(
        id: 'login_privacy',
        kind: SimDoorKind.navigation,
        destination: '/privacidade',
      ),
      SimSchoolDoor(
        id: 'login_terms',
        kind: SimDoorKind.navigation,
        destination: '/termos',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'language',
    name: 'Idioma',
    route: '/cyber/idioma',
    purpose:
        'Define stableLang, idioma, STABLE_LANG e language para app, aula, imagem e áudio.',
    doors: [
      SimSchoolDoor(
        id: 'language_known',
        kind: SimDoorKind.stateWrite,
        destination: '/cyber/objeto',
        writes: ['StudentProfileService.draft'],
      ),
      SimSchoolDoor(
        id: 'language_other',
        kind: SimDoorKind.stateWrite,
        destination: '/cyber/objeto',
        writes: ['idiomaOutro', 'stableLang'],
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'objective',
    name: 'Recepção pedagógica',
    route: '/cyber/objeto',
    purpose: 'Recebe objetivo, nome preferido e anexos, cria a entrada viva.',
    doors: [
      SimSchoolDoor(
        id: 'objective_text',
        kind: SimDoorKind.stateWrite,
        writes: ['objetivo', 'student_profile_notes'],
      ),
      SimSchoolDoor(
        id: 'objective_document',
        kind: SimDoorKind.serverCall,
        calls: ['processAttachment'],
      ),
      SimSchoolDoor(
        id: 'objective_camera',
        kind: SimDoorKind.serverCall,
        calls: ['processAttachment'],
      ),
      SimSchoolDoor(
        id: 'objective_gallery',
        kind: SimDoorKind.serverCall,
        calls: ['processAttachment'],
      ),
      SimSchoolDoor(
        id: 'objective_remove_attachment',
        kind: SimDoorKind.action,
        writes: ['attachments'],
      ),
      SimSchoolDoor(
        id: 'objective_continue',
        kind: SimDoorKind.navigation,
        destination: '/cyber/curriculo',
        writes: ['lessonLocalId', 'LiveEntry'],
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'preparation',
    name: 'Preparo',
    route: '/cyber/curriculo',
    purpose:
        'Roda T00, perfil, currículo, primeira aula T02 e decide placement ou aula.',
    doors: [
      SimSchoolDoor(
        id: 'prep_t00',
        kind: SimDoorKind.serverCall,
        calls: ['/api/bootstrap-t00'],
      ),
      SimSchoolDoor(
        id: 'prep_first_lesson',
        kind: SimDoorKind.serverCall,
        calls: ['T02'],
      ),
      SimSchoolDoor(
        id: 'prep_to_placement',
        kind: SimDoorKind.navigation,
        destination: '/cyber/placement',
      ),
      SimSchoolDoor(
        id: 'prep_to_classroom',
        kind: SimDoorKind.navigation,
        destination: '/cyber/aula',
      ),
      SimSchoolDoor(
        id: 'prep_buy_credits',
        kind: SimDoorKind.navigation,
        destination: '/creditos',
      ),
      SimSchoolDoor(id: 'prep_retry', kind: SimDoorKind.action),
    ],
  ),
  SimSchoolEnvironment(
    id: 'placement',
    name: 'Nivelamento',
    route: '/cyber/placement',
    purpose: 'Opcional: começa do zero ou responde blocos diagnósticos.',
    doors: [
      SimSchoolDoor(
        id: 'placement_skip',
        kind: SimDoorKind.navigation,
        destination: '/cyber/aula',
        writes: ['placement.skipped'],
      ),
      SimSchoolDoor(
        id: 'placement_start',
        kind: SimDoorKind.serverCall,
        calls: ['callPlacementT02'],
      ),
      SimSchoolDoor(
        id: 'placement_answer',
        kind: SimDoorKind.stateWrite,
        writes: ['placement.answers'],
      ),
      SimSchoolDoor(
        id: 'placement_continue',
        kind: SimDoorKind.navigation,
        destination: '/cyber/aula',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'classroom',
    name: 'Sala de aula',
    route: '/cyber/aula',
    purpose:
        'Aula principal: conteúdo, áudio, imagem, pergunta, sinais, dúvida, revisão e recuperação.',
    doors: [
      SimSchoolDoor(id: 'class_menu', kind: SimDoorKind.modal),
      SimSchoolDoor(
        id: 'class_audio',
        kind: SimDoorKind.action,
        calls: ['studentLessonMediaService.playLessonAudioSequence'],
      ),
      SimSchoolDoor(
        id: 'class_review',
        kind: SimDoorKind.modal,
        calls: ['ReviewRoomService'],
      ),
      SimSchoolDoor(
        id: 'class_answer',
        kind: SimDoorKind.stateWrite,
        writes: ['selectedAnswer'],
      ),
      SimSchoolDoor(
        id: 'class_signal_1',
        kind: SimDoorKind.stateWrite,
        calls: ['StudentLessonExecutor'],
      ),
      SimSchoolDoor(
        id: 'class_signal_2',
        kind: SimDoorKind.stateWrite,
        calls: ['StudentLessonExecutor'],
      ),
      SimSchoolDoor(
        id: 'class_signal_3',
        kind: SimDoorKind.stateWrite,
        calls: ['StudentLessonExecutor'],
      ),
      SimSchoolDoor(
        id: 'class_doubt',
        kind: SimDoorKind.modal,
        calls: ['doubtT02Caller'],
      ),
      SimSchoolDoor(
        id: 'class_advance',
        kind: SimDoorKind.action,
        calls: ['LearningDecisionEngine'],
      ),
      SimSchoolDoor(
        id: 'class_done',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
      SimSchoolDoor(
        id: 'class_buy_credits',
        kind: SimDoorKind.navigation,
        destination: '/creditos',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'drawer',
    name: 'Menu da aula',
    route: '/cyber/aula#drawer',
    purpose:
        'Gaveta lateral: histórico, conta, backup, status, créditos e logout.',
    doors: [
      SimSchoolDoor(
        id: 'drawer_new_lesson',
        kind: SimDoorKind.navigation,
        destination: '/cyber/aula',
      ),
      SimSchoolDoor(
        id: 'drawer_credits',
        kind: SimDoorKind.navigation,
        destination: '/creditos',
      ),
      SimSchoolDoor(
        id: 'drawer_open_lesson',
        kind: SimDoorKind.navigation,
        destination: '/cyber/aula',
      ),
      SimSchoolDoor(
        id: 'drawer_rename',
        kind: SimDoorKind.stateWrite,
        writes: ['StudentLearningState.profile.objetivo'],
      ),
      SimSchoolDoor(
        id: 'drawer_delete',
        kind: SimDoorKind.serverCall,
        calls: ['deleteLesson', 'deleteSimLessonByLocalId'],
      ),
      SimSchoolDoor(id: 'drawer_export_backup', kind: SimDoorKind.action),
      SimSchoolDoor(
        id: 'drawer_import_backup',
        kind: SimDoorKind.action,
        calls: ['StudentLearningSync.drain'],
      ),
      SimSchoolDoor(
        id: 'drawer_export_status',
        kind: SimDoorKind.action,
        calls: ['fatherPanel.buildStatusReport'],
      ),
      SimSchoolDoor(
        id: 'drawer_logout',
        kind: SimDoorKind.navigation,
        destination: '/login',
        calls: ['supabase.auth.signOut'],
      ),
      SimSchoolDoor(
        id: 'drawer_delete_account',
        kind: SimDoorKind.navigation,
        destination: '/conta/deletar',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'credits',
    name: 'Caixa',
    route: '/creditos',
    purpose: 'Mostra saldo e abre Stripe Hosted Checkout.',
    doors: [
      SimSchoolDoor(
        id: 'credits_back',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
      SimSchoolDoor(
        id: 'credits_pack_100',
        kind: SimDoorKind.externalLink,
        destination: 'https://checkout.stripe.com/',
      ),
      SimSchoolDoor(
        id: 'credits_pack_200',
        kind: SimDoorKind.externalLink,
        destination: 'https://checkout.stripe.com/',
      ),
      SimSchoolDoor(
        id: 'credits_pack_500',
        kind: SimDoorKind.externalLink,
        destination: 'https://checkout.stripe.com/',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'checkout_return',
    name: 'Retorno do pagamento',
    route: '/checkout/return',
    purpose: 'Confirma pagamento e devolve o aluno ao returnTo salvo.',
    doors: [
      SimSchoolDoor(
        id: 'checkout_continue',
        kind: SimDoorKind.navigation,
        destination: '/cyber/aula',
      ),
      SimSchoolDoor(
        id: 'checkout_retry',
        kind: SimDoorKind.navigation,
        destination: '/creditos',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'father_panel',
    name: 'Painel do Pai',
    route: '/pai',
    purpose: 'Supervisão read-only em linguagem humana.',
    doors: [
      SimSchoolDoor(
        id: 'father_back',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'delete_account',
    name: 'Deletar conta',
    route: '/conta/deletar',
    purpose: 'Solicita exclusão da conta com confirmação DELETAR.',
    doors: [
      SimSchoolDoor(
        id: 'delete_back',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
      SimSchoolDoor(
        id: 'delete_submit',
        kind: SimDoorKind.serverCall,
        calls: ['requestAccountDeletion'],
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'privacy',
    name: 'Privacidade',
    route: '/privacidade',
    purpose: 'Página legal de privacidade.',
    doors: [
      SimSchoolDoor(
        id: 'privacy_back',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
    ],
  ),
  SimSchoolEnvironment(
    id: 'terms',
    name: 'Termos',
    route: '/termos',
    purpose: 'Página legal de termos de uso.',
    doors: [
      SimSchoolDoor(
        id: 'terms_back',
        kind: SimDoorKind.navigation,
        destination: '/',
      ),
    ],
  ),
];

List<SimSchoolDoor> allSimSchoolDoors() => [
  for (final environment in simSchoolEnvironments) ...environment.doors,
];

List<String> unresolvedInternalDestinations() {
  final paths = simLiveRoutes.map((route) => route.path).toSet();
  return allSimSchoolDoors()
      .map((door) => door.destination)
      .whereType<String>()
      .where(
        (destination) =>
            destination.startsWith('/') && !paths.contains(destination),
      )
      .toSet()
      .toList(growable: false);
}
