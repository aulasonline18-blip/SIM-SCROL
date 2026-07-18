import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../sim/media/visual_svg_safety.dart';
import '../../sim/ui/sim_i18n.dart';

@visibleForTesting
bool debugUseVisualWebViewPlaceholder = false;

class VisualWebViewRenderer extends StatefulWidget {
  const VisualWebViewRenderer({
    required this.svgDataUrl,
    this.onSettled,
    super.key,
  });

  final String svgDataUrl;
  final VoidCallback? onSettled;

  @override
  State<VisualWebViewRenderer> createState() => _VisualWebViewRendererState();
}

class _VisualWebViewRendererState extends State<VisualWebViewRenderer> {
  WebViewController? _controller;
  String? _safeSvg;
  bool _failed = false;
  bool _settled = false;

  bool get _useDebugPlaceholder => kDebugMode && debugUseVisualWebViewPlaceholder;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant VisualWebViewRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgDataUrl != widget.svgDataUrl) {
      _controller = null;
      _safeSvg = null;
      _failed = false;
      _settled = false;
      _configure();
    }
  }

  void _configure() {
    final svg = safeLessonSvgFromDataUrl(widget.svgDataUrl);
    if (svg == null) {
      _failed = true;
      _notifySettled();
      return;
    }
    _safeSvg = svg;
    if (_useDebugPlaceholder) {
      _notifySettled();
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url == 'about:blank' || url.startsWith('data:text/html')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) => _notifySettled(),
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _failed = true);
            _notifySettled();
          },
        ),
      );
    controller.loadHtmlString(_htmlFor(svg));
    _controller = controller;
  }

  void _notifySettled() {
    if (_settled) return;
    _settled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSettled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _safeSvg == null) {
      return Center(
        child: Text(
          t('aula_image_unavailable_short'),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_useDebugPlaceholder) {
      return ColoredBox(
        color: Colors.transparent,
        child: Center(
          child: Text(
            t('aula_image_alt'),
            key: const Key('visual-webview-placeholder'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return WebViewWidget(controller: controller);
  }

  String _htmlFor(String svg) {
    return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;background:transparent;}
.frame{width:100vw;height:100vh;display:flex;align-items:center;justify-content:center;background:transparent;}
svg{max-width:100%;max-height:100%;width:100%;height:100%;object-fit:contain;}
</style>
</head>
<body>
<div class="frame">$svg</div>
</body>
</html>
''';
  }
}
