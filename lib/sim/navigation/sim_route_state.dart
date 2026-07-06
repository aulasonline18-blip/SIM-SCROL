import 'sim_route_contract.dart';

const simRouteStateSnapshotVersion = 1;

enum SimRouteStateFieldKind { live, historical, volatile, sensitive }

enum SimRouteStateScope { memory, local, neverPersist }

class SimRouteStateField {
  const SimRouteStateField({
    required this.key,
    required this.kind,
    required this.scope,
    this.description = '',
  });

  final String key;
  final SimRouteStateFieldKind kind;
  final SimRouteStateScope scope;
  final String description;

  bool get canPersist =>
      scope != SimRouteStateScope.neverPersist &&
      kind != SimRouteStateFieldKind.sensitive &&
      kind != SimRouteStateFieldKind.volatile;
}

class SimRouteStateContract {
  const SimRouteStateContract({
    required this.routeName,
    required this.path,
    required this.restorable,
    required this.storageScope,
    required this.fields,
    this.ttl,
    this.sessionScoped = true,
  });

  final String routeName;
  final String path;
  final bool restorable;
  final SimRouteStateScope storageScope;
  final List<SimRouteStateField> fields;
  final Duration? ttl;
  final bool sessionScoped;

  Iterable<SimRouteStateField> get persistableFields =>
      fields.where((field) => field.canPersist);

  Iterable<SimRouteStateField> get volatileFields =>
      fields.where((field) => field.kind == SimRouteStateFieldKind.volatile);

  Iterable<SimRouteStateField> get sensitiveFields =>
      fields.where((field) => field.kind == SimRouteStateFieldKind.sensitive);

  bool allowsField(String key) => fields.any((field) => field.key == key);

  bool canPersistField(String key) {
    for (final field in fields) {
      if (field.key == key) return field.canPersist;
    }
    return false;
  }
}

const simRouteStateContracts = <SimRouteStateContract>[
  SimRouteStateContract(
    routeName: 'portal',
    path: '/',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'selectedTab',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
        description: 'Portal tab or section selected by the student.',
      ),
      SimRouteStateField(
        key: 'menuOpen',
        kind: SimRouteStateFieldKind.volatile,
        scope: SimRouteStateScope.neverPersist,
        description: 'Transient portal menu overlay.',
      ),
      SimRouteStateField(
        key: 'filters',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
        description: 'Lightweight portal filtering state.',
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'login',
    path: '/login',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    ttl: Duration(minutes: 30),
    fields: [
      SimRouteStateField(
        key: 'returnTo',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
        description: 'Safe destination after authentication completes.',
      ),
      SimRouteStateField(
        key: 'recoverableError',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
        description: 'Visible login error that can be retried.',
      ),
      SimRouteStateField(
        key: 'password',
        kind: SimRouteStateFieldKind.sensitive,
        scope: SimRouteStateScope.neverPersist,
        description: 'Credentials must never be persisted.',
      ),
      SimRouteStateField(
        key: 'authToken',
        kind: SimRouteStateFieldKind.sensitive,
        scope: SimRouteStateScope.neverPersist,
        description: 'Auth tokens are outside route state.',
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'language',
    path: '/cyber/idioma',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'selectedLanguageCode',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'otherLanguage',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'objective',
    path: '/cyber/objeto',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    ttl: Duration(hours: 2),
    fields: [
      SimRouteStateField(
        key: 'preferredName',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'objectiveText',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'guidedAnswers',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'attachmentMetadata',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
        description: 'Names, sizes and content types only; no binary data.',
      ),
      SimRouteStateField(
        key: 'attachmentBlob',
        kind: SimRouteStateFieldKind.volatile,
        scope: SimRouteStateScope.neverPersist,
        description: 'File bytes and base64 payloads are heavy.',
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'preparation',
    path: '/cyber/curriculo',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'lessonLocalId',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'selectedCurriculumItem',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'loadedCurriculum',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'loadingState',
        kind: SimRouteStateFieldKind.volatile,
        scope: SimRouteStateScope.neverPersist,
      ),
      SimRouteStateField(
        key: 'recoverableError',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'placement',
    path: '/cyber/placement',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'lessonLocalId',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'placementProgress',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'currentAnswer',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'loadingState',
        kind: SimRouteStateFieldKind.volatile,
        scope: SimRouteStateScope.neverPersist,
      ),
      SimRouteStateField(
        key: 'recoverableError',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'classroom',
    path: '/cyber/aula',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'lessonLocalId',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'currentLayer',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'currentItem',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'scrollOffset',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'visibleAnchor',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'conversationHistory',
        kind: SimRouteStateFieldKind.historical,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'deadFeedback',
        kind: SimRouteStateFieldKind.historical,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'draftDoubtText',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'draftDoubtAttachmentMetadata',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'temporarySelection',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'mediaAttachmentBlob',
        kind: SimRouteStateFieldKind.volatile,
        scope: SimRouteStateScope.neverPersist,
      ),
      SimRouteStateField(
        key: 'studentPrivateToken',
        kind: SimRouteStateFieldKind.sensitive,
        scope: SimRouteStateScope.neverPersist,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'credits',
    path: '/creditos',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    ttl: Duration(minutes: 30),
    fields: [
      SimRouteStateField(
        key: 'returnTo',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'checkoutInProgress',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'canceled',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'recoverableError',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'paymentSecret',
        kind: SimRouteStateFieldKind.sensitive,
        scope: SimRouteStateScope.neverPersist,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'checkoutReturn',
    path: '/checkout/return',
    restorable: false,
    storageScope: SimRouteStateScope.neverPersist,
    fields: [
      SimRouteStateField(
        key: 'session_id',
        kind: SimRouteStateFieldKind.sensitive,
        scope: SimRouteStateScope.neverPersist,
      ),
      SimRouteStateField(
        key: 'returnTo',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'parentPanel',
    path: '/pai',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'selectedTab',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
      SimRouteStateField(
        key: 'filters',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'privacy',
    path: '/privacidade',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'scrollOffset',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'terms',
    path: '/termos',
    restorable: true,
    storageScope: SimRouteStateScope.memory,
    fields: [
      SimRouteStateField(
        key: 'scrollOffset',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'deleteAccount',
    path: '/conta/deletar',
    restorable: false,
    storageScope: SimRouteStateScope.neverPersist,
    fields: [
      SimRouteStateField(
        key: 'confirmationText',
        kind: SimRouteStateFieldKind.sensitive,
        scope: SimRouteStateScope.neverPersist,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'classroomDrawer',
    path: '/cyber/aula#drawer',
    restorable: false,
    storageScope: SimRouteStateScope.neverPersist,
    fields: [
      SimRouteStateField(
        key: 'searchQuery',
        kind: SimRouteStateFieldKind.volatile,
        scope: SimRouteStateScope.neverPersist,
      ),
    ],
  ),
  SimRouteStateContract(
    routeName: 'classroomDoubtSheet',
    path: '/cyber/aula#doubt',
    restorable: false,
    storageScope: SimRouteStateScope.neverPersist,
    fields: [
      SimRouteStateField(
        key: 'draftDoubtText',
        kind: SimRouteStateFieldKind.live,
        scope: SimRouteStateScope.memory,
        description:
            'Owned by the classroom route state, not by overlay route.',
      ),
    ],
  ),
];

SimRouteStateContract? simRouteStateByName(String routeName) {
  for (final contract in simRouteStateContracts) {
    if (contract.routeName == routeName) return contract;
  }
  return null;
}

SimRouteStateContract? simRouteStateByPath(String rawPath) {
  final route = simRouteByPath(rawPath);
  if (route == null) return null;
  return simRouteStateByName(route.name);
}

bool simRouteCanRestoreField(String routeName, String fieldKey) {
  return simRouteStateByName(routeName)?.canPersistField(fieldKey) ?? false;
}
