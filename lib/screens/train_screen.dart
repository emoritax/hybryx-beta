// ─────────────────────────────────────────────────────────────────────
// train_screen.dart — Pestaña central "Entrenar" (diseño 3 · principal).
//
//  • Encabezado: logo, @alias, nivel + barra de XP, racha 🔥 (datos vivos)
//  • Entreno en curso (si hay) con punto que late
//  • "Rutina de hoy": sugiere la SIGUIENTE en tu rotación
//  • Botón 3D INICIAR ENTRENO
//  • "Esta semana": 7 días que se encienden en cascada
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';
import '../widgets/dialogs.dart';
import '../widgets/motion.dart';
import 'live_workout_screen.dart';

class TrainScreen extends StatefulWidget {
  final VoidCallback onGoToRoutines;
  const TrainScreen({super.key, required this.onGoToRoutines});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  final _repo = Repo.instance;

  bool _loading = true;
  String _alias = '';
  Progress? _progress;
  Workout? _active;
  List<Routine> _routines = [];
  int? _suggestedId; // rutina sugerida por la rotación
  int? _pickedId; // rutina que elegiste con "Cambiar" (tiene prioridad)
  List<RoutineItem> _items = []; // ejercicios de la rutina mostrada

  @override
  void initState() {
    super.initState();
    _load();
    // Suscribirse a la "campana" del repo: cualquier cambio -> recargar.
    _repo.changes.addListener(_load);
  }

  @override
  void dispose() {
    // Siempre desuscribirse; si no, el repo llamaría a un State muerto.
    _repo.changes.removeListener(_load);
    super.dispose();
  }

  /// La rutina que se muestra: la elegida o, si no, la sugerida.
  Routine? get _routine {
    final id = _pickedId ?? _suggestedId;
    // firstWhere con orElse no sirve para devolver null en Dart 3 con
    // tipos no-nulos; filtramos y tomamos la primera si existe.
    final found = _routines.where((r) => r.id == id);
    return found.isEmpty ? null : found.first;
  }

  Future<void> _load() async {
    final alias = await _repo.getAlias();
    final progress = await _repo.getProgress();
    final active = await _repo.getActiveWorkout();
    // Solo rutinas con ejercicios sirven para entrenar.
    final routines =
        (await _repo.getRoutines()).where((r) => r.itemCount > 0).toList();

    // ── Rotación: la siguiente después de la última que usaste ──
    int? suggested;
    if (routines.isNotEmpty) {
      final lastId = await _repo.getLastUsedRoutineId();
      final i = routines.indexWhere((r) => r.id == lastId);
      // indexWhere da -1 si no la encuentra: (-1 + 1) % n = 0 -> la primera.
      suggested = routines[(i + 1) % routines.length].id;
    }
    // Si la rutina elegida ya no existe (la borraste), olvidamos la elección.
    if (!routines.any((r) => r.id == _pickedId)) _pickedId = null;

    final shownId = _pickedId ?? suggested;
    final items =
        shownId == null ? <RoutineItem>[] : await _repo.getRoutineItems(shownId);

    if (!mounted) return;
    setState(() {
      _alias = alias;
      _progress = progress;
      _active = active;
      _routines = routines;
      _suggestedId = suggested;
      _items = items;
      _loading = false;
    });
  }

  // ═════════════════════ Acciones ═════════════════════

  Future<void> _start({Routine? routine}) async {
    final id = await _repo.startWorkout(routine: routine);
    await _openWorkout(id);
  }

  Future<void> _openWorkout(int id) async {
    if (!mounted) return;
    await Navigator.of(context).push(_slideUp(LiveWorkoutScreen(workoutId: id)));
  }

  /// Transición propia: la pantalla de entreno sube desde abajo.
  static Route<void> _slideUp(Widget page) => PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );

  Future<void> _discard(Workout w) async {
    final ok = await confirm(context,
        title: '¿Descartar entreno?',
        message: 'Se borran todas sus series.',
        confirmLabel: 'Descartar');
    if (ok) await _repo.deleteWorkout(w.id);
  }

  /// Hoja inferior para elegir otra rutina.
  Future<void> _pickRoutine() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true, // alto justo para su contenido
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('ELIGE RUTINA', style: Hx.label()),
            const SizedBox(height: 8),
            for (final r in _routines)
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                selected: r.id == _routine?.id,
                selectedTileColor: Hx.limeTint,
                selectedColor: Hx.lime,
                title: Text(r.name,
                    style: Hx.disp(22, weight: FontWeight.w700)),
                subtitle: Text('${r.itemCount} ejercicios',
                    style: const TextStyle(color: Hx.muted)),
                onTap: () => Navigator.pop(ctx, r.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      _pickedId = picked;
      await _load();
    }
  }

  // ═════════════════════ UI ═════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final p = _progress!;
    final active = _active;
    final routine = _routine;

    // Cada sección va envuelta en FadeSlideIn con su índice -> cascada.
    var i = 0;
    Widget step(Widget w) => FadeSlideIn(index: i++, child: w);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        step(_header(p)),
        const SizedBox(height: 16),
        if (active != null) ...[
          step(_activeCard(active)),
          const SizedBox(height: 16),
        ],
        step(routine == null ? _noRoutineCard() : _todayCard(routine)),
        const SizedBox(height: 18),
        if (active == null)
          step(PushButton(
            title: 'INICIAR ENTRENO',
            subtitle: routine == null ? 'Entreno libre' : routine.name,
            onTap: () => _start(routine: routine),
          )),
        if (active == null && routine != null) ...[
          const SizedBox(height: 10),
          step(Center(
            child: TextButton.icon(
              onPressed: () => _start(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('o entreno libre'),
            ),
          )),
        ],
        const SizedBox(height: 16),
        step(_weekCard(p)),
      ],
    );
  }

  Widget _header(Progress p) {
    return Row(
      children: [
        const HxLogo(size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@$_alias',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Row(
                children: [
                  LevelBadge(level: p.level),
                  const SizedBox(width: 8),
                  Expanded(child: AnimatedBar(fraction: p.levelFraction)),
                  const SizedBox(width: 8),
                  Text('${thousands(p.xpIntoLevel)}/${thousands(p.xpForLevel)} XP',
                      style: const TextStyle(fontSize: 11, color: Hx.muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Racha semanal con fuego.
        Tooltip(
          message: 'Semanas seguidas entrenando',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: Hx.orangeTint, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 18, color: Hx.orange),
                const SizedBox(width: 2),
                AnimatedCount(
                    value: p.weekStreak,
                    style: const TextStyle(
                        color: Hx.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _activeCard(Workout w) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Hx.card(radius: 20, border: Hx.lime),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const PulseDot(),
            const SizedBox(width: 8),
            Text('ENTRENO EN CURSO', style: Hx.label(color: Hx.lime)),
            const Spacer(),
            Text(timeAgo(w.startedAt, DateTime.now()),
                style: const TextStyle(fontSize: 12, color: Hx.muted)),
          ]),
          const SizedBox(height: 8),
          Text(w.name.toUpperCase(), style: Hx.disp(30)),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                  onPressed: () => _discard(w),
                  child: const Text('Descartar',
                      style: TextStyle(color: Hx.muted))),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openWorkout(w.id),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Continuar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayCard(Routine r) {
    final totalSets = _items.fold<int>(0, (sum, it) => sum + it.targetSets);
    // Estimación: ~2,5 min por serie (serie + descanso).
    final minutes = (totalSets * 2.5).round();
    const maxChips = 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Hx.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_pickedId == null ? 'RUTINA DE HOY' : 'RUTINA ELEGIDA',
                  style: Hx.label(color: Hx.lime)),
              const Spacer(),
              if (_routines.length > 1)
                GestureDetector(
                  onTap: _pickRoutine,
                  child: const Text('Cambiar',
                      style: TextStyle(
                          color: Hx.lime,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // AnimatedSwitcher: al cambiar de rutina el título hace fade.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(r.name.toUpperCase(),
                key: ValueKey(r.id), style: Hx.disp(36)),
          ),
          const SizedBox(height: 6),
          Text('${_items.length} ejercicios · $totalSets series · ~$minutes min',
              style: const TextStyle(fontSize: 13, color: Hx.muted)),
          const SizedBox(height: 12),
          // Wrap: los chips bajan de línea si no caben.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final it in _items.take(maxChips)) _chip(it.exerciseName),
              if (_items.length > maxChips)
                _chip('+${_items.length - maxChips}', muted: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool muted = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: Hx.line, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: muted ? Hx.muted : Hx.text)),
      );

  Widget _noRoutineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: Hx.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ARMA TU MAZO', style: Hx.label(color: Hx.lime)),
          const SizedBox(height: 10),
          Text('CREA TU PRIMERA RUTINA', style: Hx.disp(32)),
          const SizedBox(height: 6),
          const Text(
              'Elige ejercicios del catálogo y HYBRYX te propondrá la rutina de cada día.',
              style: TextStyle(fontSize: 13, color: Hx.muted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onGoToRoutines,
            icon: const Icon(Icons.style_outlined),
            label: const Text('Ir a Rutinas'),
          ),
        ],
      ),
    );
  }

  Widget _weekCard(Progress p) {
    final todayIndex = DateTime.now().weekday - 1; // lunes = 0
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: Hx.card(),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Esta semana',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Text(
                  '${p.sessionsThisWeek} ${p.sessionsThisWeek == 1 ? 'sesión' : 'sesiones'}',
                  style: const TextStyle(fontSize: 13, color: Hx.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: d == 0 ? 0 : 6),
                    // Cada día entra con retraso propio: se "encienden".
                    child: FadeSlideIn(
                      index: d,
                      dy: 0.4,
                      child: _dayPill(d, p.thisWeek[d], d == todayIndex),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayPill(int d, bool done, bool today) {
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? Hx.lime : (today ? Colors.transparent : Hx.line),
        borderRadius: BorderRadius.circular(10),
        border: today && !done ? Border.all(color: Hx.lime, width: 2) : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 18, color: Hx.bg)
          : Text(weekdayInitials[d],
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: today ? Hx.lime : Hx.dim)),
    );
  }
}
