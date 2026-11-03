// ─────────────────────────────────────────────────────────────────────
// main.dart — Punto de entrada. Arranca con un splash animado del logo
// mientras se abre la base de datos, y luego pasa a la app.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/db.dart';
import 'screens/home_shell.dart';
import 'theme/hx.dart';
import 'widgets/motion.dart';

void main() {
  // Necesario si se llama código nativo ANTES de runApp (aquí: el color
  // de la barra de estado). Inicializa el puente Flutter <-> Android.
  WidgetsFlutterBinding.ensureInitialized();
  // Barra de estado y de navegación del sistema en tonos oscuros.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Hx.navBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HybryxApp());
}

class HybryxApp extends StatelessWidget {
  const HybryxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HYBRYX',
      debugShowCheckedModeBanner: false,
      theme: Hx.theme(),
      home: const SplashScreen(),
    );
  }
}

/// Splash: el logo entra con un "rebote" elástico mientras la DB se abre
/// en paralelo. Esperamos a que terminen AMBAS cosas antes de seguir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Future.wait corre ambas a la vez y espera a la más lenta.
    await Future.wait([
      _c.forward(), // forward() devuelve un Future que termina con la animación
      AppDatabase.instance.database, // abre (o migra) SQLite
    ]);
    if (!mounted) return;
    // pushReplacement: reemplaza el splash (no se puede volver a él con
    // "atrás"). PageRouteBuilder permite una transición propia: fade.
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, _, _) => const HomeShell(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Interval: cada animación usa solo un tramo del tiempo total.
    final logoScale = CurvedAnimation(
        parent: _c, curve: const Interval(0, 0.7, curve: Curves.elasticOut));
    final textFade = CurvedAnimation(
        parent: _c, curve: const Interval(0.45, 1, curve: Curves.easeOut));

    return Scaffold(
      backgroundColor: Colors.black, // igual al fondo del logo
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(scale: logoScale, child: const HxLogo(size: 120)),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: textFade,
              child: Text('HYBRYX', style: Hx.disp(34, spacing: 6, color: Hx.text)),
            ),
          ],
        ),
      ),
    );
  }
}
