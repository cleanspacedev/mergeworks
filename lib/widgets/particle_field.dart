import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A lightweight particle overlay that can be placed in a Stack and triggered
/// using [burst] to emit colorful particles from a given position.
class ParticleField extends StatefulWidget {
  const ParticleField({super.key});

  @override
  State<ParticleField> createState() => ParticleFieldState();
}

class ParticleFieldState extends State<ParticleField> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<_Particle> _particles = [];
  Duration _lastTime = Duration.zero;

  static const int _maxParticles = 220;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_onTick)
      ..forward();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Emit a burst of particles at [origin] in the overlay's coordinate space.
  void burst(Offset origin, {int count = 36}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final colors = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.onPrimary.withValues(alpha: 0.8),
    ];
    final rand = math.Random();
    for (int i = 0; i < count; i++) {
      if (_particles.length >= _maxParticles) break;
      final angle = rand.nextDouble() * math.pi * 2;
      final speed = 90 + rand.nextDouble() * 180; // px/s
      final vx = math.cos(angle) * speed;
      final vy = math.sin(angle) * speed;
      final life = 600 + rand.nextInt(700); // ms
      final size = 2.0 + rand.nextDouble() * 4.0;
      final color = colors[rand.nextInt(colors.length)];
      _particles.add(_Particle(
        position: origin,
        velocity: Offset(vx, vy),
        lifeMs: life,
        maxLifeMs: life,
        size: size,
        color: color,
        rotation: rand.nextDouble() * math.pi,
        rotationSpeed: (rand.nextDouble() - 0.5) * 6,
      ));
    }
    if (!_ticker.isAnimating) _ticker.forward();
    setState(() {});
  }

  void _onTick() {
    final elapsed = _ticker.lastElapsedDuration ?? Duration.zero;
    final dtMs = (elapsed - _lastTime).inMilliseconds;
    _lastTime = elapsed;
    if (dtMs <= 0) return;

    final gravity = 220.0; // px/s^2 downward
    final damping = 0.98; // velocity damping per frame

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.lifeMs -= dtMs;
      if (p.lifeMs <= 0) {
        _particles.removeAt(i);
        continue;
      }
      final dt = dtMs / 1000.0;
      // Integrate motion
      p.velocity = Offset(p.velocity.dx * damping, p.velocity.dy * damping + gravity * dt);
      p.position = Offset(p.position.dx + p.velocity.dx * dt, p.position.dy + p.velocity.dy * dt);
      p.rotation += p.rotationSpeed * dt;
    }

    if (_particles.isEmpty) {
      _ticker.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(_particles),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final t = p.lifeMs / p.maxLifeMs; // 1 -> 0
      final opacity = (t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);
      final rect = Rect.fromCenter(center: Offset.zero, width: p.size * (0.8 + 0.4 * (1 - t)), height: p.size);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.lifeMs,
    required this.maxLifeMs,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });

  Offset position;
  Offset velocity;
  double size;
  int lifeMs;
  int maxLifeMs;
  Color color;
  double rotation;
  double rotationSpeed;
}
