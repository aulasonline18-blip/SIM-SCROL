enum SimRouteAccess { public, protected, internal, server, external }

enum SimRouteSurface { screen, modal, drawer, dialog, api, external }

enum SimNavigationAction { replace, modal, drawer, dialog, external, server }

enum SimRoutePrecondition {
  authReady,
  authenticated,
  languageSelected,
  objectiveReady,
  activeLesson,
  parentRole,
  paymentReturn,
  serverOnly,
  externalApp,
}

class SimRouteOrigin {
  const SimRouteOrigin({
    required this.origin,
    required this.action,
    required this.navigation,
  });

  final String origin;
  final String action;
  final SimNavigationAction navigation;
}

class SimRouteContractEntry {
  const SimRouteContractEntry({
    required this.name,
    required this.path,
    required this.destination,
    required this.access,
    required this.surface,
    this.requiredParams = const [],
    this.optionalParams = const [],
    this.preconditions = const [],
    this.canDeepLink = false,
    this.restorable = false,
    this.fallbackPath,
    this.origins = const [],
  });

  final String name;
  final String path;
  final String destination;
  final SimRouteAccess access;
  final SimRouteSurface surface;
  final List<String> requiredParams;
  final List<String> optionalParams;
  final List<SimRoutePrecondition> preconditions;
  final bool canDeepLink;
  final bool restorable;
  final String? fallbackPath;
  final List<SimRouteOrigin> origins;

  bool get isProtected => access == SimRouteAccess.protected;
  bool get isOverlay =>
      surface == SimRouteSurface.modal ||
      surface == SimRouteSurface.drawer ||
      surface == SimRouteSurface.dialog;
}

const simRouteContract = <SimRouteContractEntry>[
  SimRouteContractEntry(
    name: 'portal',
    path: '/',
    destination: 'PortalScreen',
    access: SimRouteAccess.public,
    surface: SimRouteSurface.screen,
    canDeepLink: true,
    restorable: true,
    origins: [
      SimRouteOrigin(
        origin: 'any',
        action: 'fallback, logout, finish lesson or explicit portal action',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'login',
    path: '/login',
    destination: 'LoginScreen',
    access: SimRouteAccess.public,
    surface: SimRouteSurface.screen,
    optionalParams: ['returnTo'],
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/',
    origins: [
      SimRouteOrigin(
        origin: 'guard',
        action: 'unauthenticated protected route',
        navigation: SimNavigationAction.replace,
      ),
      SimRouteOrigin(
        origin: 'portal, drawer',
        action: 'login/logout',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'language',
    path: '/cyber/idioma',
    destination: 'ConversationalEntryScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
    ],
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/login',
    origins: [
      SimRouteOrigin(
        origin: 'portal',
        action: 'start after login',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'objective',
    path: '/cyber/objeto',
    destination: 'ConversationalEntryScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.languageSelected,
    ],
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/cyber/idioma',
    origins: [
      SimRouteOrigin(
        origin: 'language, classroom guard, aux room',
        action: 'language selected or missing active lesson',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'preparation',
    path: '/cyber/curriculo',
    destination: 'PhaseBoundaryScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    requiredParams: ['lessonLocalId'],
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.languageSelected,
      SimRoutePrecondition.objectiveReady,
    ],
    canDeepLink: false,
    restorable: true,
    fallbackPath: '/cyber/objeto',
    origins: [
      SimRouteOrigin(
        origin: 'objective',
        action: 'save objective and prepare curriculum',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'placement',
    path: '/cyber/placement',
    destination: 'PlacementLabScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    requiredParams: ['lessonLocalId'],
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.languageSelected,
      SimRoutePrecondition.objectiveReady,
    ],
    canDeepLink: false,
    restorable: true,
    fallbackPath: '/cyber/curriculo',
    origins: [
      SimRouteOrigin(
        origin: 'preparation',
        action: 'placement route decision',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'warmup',
    path: '/cyber/warmup',
    destination: 'WarmupBridgeScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    requiredParams: ['lessonLocalId'],
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.languageSelected,
      SimRoutePrecondition.objectiveReady,
    ],
    canDeepLink: false,
    restorable: true,
    fallbackPath: '/cyber/placement',
    origins: [
      SimRouteOrigin(
        origin: 'placement',
        action: 'warmup bridge before classroom',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'classroom',
    path: '/cyber/aula',
    destination: 'ChatAulaScreen or AulaLabScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    requiredParams: ['lessonLocalId'],
    optionalParams: ['source', 'origin', 'marker'],
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.languageSelected,
      SimRoutePrecondition.objectiveReady,
      SimRoutePrecondition.activeLesson,
    ],
    canDeepLink: false,
    restorable: true,
    fallbackPath: '/cyber/objeto',
    origins: [
      SimRouteOrigin(
        origin: 'preparation, placement, drawer, checkout_return',
        action: 'open active lesson',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'credits',
    path: '/creditos',
    destination: 'CreditsLabScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    optionalParams: ['returnTo', 'canceled'],
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
    ],
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/login',
    origins: [
      SimRouteOrigin(
        origin: 'portal, preparation, classroom, drawer, checkout_return',
        action: 'buy or reload credits',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'checkoutReturn',
    path: '/checkout/return',
    destination: 'CheckoutReturnScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    requiredParams: ['session_id'],
    optionalParams: ['returnTo'],
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.paymentReturn,
    ],
    canDeepLink: true,
    restorable: false,
    fallbackPath: '/creditos',
    origins: [
      SimRouteOrigin(
        origin: 'Stripe hosted checkout',
        action: 'payment success return URL',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'parentPanel',
    path: '/pai',
    destination: 'FatherLabScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
      SimRoutePrecondition.parentRole,
    ],
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/',
    origins: [
      SimRouteOrigin(
        origin: 'drawer, support menu',
        action: 'open responsible adult panel',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'privacy',
    path: '/privacidade',
    destination: 'LegalLabScreen privacy',
    access: SimRouteAccess.public,
    surface: SimRouteSurface.screen,
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/',
    origins: [
      SimRouteOrigin(
        origin: 'login, drawer, footer, billing',
        action: 'open privacy policy',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'terms',
    path: '/termos',
    destination: 'LegalLabScreen terms',
    access: SimRouteAccess.public,
    surface: SimRouteSurface.screen,
    canDeepLink: true,
    restorable: true,
    fallbackPath: '/',
    origins: [
      SimRouteOrigin(
        origin: 'login, drawer, footer, billing',
        action: 'open terms of use',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'deleteAccount',
    path: '/conta/deletar',
    destination: 'DeleteAccountLabScreen',
    access: SimRouteAccess.protected,
    surface: SimRouteSurface.screen,
    preconditions: [
      SimRoutePrecondition.authReady,
      SimRoutePrecondition.authenticated,
    ],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/login',
    origins: [
      SimRouteOrigin(
        origin: 'drawer',
        action: 'request account deletion',
        navigation: SimNavigationAction.replace,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'apiBootstrapT00',
    path: '/api/bootstrap-t00',
    destination: 'server_t00',
    access: SimRouteAccess.server,
    surface: SimRouteSurface.api,
    preconditions: [SimRoutePrecondition.serverOnly],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/',
  ),
  SimRouteContractEntry(
    name: 'apiGenerateLessonImage',
    path: '/api/generate-lesson-image',
    destination: 'server_image',
    access: SimRouteAccess.server,
    surface: SimRouteSurface.api,
    preconditions: [SimRoutePrecondition.serverOnly],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/',
  ),
  SimRouteContractEntry(
    name: 'apiGenerateLessonAudio',
    path: '/api/generate-lesson-audio',
    destination: 'server_audio',
    access: SimRouteAccess.server,
    surface: SimRouteSurface.api,
    preconditions: [SimRoutePrecondition.serverOnly],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/',
  ),
  SimRouteContractEntry(
    name: 'apiPaymentsWebhook',
    path: '/api/public/payments/webhook',
    destination: 'server_stripe_webhook',
    access: SimRouteAccess.server,
    surface: SimRouteSurface.api,
    preconditions: [SimRoutePrecondition.serverOnly],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/',
  ),
  SimRouteContractEntry(
    name: 'externalWhatsapp',
    path: 'https://wa.me/message/RLCYEXAYFUIIA1',
    destination: 'WhatsApp external app',
    access: SimRouteAccess.external,
    surface: SimRouteSurface.external,
    preconditions: [SimRoutePrecondition.externalApp],
    canDeepLink: false,
    restorable: false,
    origins: [
      SimRouteOrigin(
        origin: 'portal',
        action: 'contact developer by WhatsApp',
        navigation: SimNavigationAction.external,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'externalMessenger',
    path: 'https://m.me/61557707493807',
    destination: 'Messenger external app',
    access: SimRouteAccess.external,
    surface: SimRouteSurface.external,
    preconditions: [SimRoutePrecondition.externalApp],
    canDeepLink: false,
    restorable: false,
    origins: [
      SimRouteOrigin(
        origin: 'portal',
        action: 'contact developer by Messenger',
        navigation: SimNavigationAction.external,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'externalStripeCheckout',
    path: 'https://checkout.stripe.com/',
    destination: 'Stripe hosted checkout',
    access: SimRouteAccess.external,
    surface: SimRouteSurface.external,
    preconditions: [SimRoutePrecondition.externalApp],
    canDeepLink: false,
    restorable: false,
    origins: [
      SimRouteOrigin(
        origin: 'credits',
        action: 'open hosted checkout',
        navigation: SimNavigationAction.external,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'portalMenuOverlay',
    path: '/#portal-menu',
    destination: 'Portal menu overlay',
    access: SimRouteAccess.internal,
    surface: SimRouteSurface.modal,
    canDeepLink: false,
    restorable: false,
    origins: [
      SimRouteOrigin(
        origin: 'portal',
        action: 'open menu',
        navigation: SimNavigationAction.modal,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'classroomDrawer',
    path: '/cyber/aula#drawer',
    destination: 'Aula drawer',
    access: SimRouteAccess.internal,
    surface: SimRouteSurface.drawer,
    preconditions: [SimRoutePrecondition.activeLesson],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/cyber/aula',
    origins: [
      SimRouteOrigin(
        origin: 'classroom',
        action: 'open aula menu',
        navigation: SimNavigationAction.drawer,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'classroomDoubtSheet',
    path: '/cyber/aula#doubt',
    destination: 'DoubtInputSheet',
    access: SimRouteAccess.internal,
    surface: SimRouteSurface.modal,
    preconditions: [SimRoutePrecondition.activeLesson],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/cyber/aula',
    origins: [
      SimRouteOrigin(
        origin: 'classroom',
        action: 'open doubt composer',
        navigation: SimNavigationAction.modal,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'classroomReviewRoom',
    path: '/cyber/aula#review',
    destination: 'ReviewRoomView overlay',
    access: SimRouteAccess.internal,
    surface: SimRouteSurface.modal,
    preconditions: [SimRoutePrecondition.activeLesson],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/cyber/aula',
    origins: [
      SimRouteOrigin(
        origin: 'classroom',
        action: 'open review room',
        navigation: SimNavigationAction.modal,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'classroomRecoveryRoom',
    path: '/cyber/aula#recovery',
    destination: 'RecoveryRoomView overlay',
    access: SimRouteAccess.internal,
    surface: SimRouteSurface.modal,
    preconditions: [SimRoutePrecondition.activeLesson],
    canDeepLink: false,
    restorable: false,
    fallbackPath: '/cyber/aula',
    origins: [
      SimRouteOrigin(
        origin: 'classroom',
        action: 'open recovery room',
        navigation: SimNavigationAction.modal,
      ),
    ],
  ),
  SimRouteContractEntry(
    name: 'confirmDialogOverlay',
    path: '/#confirm-dialog',
    destination: 'Shared confirmation dialog',
    access: SimRouteAccess.internal,
    surface: SimRouteSurface.dialog,
    canDeepLink: false,
    restorable: false,
    origins: [
      SimRouteOrigin(
        origin: 'drawer, shared actions',
        action: 'confirm destructive or mode-changing action',
        navigation: SimNavigationAction.dialog,
      ),
    ],
  ),
];

List<SimRouteContractEntry> get simScreenRoutes => simRouteContract
    .where((route) => route.surface == SimRouteSurface.screen)
    .toList(growable: false);

List<SimRouteContractEntry> get simOverlayRoutes =>
    simRouteContract.where((route) => route.isOverlay).toList(growable: false);

SimRouteContractEntry? simRouteByName(String name) {
  for (final route in simRouteContract) {
    if (route.name == name) return route;
  }
  return null;
}

SimRouteContractEntry? simRouteByPath(String rawPath) {
  final normalized = _normalizeLookupPath(rawPath);
  for (final route in simRouteContract) {
    if (route.path == normalized) return route;
  }
  return null;
}

String _normalizeLookupPath(String rawPath) {
  if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
    return rawPath;
  }
  final uri = Uri.tryParse(rawPath);
  if (uri == null) return rawPath;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.fragment.isEmpty ? path : '$path#${uri.fragment}';
}
