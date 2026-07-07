import '../ui/sim_i18n.dart';

class AulaDrawerAction {
  const AulaDrawerAction({
    required this.id,
    required this.labelKey,
    required this.effect,
    this.destination,
    this.requiresAuth = false,
  });

  final String id;
  final String labelKey;
  final String effect;
  final String? destination;
  final bool requiresAuth;

  String get label => t(labelKey);
}

const aulaDrawerInitialVisible = 30;
const aulaDrawerPageSize = 30;

const aulaDrawerActions = <AulaDrawerAction>[
  AulaDrawerAction(
    id: 'new_lesson',
    labelKey: 'nova_aula',
    effect: 'freezeActive, clearOnboarding, clearCurriculo',
    destination: '/cyber/aula',
  ),
  AulaDrawerAction(
    id: 'top_up',
    labelKey: 'recarregar_creditos',
    effect: 'save returnTo and open credits',
    destination: '/creditos',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'open_current_lesson',
    labelKey: 'menu_open_lesson',
    effect: 'open current active lesson or start objective flow if none exists',
    destination: '/cyber/aula',
  ),
  AulaDrawerAction(
    id: 'parent_panel',
    labelKey: 'parent_panel',
    effect: 'open responsible adult support panel',
    destination: '/pai',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'privacy',
    labelKey: 'privacy',
    effect: 'open privacy policy',
    destination: '/privacidade',
  ),
  AulaDrawerAction(
    id: 'terms',
    labelKey: 'terms',
    effect: 'open terms of use',
    destination: '/termos',
  ),
  AulaDrawerAction(
    id: 'search_history',
    labelKey: 'drawer_search_history',
    effect: 'filter cloud and local lessons by tema, idioma, nivel or id',
  ),
  AulaDrawerAction(
    id: 'open_cloud_lesson',
    labelKey: 'drawer_open_cloud_lesson',
    effect: 'hydrate StudentLearningState from cloud and set active',
    destination: '/cyber/aula',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'open_local_lesson',
    labelKey: 'drawer_open_local_lesson',
    effect: 'restore cyber lesson to session',
    destination: '/cyber/aula',
  ),
  AulaDrawerAction(
    id: 'rename',
    labelKey: 'drawer_rename',
    effect: 'rename local/cloud lesson and enqueue sync',
  ),
  AulaDrawerAction(
    id: 'delete',
    labelKey: 'drawer_delete',
    effect: 'local-first tombstone and cloud delete when authenticated',
  ),
  AulaDrawerAction(
    id: 'export_backup',
    labelKey: 'drawer_export_backup',
    effect: 'download sim-backup-YYYY-MM-DD.txt',
  ),
  AulaDrawerAction(
    id: 'import_backup',
    labelKey: 'drawer_import_backup',
    effect: 'parse backup, import lessons, enqueue sync and pull cloud',
  ),
  AulaDrawerAction(
    id: 'export_status',
    labelKey: 'drawer_export_status',
    effect: 'download sim-status-YYYY-MM-DD.txt from fatherPanel report',
  ),
  AulaDrawerAction(
    id: 'logout',
    labelKey: 'logout',
    effect: 'signOut, clear local session, open login',
    destination: '/login',
    requiresAuth: true,
  ),
  AulaDrawerAction(
    id: 'delete_account',
    labelKey: 'delete_account_request',
    effect: 'open account deletion route',
    destination: '/conta/deletar',
    requiresAuth: true,
  ),
];

bool matchesLessonSearch(String query, List<Object?> parts) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return parts.any(
    (part) => (part ?? '').toString().toLowerCase().contains(needle),
  );
}
