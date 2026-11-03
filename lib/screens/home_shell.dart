// ─────────────────────────────────────────────────────────────────────
// home_shell.dart — Las 3 pestañas + barra inferior.
//   [Perfil]  [ ⚡ Entrenar ]  [Rutinas]
// Gesto: puedes DESLIZAR entre pestañas (PageView) o tocar la barra.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/hx_nav_bar.dart';
import 'profile_screen.dart';
import 'routines_screen.dart';
import 'train_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // PageController maneja qué página se ve; arranca en el centro.
  final _pages = PageController(initialPage: 1);
  int _index = 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Animar a una pestaña (desde la barra o desde otra pantalla).
  void goTo(int i) => _pages.animateToPage(i,
      duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false, // abajo ya está la barra, que maneja su propio margen
        child: PageView(
          controller: _pages,
          // Se dispara al terminar de deslizar a otra página.
          onPageChanged: (i) {
            HapticFeedback.selectionClick();
            setState(() => _index = i);
          },
          children: [
            const ProfileScreen(),
            // Entrenar puede pedir "llévame a Rutinas" (cuando no hay rutinas).
            TrainScreen(onGoToRoutines: () => goTo(2)),
            const RoutinesScreen(),
          ],
        ),
      ),
      bottomNavigationBar: HxNavBar(index: _index, onTap: goTo),
    );
  }
}
