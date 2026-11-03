// ─────────────────────────────────────────────────────────────────────
// hx_nav_bar.dart — Barra inferior del diseño: botón central "Entrenar"
// elevado (cuadro lima con rayo) y pestañas laterales.
//
// Dinámico: el ícono activo crece y cambia de color animado, aparece un
// indicador debajo, y el botón central rebota al tocarlo.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/hx.dart';

class HxNavBar extends StatefulWidget {
  final int index; // 0 Perfil · 1 Entrenar · 2 Rutinas
  final ValueChanged<int> onTap;

  const HxNavBar({super.key, required this.index, required this.onTap});

  @override
  State<HxNavBar> createState() => _HxNavBarState();
}

class _HxNavBarState extends State<HxNavBar>
    with SingleTickerProviderStateMixin {
  // Controlador del rebote del botón central.
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  // TweenSequence encadena tramos: se encoge, se pasa de tamaño y vuelve.
  // `weight` = qué porción del tiempo total dura cada tramo.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.82, end: 1.12), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 30),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _tapCenter() {
    _bounce.forward(from: 0); // reinicia el rebote aunque esté a medias
    HapticFeedback.lightImpact();
    widget.onTap(1);
  }

  @override
  Widget build(BuildContext context) {
    // Alto extra para la barra de gestos de Android (celulares sin botones).
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: 76 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Hx.navBg,
        border: Border(top: BorderSide(color: Hx.line)),
      ),
      child: Row(
        children: [
          _side(0, Icons.person_outline_rounded, 'Perfil'),
          Expanded(child: _center()),
          _side(2, Icons.style_outlined, 'Rutinas'),
        ],
      ),
    );
  }

  Widget _side(int i, IconData icon, String label) {
    final on = widget.index == i;
    return Expanded(
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap(i);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AnimatedScale: cambia `scale` y Flutter interpola solo.
            AnimatedScale(
              scale: on ? 1.15 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack, // se pasa un poquito: "salta"
              child: Icon(icon, size: 24, color: on ? Hx.lime : Hx.dim),
            ),
            const SizedBox(height: 4),
            // AnimatedDefaultTextStyle anima color y grosor del texto.
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: Hx.body,
                fontSize: 11,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? Hx.lime : Hx.dim,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 4),
            // Indicador: una rayita que crece de 0 a 16 px de ancho.
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: on ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                  color: Hx.lime, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _center() {
    final on = widget.index == 1;
    return GestureDetector(
      onTap: _tapCenter,
      behavior: HitTestBehavior.opaque, // toda el área responde, no solo el ícono
      child: Column(
        children: [
          // Translate hacia arriba: el botón "sobresale" de la barra, como
          // en el diseño (margin-top: -24px). Nada lo recorta porque los
          // Container no recortan por defecto.
          Transform.translate(
            offset: const Offset(0, -20),
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: on ? Hx.lime : Hx.surface2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Hx.navBg, width: 4),
                ),
                child: Icon(Icons.bolt_rounded,
                    size: 30, color: on ? Hx.bg : Hx.lime),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -16),
            child: Text('Entrenar',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: on ? Hx.lime : Hx.dim,
                )),
          ),
        ],
      ),
    );
  }
}
