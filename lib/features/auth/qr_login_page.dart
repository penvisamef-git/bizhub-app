import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

// "Log in with QR code": the website (Account → Log in on the BizHub app) shows a code that works once, for 60 seconds.
// The app reads it with the camera and the API logs this phone in to the same account (POST /api/user/login-qr/scan).
const _prefix = 'bizhub-login:';

class QrLoginPage extends ConsumerStatefulWidget {
  const QrLoginPage({super.key});
  @override
  ConsumerState<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends ConsumerState<QrLoginPage> with WidgetsBindingObserver {
  final _cam = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam.dispose();
    super.dispose();
  }

  // camera off while the app is in the background
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (!_cam.value.hasCameraPermission) return;
    if (s == AppLifecycleState.resumed && !_busy && _error.isEmpty) {
      _cam.start();
    } else if (s == AppLifecycleState.paused) {
      _cam.stop();
    }
  }

  Future<void> _found(BarcodeCapture cap) async {
    if (_busy || _error.isNotEmpty) return;
    final raw = cap.barcodes.map((b) => b.rawValue ?? '').firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;
    final t = ref.read(tProvider);
    if (!raw.startsWith(_prefix)) {
      setState(() => _error = t('app.qrBad'));
      await _cam.stop();
      return;
    }
    setState(() => _busy = true);
    await _cam.stop();
    try {
      final device = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'iPhone',
        TargetPlatform.android => 'Android',
        _ => 'BizHub app',
      };
      final r = await ref.read(apiProvider).post('${Api.user}/login-qr/scan', {'code': raw, 'device': device});
      final team = r['account_type'] == 'team';
      final data = obj(r['data']);
      // the router sends the person to their home screen once the session is set
      await ref.read(sessionProvider.notifier).set(team ? {...data, 'account_type': 'team'} : data);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.network
            ? t('messages.networkError')
            : e.code == 'qr_expired'
            ? t('app.qrExpired')
            : e.code == 'qr_bad'
            ? t('app.qrBad')
            : e.code == 'team_only'
            ? t('app.teamOnly')
            : e.message;
      });
    }
  }

  void _again() {
    setState(() => _error = '');
    _cam.start();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final box = (size.width * .7).clamp(200.0, 300.0);
    final window = Rect.fromCenter(center: Offset(size.width / 2, size.height * .42), width: box, height: box);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _cam,
            scanWindow: window,
            onDetect: _found,
            errorBuilder: (context, error) => _NoCamera(text: error.errorCode == MobileScannerErrorCode.permissionDenied ? t('app.qrNoCamera') : '${t('app.qrNoCamera')}\n(${error.errorCode.name})'),
          ),
          // frame + texts only while the camera works (no camera → the message above says why)
          ValueListenableBuilder(
            valueListenable: _cam,
            builder: (_, v, child) => v.error != null ? const SizedBox.shrink() : child!,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(child: CustomPaint(painter: _Frame(window, c.pubBrand))),
                ..._texts(t, c, size, window),
              ],
            ),
          ),
          // top bar: back · light
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _RoundIcon(icon: LucideIcons.arrowLeft, label: t('app.cancel'), onTap: () => context.canPop() ? context.pop() : context.go('/login')),
                    const Spacer(),
                    ValueListenableBuilder(
                      valueListenable: _cam,
                      builder: (_, v, _) => v.torchState == TorchState.unavailable
                          ? const SizedBox.shrink()
                          : _RoundIcon(icon: v.torchState == TorchState.on ? LucideIcons.flashlightOff : LucideIcons.flashlight, label: t('app.torch'), onTap: _cam.toggleTorch),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _texts(T t, C c, Size size, Rect window) => [
    // title above the frame
    Positioned(
      left: 24,
      right: 24,
      bottom: size.height - window.top + 28,
      child: Text(
        t('app.qrTitle'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.3),
      ),
    ),
    // help / checking / error below the frame
    Positioned(
      left: 24,
      right: 24,
      top: window.bottom + 28,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _busy
            ? Row(
                key: const ValueKey('busy'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                  const SizedBox(width: 12),
                  Text(
                    t('app.qrChecking'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : _error.isNotEmpty
            ? Column(
                key: const ValueKey('error'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.danger.withValues(alpha: .7)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.circleAlert, color: c.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _again,
                    icon: const Icon(LucideIcons.scanQrCode, size: 18),
                    label: Text(t('app.qrAgain')),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.pubBrand,
                      foregroundColor: c.pubOnBrand,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['KantumruyPro']),
                    ),
                  ),
                ],
              )
            : Text(
                t('app.qrHelp'),
                key: const ValueKey('help'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 15, height: 1.55),
              ),
      ),
    ),
  ];
}

// dark veil with a clear square and brand-coloured corners
class _Frame extends CustomPainter {
  final Rect window;
  final Color color;
  _Frame(this.window, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(24));
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)), Paint()..color = Colors.black.withValues(alpha: .6));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const r = 24.0, len = 34.0;
    final l = window.left, t = window.top, rt = window.right, b = window.bottom;
    for (final path in [
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t + r)
        ..arcToPoint(Offset(l + r, t), radius: const Radius.circular(r))
        ..lineTo(l + len, t),
      Path()
        ..moveTo(rt - len, t)
        ..lineTo(rt - r, t)
        ..arcToPoint(Offset(rt, t + r), radius: const Radius.circular(r))
        ..lineTo(rt, t + len),
      Path()
        ..moveTo(rt, b - len)
        ..lineTo(rt, b - r)
        ..arcToPoint(Offset(rt - r, b), radius: const Radius.circular(r))
        ..lineTo(rt - len, b),
      Path()
        ..moveTo(l + len, b)
        ..lineTo(l + r, b)
        ..arcToPoint(Offset(l, b - r), radius: const Radius.circular(r))
        ..lineTo(l, b - len),
    ]) {
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Frame old) => old.window != window || old.color != color;
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .45),
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onTap,
      tooltip: label,
      icon: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

class _NoCamera extends StatelessWidget {
  final String text;
  const _NoCamera({required this.text});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.cameraOff, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.55),
            ),
          ],
        ),
      ),
    ),
  );
}
