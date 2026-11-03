// ─────────────────────────────────────────────────────────────────────
// home_shell.dart — Barra de navegación inferior con 3 pestañas.
// Sigue tu idea estilo Clash Royale: el CENTRO es "entrenar".
//   [Exercises]  [ Train ]  [Routines]
// (Profile, Ranked y Feed quedan fuera de la beta.)
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'exercise_library_screen.dart';
import 'routines_screen.dart';
import 'train_screen.dart';

/// StatefulWidget porque recuerda QUÉ pestaña está seleccionada.
/// Un StatefulWidget son 2 clases: el widget (configuración, inmutable)
/// y su State (datos que cambian y sobreviven entre reconstrucciones).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

// El `_` inicial hace la clase privada a este archivo.
class _HomeShellState extends State<HomeShell> {
  int _index = 1; // arrancamos en el centro: "Train"

  @override
  Widget build(BuildContext context) {
    // Elegimos la pantalla según el índice. Al cambiar de pestaña se crea
    // una pantalla NUEVA -> su initState() vuelve a cargar de la DB.
    // ¿Por qué no IndexedStack (que mantiene vivas las 3)? Porque si
    // creas una rutina y vuelves a "Train", queremos ver la lista fresca
    // sin tener que sincronizar estado entre pantallas.
    final Widget page = switch (_index) {
      0 => const ExerciseLibraryScreen(),
      2 => const RoutinesScreen(),
      _ => const TrainScreen(), // `_` = cualquier otro valor (1)
    };

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        // setState(): "cambié datos, vuelve a llamar build()".
        // Sin setState la variable cambia pero la pantalla NO se repinta.
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.fitness_center), label: 'Exercises'),
          NavigationDestination(
              icon: Icon(Icons.play_circle_fill), label: 'Train'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Routines'),
        ],
      ),
    );
  }
}
