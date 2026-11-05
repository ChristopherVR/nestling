import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization.dart';
import '../theme.dart';

/// Simple, theme-coloured diagrams for camera setup. The camera is a generic
/// drawing (head, lens, night light and stand), not Nanit artwork.
enum CameraScene {
  /// Phone and camera inside a home, no cloud.
  overview,

  /// Phone and camera both on the home router's Wi-Fi.
  network,

  /// The pairing button on the back and the flashing night light.
  pairing,

  /// The phone talking to the nearby camera over Bluetooth.
  bluetooth,

  /// The camera receiving the home Wi-Fi details.
  wifi,

  /// The phone searching the network.
  search,

  /// All set.
  done,
}

class CameraIllustration extends StatelessWidget {
  const CameraIllustration(this.scene, {super.key, this.height = 168});
  final CameraScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(Corners.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, box) => _scene(scheme, box.biggest),
        ),
      ),
    );
  }

  Widget _scene(ColorScheme s, Size size) {
    final w = size.width, h = size.height;
    // Keep the drawing a sensible width on tablets and desktops.
    final stage = math.min(w, h * 2.4);
    final left = (w - stage) / 2;
    double x(double f) => left + stage * f;
    final cam = h * 0.62;
    Widget camera({
      bool flashing = false,
      bool button = false,
      bool ok = false,
    }) => SizedBox(
      width: cam * 0.8,
      height: cam,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CameraPainter(
                scheme: s,
                flashing: flashing,
                showButton: button,
              ),
            ),
          ),
          if (ok)
            Positioned(
              right: -12,
              top: -8,
              child: _Badge(Icons.check, s.primary, s.onPrimary),
            ),
        ],
      ),
    );
    Widget at(double fx, double fy, Widget child) => Positioned(
      left: x(fx),
      top: h * fy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
    Widget waves(double fx, double fy, double angle, {Color? color}) => at(
      fx,
      fy,
      CustomPaint(
        size: Size.square(h * 0.32),
        painter: WavesPainter(color: color ?? s.primary, angle: angle),
      ),
    );
    Widget icon(IconData i, double size, Color c) =>
        Icon(i, size: size, color: c);
    Widget phone() =>
        _Device(icon: Icons.smartphone, size: h * 0.42, scheme: s);
    return switch (scene) {
      CameraScene.overview => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: HousePainter(
                color: s.outline,
                left: x(0.08),
                right: x(0.92),
              ),
            ),
          ),
          at(0.3, 0.62, phone()),
          waves(0.5, 0.6, 0),
          at(0.7, 0.58, camera()),
          at(
            0.88,
            0.2,
            _Badge(
              Icons.cloud_off,
              s.secondaryContainer,
              s.onSecondaryContainer,
            ),
          ),
        ],
      ),
      CameraScene.network => Stack(
        children: [
          at(0.18, 0.58, phone()),
          waves(0.34, 0.5, math.pi),
          at(
            0.5,
            0.45,
            _Device(icon: Icons.router_outlined, size: h * 0.4, scheme: s),
          ),
          waves(0.66, 0.5, 0),
          at(0.82, 0.56, camera()),
          at(0.5, 0.86, icon(Icons.check_circle, h * 0.16, s.primary)),
        ],
      ),
      CameraScene.pairing => Stack(
        children: [
          at(
            0.42,
            0.52,
            Transform.scale(
              scale: 1.25,
              child: camera(flashing: true, button: true),
            ),
          ),
          at(0.68, 0.42, icon(Icons.touch_app_outlined, h * 0.22, s.primary)),
        ],
      ),
      CameraScene.bluetooth => Stack(
        children: [
          at(0.24, 0.52, phone()),
          at(0.24, 0.18, _Badge(Icons.bluetooth, s.primary, s.onPrimary)),
          waves(0.46, 0.5, 0),
          at(0.74, 0.52, camera(flashing: true)),
          at(
            0.5,
            0.88,
            _Distance(color: s.onSurfaceVariant, width: stage * 0.36),
          ),
        ],
      ),
      CameraScene.wifi => Stack(
        children: [
          at(
            0.2,
            0.5,
            _Device(icon: Icons.router_outlined, size: h * 0.4, scheme: s),
          ),
          waves(0.4, 0.5, 0),
          at(
            0.5,
            0.2,
            _Badge(
              Icons.password,
              s.secondaryContainer,
              s.onSecondaryContainer,
            ),
          ),
          at(0.72, 0.54, camera(flashing: true)),
        ],
      ),
      CameraScene.search => Stack(
        children: [
          at(0.26, 0.54, phone()),
          at(0.36, 0.34, _Badge(Icons.search, s.primary, s.onPrimary)),
          waves(0.5, 0.52, 0, color: s.outline),
          at(0.74, 0.54, Opacity(opacity: 0.55, child: camera())),
        ],
      ),
      CameraScene.done => Stack(
        children: [
          at(0.5, 0.52, Transform.scale(scale: 1.2, child: camera(ok: true))),
        ],
      ),
    };
  }
}

class _Device extends StatelessWidget {
  const _Device({required this.icon, required this.size, required this.scheme});
  final IconData icon;
  final double size;
  final ColorScheme scheme;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: scheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: scheme.outlineVariant, width: 2),
    ),
    child: Icon(icon, size: size * 0.56, color: scheme.onSurface),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.background, this.foreground);
  final IconData icon;
  final Color background, foreground;
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, size: 20, color: foreground),
  );
}

/// "1–2 m" with a measuring line.
class _Distance extends StatelessWidget {
  const _Distance({required this.color, required this.width});
  final Color color;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: Text(
            '1–2 m',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 1.5)),
      ],
    ),
  );
}

/// A generic nursery camera: rounded head with lens, a glowing night light
/// underneath, and a stand. Optionally highlights the rear pairing button.
class CameraPainter extends CustomPainter {
  CameraPainter({
    required this.scheme,
    this.flashing = false,
    this.showButton = false,
  });
  final ColorScheme scheme;
  final bool flashing, showButton;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Paint()..color = scheme.surface;
    final edge = Paint()
      ..color = scheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Stand.
    final stand = Paint()
      ..color = scheme.outline
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.55), Offset(w * 0.5, h * 0.9), stand);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.93),
        width: w * 0.62,
        height: h * 0.09,
      ),
      Paint()..color = scheme.outline,
    );
    // Night light glow under the head.
    final light = Offset(w * 0.5, h * 0.56);
    if (flashing) {
      final rays = Paint()
        ..color = scheme.tertiary
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 7; i++) {
        final a = math.pi * (0.15 + 0.7 * i / 6);
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(light + d * w * 0.24, light + d * w * 0.36, rays);
      }
      canvas.drawCircle(
        light,
        w * 0.2,
        Paint()..color = scheme.tertiary.withValues(alpha: 0.25),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: light, width: w * 0.4, height: h * 0.07),
      Paint()..color = flashing ? scheme.tertiary : scheme.secondaryContainer,
    );
    // Head.
    final head = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.46),
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(head, body);
    canvas.drawRRect(head, edge);
    // Lens.
    final lens = Offset(w * 0.5, h * 0.3);
    canvas.drawCircle(lens, w * 0.19, Paint()..color = scheme.inverseSurface);
    canvas.drawCircle(lens, w * 0.1, Paint()..color = scheme.primary);
    canvas.drawCircle(
      lens + Offset(-w * 0.04, -w * 0.04),
      w * 0.03,
      Paint()..color = scheme.onPrimary.withValues(alpha: 0.8),
    );
    if (showButton) {
      // The button on the back, drawn at the head's edge and circled.
      final button = Offset(w * 0.92, h * 0.31);
      canvas.drawCircle(button, w * 0.05, Paint()..color = scheme.tertiary);
      canvas.drawCircle(
        button,
        w * 0.12,
        Paint()
          ..color = scheme.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(CameraPainter old) =>
      old.scheme != scheme ||
      old.flashing != flashing ||
      old.showButton != showButton;
}

/// Three signal arcs pointing at [angle] (0 = right, pi = left).
class WavesPainter extends CustomPainter {
  WavesPainter({required this.color, this.angle = 0});
  final Color color;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(
      size.width / 2 - math.cos(angle) * size.width * 0.35,
      size.height / 2,
    );
    for (var i = 1; i <= 3; i++) {
      final r = size.width * 0.22 * i;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        angle - 0.6,
        1.2,
        false,
        Paint()
          ..color = color.withValues(alpha: 1 - i * 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(WavesPainter old) =>
      old.color != color || old.angle != angle;
}

/// A simple house outline: roof and walls.
class HousePainter extends CustomPainter {
  HousePainter({required this.color, required this.left, required this.right});
  final Color color;
  final double left, right;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final mid = (left + right) / 2;
    final path = Path()
      ..moveTo(left, h * 0.42)
      ..lineTo(mid, h * 0.1)
      ..lineTo(right, h * 0.42)
      ..moveTo(left + 12, h * 0.36)
      ..lineTo(left + 12, h * 0.95)
      ..lineTo(right - 12, h * 0.95)
      ..lineTo(right - 12, h * 0.36);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(HousePainter old) =>
      old.color != color || old.left != left || old.right != right;
}

/// What a router's device list looks like, with the camera's row
/// highlighted, so people know what to look for.
class RouterListExample extends StatelessWidget {
  const RouterListExample({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    Widget row(IconData icon, String name, String ip, {bool camera = false}) {
      // The camera's row looks selected, the way a list marks a choice.
      final style = (camera ? t.labelLarge : t.bodyMedium)?.copyWith(
        color: camera ? s.onSecondaryContainer : null,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      return Container(
        color: camera ? s.secondaryContainer : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: camera ? s.onSecondaryContainer : s.onSurfaceVariant,
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(name, style: style)),
            Text(ip, style: style),
          ],
        ),
      );
    }

    return Semantics(
      label: tr('Example router device list. Nanit camera, 192.168.1.25'),
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: s.outlineVariant),
            borderRadius: BorderRadius.circular(Corners.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row(Icons.laptop, 'Living-room-PC', '192.168.1.12'),
              row(Icons.smartphone, 'Pixel-8', '192.168.1.18'),
              row(
                Icons.videocam_outlined,
                'Nanit (N301…)',
                '192.168.1.25',
                camera: true,
              ),
              row(Icons.tv, 'Samsung-TV', '192.168.1.31'),
            ],
          ),
        ),
      ),
    );
  }
}
