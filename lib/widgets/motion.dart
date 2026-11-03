// ─────────────────────────────────────────────────────────────────────
// motion.dart — Piezas de animación reutilizables. Aquí vive lo
// "dinámico": entradas escalonadas, contadores que suben, barras que se
// llenan, botón 3D que se hunde, punto que pulsa y el logo.
//
// Dos formas de animar en Flutter, y usamos ambas:
//  • Implícita (TweenAnimationBuilder, AnimatedX): le das el valor final
//    y Flutter anima solo desde el anterior. Simple.
//  • Explícita (AnimationController): tú controlas cuándo empieza, la
//    repites, la retrasas. Más control, más código.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/hx.dart';
import '../theme/labels.dart';

/// Aparece subiendo y desvaneciéndose. `index` lo retrasa: el ítem 0
/// entra primero, el 1 un poco después... = efecto "cascada".
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final double dy; // cuánto sube (fracción de su propia altura)

  const FadeSlideIn({super.key, required this.child, this.index = 0, this.dy = 0.15});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

// SingleTickerProviderStateMixin le da al State un "Ticker": un reloj que
// late con cada frame de la pantalla (60/120 por segundo). El
// AnimationController lo necesita para avanzar.
class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));
  // Curva: easeOutCubic arranca rápido y frena suave (se siente natural).
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    // 60 ms entre cada ítem, con tope para que listas largas no tarden.
    final delay = Duration(milliseconds: 60 * widget.index.clamp(0, 10));
    Future.delayed(delay, () {
      if (mounted) _c.forward(); // pudo destruirse mientras esperaba
    });
  }

  @override
  void dispose() {
    _c.dispose(); // un controller sin dispose sigue consumiendo frames
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: Offset(0, widget.dy), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Número que "cuenta" hasta su valor (0 → 1.240). Implícita: si el
/// valor cambia después, anima desde el anterior al nuevo.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  final String suffix;

  const AnimatedCount(
      {super.key, required this.value, required this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${thousands(v)}$suffix', style: style),
    );
  }
}

/// Barra de progreso que se llena animada (XP, series del entreno).
class AnimatedBar extends StatelessWidget {
  final double fraction; // 0..1
  final Color color;
  final double height;

  const AnimatedBar(
      {super.key, required this.fraction, this.color = Hx.lime, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: Hx.line,
        alignment: Alignment.centerLeft, // la parte llena crece desde la izq.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          // FractionallySizedBox: ancho = fracción del padre.
          builder: (context, f, _) => FractionallySizedBox(
            widthFactor: f,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

/// El botón 3D del diseño (sombra lima oscura abajo). Al presionar se
/// "hunde": baja 5 px y la sombra se achica. Vibra al soltar.
class PushButton extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color shadow;
  final Color foreground;

  const PushButton({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = Hx.lime,
    this.shadow = Hx.limeDark,
    this.foreground = Hx.bg,
  });

  @override
  State<PushButton> createState() => _PushButtonState();
}

class _PushButtonState extends State<PushButton> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    // GestureDetector nos da cada fase del toque por separado.
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false), // el dedo se fue del botón
      onTapUp: (_) {
        _set(false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      // AnimatedContainer anima solo cualquier propiedad que cambie
      // (aquí: posición y sombra) en 90 ms.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: 64,
        transform: Matrix4.translationValues(0, _down ? 5 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: widget.shadow, offset: Offset(0, _down ? 1 : 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.title,
                style: Hx.disp(26, color: widget.foreground, spacing: 1)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(widget.subtitle!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.foreground)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Punto que late (indica "en vivo"). Explícita con repeat(reverse).
class PulseDot extends StatefulWidget {
  final Color color;
  const PulseDot({super.key, this.color = Hx.lime});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true); // `..` = llamar repeat sobre el mismo objeto

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.7, end: 1.2).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// El logo HYBRYX recortado con esquinas redondeadas.
class HxLogo extends StatelessWidget {
  final double size;
  const HxLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset('assets/logo.png',
          width: size, height: size, fit: BoxFit.cover),
    );
  }
}

/// Insignia de nivel ("Nv. 12") que hace "pop" cuando el nivel cambia.
/// AnimatedSwitcher anima entre el hijo viejo y el nuevo; la `key` con el
/// nivel es lo que le indica que el hijo cambió.
class LevelBadge extends StatelessWidget {
  final int level;
  final double fontSize;
  const LevelBadge({super.key, required this.level, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: child),
      child: Container(
        key: ValueKey(level),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: Hx.lime, borderRadius: BorderRadius.circular(6)),
        child: Text('Nv. $level',
            style: Hx.disp(fontSize, weight: FontWeight.w700, color: Hx.bg)),
      ),
    );
  }
}
