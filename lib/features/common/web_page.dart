import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/web_login.dart';
import '../../widgets/ui.dart';

// open a web screen of BizHub inside the app (already logged in)
void openWeb(BuildContext context, String path, String title) => context.push(Uri(path: '/web', queryParameters: {'path': path, 'title': title}).toString());

// The big editors (website builder, restaurant setup, name card designer…) stay on the web for now.
// This page opens them inside the app: it gives the web page the same login, language and light/dark,
// and hides the web's own header and bottom bar (the app has its own).
class WebPage extends ConsumerStatefulWidget {
  final String path;
  final String title;
  const WebPage({super.key, required this.path, required this.title});
  @override
  ConsumerState<WebPage> createState() => _WebPageState();
}

class _WebPageState extends ConsumerState<WebPage> {
  WebViewController? _wv;
  int _progress = 0;
  bool _primed = false;
  late final Uri _site = Uri.parse(Config.siteUrl);

  static const _hideChrome = '.app-header,.bottom-bar,.sidebar,.more-overlay{display:none!important}.app-main,.app-content{padding-top:8px!important;padding-bottom:24px!important}';

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return; // in a browser there is no web view: the button below opens the page
    final s = ref.read(sessionProvider);
    final prefs = ref.read(prefsProvider);
    final login = s == null ? '' : cryptoJsEncrypt(jsonEncode({...s.data, if (s.team) 'account_type': 'team'}));
    final theme = prefs.theme == ThemeMode.dark
        ? 'dark'
        : prefs.theme == ThemeMode.light
        ? 'light'
        : (WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? 'dark' : 'light');
    final target = _site.resolve(widget.path).toString();
    final prime =
        'try{localStorage.setItem(${jsonEncode(Config.webLoginKey)},${jsonEncode(login)});'
        'localStorage.setItem("bizhub_lang",${jsonEncode(prefs.lang)});'
        'localStorage.setItem("bizhub_theme",${jsonEncode(theme)});}catch(e){}'
        'location.replace(${jsonEncode(target)});';
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => mounted ? setState(() => _progress = p) : null,
          onPageFinished: (url) async {
            if (!_primed) {
              _primed = true;
              await _wv!.runJavaScript(prime);
              return;
            }
            await _wv!.runJavaScript(
              '(function(){var s=document.getElementById("bh-app");if(!s){s=document.createElement("style");s.id="bh-app";document.head.appendChild(s);}s.textContent=${jsonEncode(_hideChrome)};})();',
            );
          },
          // the web moved to its login page by itself (pushState) = it did not get the app's login:
          // usually WEB_LOGIN_KEY in env.json ≠ VITE_LOGIN_STORAGE_KEY of the website
          onUrlChange: (change) {
            final u = Uri.tryParse(change.url ?? '');
            if (!_primed || u == null || u.host != _site.host || u.path != '/login' || !mounted) return;
            toast(context, ref.read(tProvider)('app.webLoginFailed'));
            Navigator.of(context).maybePop();
          },
          onNavigationRequest: (req) {
            final u = Uri.tryParse(req.url);
            if (u == null) return NavigationDecision.prevent;
            // phone, Telegram, mail, other sites → the phone's own apps
            if (u.host != _site.host) {
              launchUrl(u, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            // "back to my businesses" / logged out → back to the app
            if (_primed && (u.path == '/app/dashboard' || u.path == '/login' || u.path == '/app/super-admin/dashboard')) {
              if (mounted) Navigator.of(context).maybePop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      // a tiny page on the same site, just to write the login before the real page starts
      ..loadRequest(_site.resolve('/robots.txt'));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final url = _site.resolve(widget.path);
    return Scaffold(
      backgroundColor: c.appBg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  RoundBtn(LucideIcons.arrowLeft, size: 42, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_wv != null) RoundBtn(LucideIcons.refreshCw, size: 42, onTap: () => _wv!.reload()),
                  const SizedBox(width: 8),
                  RoundBtn(
                    LucideIcons.externalLink,
                    size: 42,
                    tip: t('app.openWeb'),
                    onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
                  ),
                ],
              ),
            ),
          ),
          if (_wv != null && _progress < 100) LinearProgressIndicator(value: _progress / 100, minHeight: 2, color: c.brand, backgroundColor: Colors.transparent),
          Expanded(
            child: _wv != null
                ? Stack(
                    children: [
                      WebViewWidget(controller: _wv!),
                      if (!_primed || _progress < 30)
                        Container(
                          color: c.appBg,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: c.brand),
                              const SizedBox(height: 14),
                              Muted(t('app.loadingPage')),
                            ],
                          ),
                        ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Panel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.globe, size: 32, color: c.brand),
                            const SizedBox(height: 12),
                            Muted(t('app.webNote'), align: TextAlign.center),
                            const SizedBox(height: 16),
                            Btn(
                              t('app.openWeb'),
                              icon: LucideIcons.externalLink,
                              onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
