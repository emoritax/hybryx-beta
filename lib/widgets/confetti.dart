// ─────────────────────────────────────────────────────────────────────
// confetti.dart — Lluvia de confeti para celebrar, dibujada a mano con
// CustomPainter (sin paquetes externos).
//
// Idea: generamos ~90 "partículas" con posición, velocidad, giro y color
// aleatorios. Un AnimationController va de 0 a 1 en 3 s; en cada frame el
// painter calcula dónde está cada partícula en el instante t (física de
// caída simple) y la dibuja.
// ─────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/hx.dart';

class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward(); // arranca solo, una vez

  // Partículas generadas UNA vez (no en cada frame, o "temblarían").
  final _particles = _Particle.generate(90);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer: el confeti no bloquea toques a los botones de abajo.
    return IgnorePointer(
      // AnimatedBuilder reconstruye SOLO el CustomPaint en cada frame.
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_particles, _c.value),
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // posición inicial horizontal (0..1 del ancho)
  final double delay; // retraso de salida (0..0.3 del tiempo)
  final double vx; // deriva horizontal
  final double fall; // velocidad de caída
  final double spin; // vueltas que da
  final double size;
  final Color color;

  _Particle(this.x, this.delay, this.vx, this.fall, this.spin, this.size,
      this.color);

  static List<_Particle> generate(int n) {
    final r = math.Random();
    const colors = [Hx.lime, Hx.orange, Hx.blue, Hx.violet, Hx.text];
    // nextDouble() da un número entre 0 y 1; lo escalamos a cada rango.
    return List.generate(
      n,
      (_) => _Particle(
        r.nextDouble(),
        r.nextDouble() * 0.3,
        (r.nextDouble() - 0.5) * 0.4,
        0.8 + r.nextDouble() * 0.7,
        (r.nextDouble() - 0.5) * 12,
        5 + r.nextDouble() * 6,
        colors[r.nextInt(colors.length)],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1

  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      // Tiempo local de la partícula, descontando su retraso.
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt == 0) continue;
      // Caída acelerada: y crece con lt² (como la gravedad).
      final y = -20 + p.fall * size.height * 1.2 * lt * lt;
      final x = p.x * size.width + p.vx * size.width * lt;
      // Se desvanece en el último 25% del recorrido.
      final opacity = lt > 0.75 ? (1 - lt) / 0.25 : 1.0;
      paint.color = p.color.withValues(alpha: opacity);

      canvas.save(); // guardamos el estado del lienzo...
      canvas.translate(x, y); // ...movemos el origen a la partícula...
      canvas.rotate(p.spin * lt); // ...la giramos...
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint);
      canvas.restore(); // ...y volvemos al estado original.
    }
  }

  // Repintar solo si avanzó el tiempo.
  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
