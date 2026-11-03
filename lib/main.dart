// ─────────────────────────────────────────────────────────────────────
// main.dart — Punto de entrada. Flutter siempre arranca por main().
// ─────────────────────────────────────────────────────────────────────

// material.dart trae todos los widgets de Material Design
// (Scaffold, AppBar, botones, temas...). Es la base visual de la app.
import 'package:flutter/material.dart';

// La "carcasa" con la barra de navegación inferior.
import 'screens/home_shell.dart';

void main() {
  // runApp() toma el widget raíz y lo pinta a pantalla completa.
  // NO abrimos la base de datos aquí: se abre la primera vez que alguien
  // la pide (lazy, ver db.dart). Así el primer frame aparece rápido.
  runApp(const HybryxApp());
}

/// StatelessWidget = widget sin estado propio que cambie con el tiempo.
/// La raíz solo configura el tema y la pantalla inicial.
class HybryxApp extends StatelessWidget {
  // `const` + `super.key`: Flutter puede reutilizar esta instancia
  // en vez de reconstruirla.
  const HybryxApp({super.key});

  // build() describe CÓMO se ve el widget. Flutter lo llama cada vez que
  // necesita pintarlo, así que debe ser rápido y sin efectos secundarios.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HYBRYX Beta', // nombre en el selector de apps recientes
      debugShowCheckedModeBanner: false, // quita la cinta "DEBUG"
      theme: ThemeData(
        useMaterial3: true,
        // fromSeed genera una paleta completa a partir de UN color.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5A1F), // naranja HYBRYX
          brightness: Brightness.dark, // modo oscuro: típico en apps de gym
        ),
      ),
      home: const HomeShell(),
    );
  }
}
