import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sim/organism/sim_organism.dart';

typedef ExternalDoorLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

String _pathForInternalRoute(String raw) {
  final clean = raw.trim();
  if (clean.isEmpty || clean.startsWith('//')) return '/';
  final uri = Uri.tryParse(clean);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return '/';
  final path = uri.path.isEmpty ? '/' : uri.path;
  return SimOrganismRouter.isKnownScreenRoute(path) ? path : '/';
}

String safeNavigationRoute(String raw) => _pathForInternalRoute(raw);

String safeNavigationReturnTo(String raw) => _pathForInternalRoute(raw);

Future<bool> _launchExternalDoor(Uri uri, LaunchMode mode) {
  return launchUrl(uri, mode: mode);
}

class NavigationState extends ChangeNotifier {
  NavigationState({this._launcher = _launchExternalDoor});

  final ExternalDoorLauncher _launcher;

  String route = '/';
  String returnTo = '/';
  String? externalDoorOpened;
  String? externalDoorPending;
  String? externalDoorError;
  String? rejectedRoute;
  String? routeFallbackReason;

  void goPortal() {
    openRoute('/');
  }

  void goLogin({String target = '/'}) {
    returnTo = safeNavigationReturnTo(target);
    openRoute('/login');
  }

  void goAula() {
    openRoute('/cyber/aula');
  }

  void openRoute(String path, {String fallbackReason = 'invalid_route'}) {
    final next = safeNavigationRoute(path);
    final rejected = next != _pathForInternalRoute(path) || next != path.trim();
    if (rejected && next == '/') {
      rejectedRoute = path;
      routeFallbackReason = fallbackReason;
    } else {
      rejectedRoute = null;
      routeFallbackReason = null;
    }
    route = next;
    notifyListeners();
  }

  void setReturnTo(String target) {
    returnTo = safeNavigationReturnTo(target);
    notifyListeners();
  }

  Future<bool> openExternalDoor(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      externalDoorPending = null;
      externalDoorError = 'external_door_invalid_url';
      notifyListeners();
      return false;
    }
    externalDoorPending = url;
    externalDoorError = null;
    notifyListeners();
    final opened = await _launcher(uri, LaunchMode.externalApplication);
    externalDoorPending = null;
    if (opened) {
      externalDoorOpened = url;
      externalDoorError = null;
    } else {
      externalDoorError = 'external_door_open_failed';
    }
    notifyListeners();
    return opened;
  }
}
