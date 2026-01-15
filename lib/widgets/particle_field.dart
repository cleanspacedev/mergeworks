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
  void burst(Offset origin, {int count = 36, int variant = 0}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.onPrimary.withValues(alpha: 0.8),
    ];
    final rand = math.Random();

    // Variant presets: 0=balanced, 1=floaty, 2=punchy
    final v = variant % 3;
    double minSpeed, maxSpeed;
    int minLife, maxLife;
    double gravity, damping;
    double minSize, maxSize;
    switch (v) {
      case 1: // floaty, longer life
        minSpeed = 70; maxSpeed = 140; minLife = 900; maxLife = 1600; gravity = 120; damping = 0.985; minSize = 3.0; maxSize = 5.0;
        break;
      case 2: // punchy, heavier
        minSpeed = 140; maxSpeed = 260; minLife = 500; maxLife = 1000; gravity = 320; damping = 0.97; minSize = 2.0; maxSize = 3.0;
        break;
      default: // balanced
        minSpeed = 90; maxSpeed = 180; minLife = 600; maxLife = 1300; gravity = 220; damping = 0.98; minSize = 2.0; maxSize = 4.0;
    }

    for (int i = 0; i < count; i++) {
      if (_particles.length >= _maxParticles) break;
      final angle = rand.nextDouble() * math.pi * 2;
      final speed = minSpeed + rand.nextDouble() * (maxSpeed - minSpeed);
      final vx = math.cos(angle) * speed;
      final vy = math.sin(angle) * speed;
      final life = minLife + rand.nextInt(maxLife - minLife + 1); // ms
      final size = minSize + rand.nextDouble() * (maxSize - minSize);
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
        gravity: gravity,
        damping: damping,
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

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.lifeMs -= dtMs;
      if (p.lifeMs <= 0) {
        _particles.removeAt(i);
        continue;
      }
      final dt = dtMs / 1000.0;
      // Integrate motion with per-particle physics
      p.velocity = Offset(p.velocity.dx * p.damping, p.velocity.dy * p.damping + p.gravity * dt);
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
    required this.gravity,
    required this.damping,
  });

  Offset position;
  Offset velocity;
  double size;
  int lifeMs;
  int maxLifeMs;
  Color color;
  double rotation;
  double rotationSpeed;
  double gravity;
  double damping;
}
