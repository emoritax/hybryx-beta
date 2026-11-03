// ─────────────────────────────────────────────────────────────────────
// live_workout_screen.dart — Registrar el entreno en vivo.
//
//  • Cronómetro + barra de progreso (series hechas / total) animada
//  • Series: W = calentamiento, 1/2/3 = normales, D = drop set
//  • ✓ -> la fila se pinta lima, vibra y arranca el descanso
//  • PR EN VIVO: si una serie supera tu mejor 1RM histórico, aparece la
//    etiqueta PR, vibra fuerte y sale un aviso
//  • Gesto: desliza una serie a la izquierda para borrarla
//  • Terminar -> pantalla de celebración con confeti
// ─────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/progress.dart';
import '../data/repo.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';
import '../widgets/dialogs.dart';
import 'exercise_picker_screen.dart';
import 'workout_summary_screen.dart';

/// Acciones del menú de una serie (al tocar su etiqueta W/1/D).
enum _SetAction { addDrop, toWarmup, toNormal, delete }

class LiveWorkoutScreen extends StatefulWidget {
  final int workoutId;
  const LiveWorkoutScreen({super.key, required this.workoutId});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  static const _restSeconds = 90;
  final _repo = Repo.instance;

  Workout? _workout;
  List<WorkoutExercise> _exercises = [];
  // Mejor 1RM estimado de cada ejercicio ANTES de este entreno.
  Map<int, double> _historicBest = {};
  bool _loading = true;

  Timer? _restTimer;
  int _restLeft = 0;
  int _restTotal = _restSeconds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final workout = await _repo.getWorkout(widget.workoutId);
    final exercises = await _repo.getWorkoutExercises(widget.workoutId);
    final best =
        await _repo.getBestE1rmByExercise(excludeWorkoutId: widget.workoutId);
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _exercises = exercises;
      _historicBest = best;
      _loading = false;
    });
  }

  // ═════════════════════ PRs en vivo ═════════════════════

  /// ids de las series que HOY son récord. Una serie es PR si:
  ///  - está hecha, no es calentamiento y tiene peso y reps,
  ///  - su 1RM estimado supera tu mejor marca anterior (que debe existir:
  ///    la primera vez es tu línea base),
  ///  - y es la MEJOR del ejercicio hoy (un PR por ejercicio, no tres).
  Set<int> _prSetIds() {
    final ids = <int>{};
    for (final we in _exercises) {
      final previous = _historicBest[we.exerciseId] ?? 0;
      if (previous <= 0) continue;
      WorkoutSet? top;
      var topValue = 0.0;
      for (final s in we.sets) {
        final w = s.weightKg ?? 0;
        final r = s.reps ?? 0;
        if (!s.done || s.type == SetType.warmup || w <= 0 || r <= 0) continue;
        final v = estimate1rm(w, r);
        if (v > topValue) {
          topValue = v;
          top = s;
        }
      }
      if (top != null && topValue > previous) ids.add(top.id);
    }
    return ids;
  }

  // ═════════════════════ Descanso ═════════════════════

  void _startRest() {
    _restTimer?.cancel();
    setState(() {
      _restTotal = _restSeconds;
      _restLeft = _restSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restLeft <= 1) {
        timer.cancel();
        HapticFeedback.heavyImpact(); // "¡a la siguiente serie!"
        setState(() {
          _restLeft = 0;
          _restTimer = null;
        });
      } else {
        setState(() => _restLeft--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _restLeft = 0;
      _restTimer = null;
    });
  }

  // ═════════════════════ Acciones ═════════════════════

  Future<void> _addExercises() async {
    final picked = await Navigator.push<List<Exercise>>(context,
        MaterialPageRoute(builder: (_) => const ExercisePickerScreen()));
    if (picked == null || picked.isEmpty) return;
    for (final e in picked) {
      await _repo.addExerciseToWorkout(widget.workoutId, e.id!);
    }
    await _load();
  }

  Future<void> _removeExercise(WorkoutExercise we) async {
    final ok = await confirm(context, title: '¿Quitar ${we.exerciseName}?');
    if (!ok) return;
    await _repo.removeWorkoutExercise(we.id);
    await _load();
  }

  /// Nueva serie. Una normal copia kg/reps de la última normal.
  Future<void> _addSet(WorkoutExercise we, SetType type) async {
    HapticFeedback.selectionClick();
    double? weight;
    int? reps;
    if (type == SetType.normal) {
      final normals = we.sets.where((s) => s.type == SetType.normal);
      if (normals.isNotEmpty) {
        weight = normals.last.weightKg;
        reps = normals.last.reps;
      }
    }
    await _repo.addSet(we.id, type, weightKg: weight, reps: reps);
    await _load();
  }

  Future<void> _onSetAction(WorkoutSet set, _SetAction action) async {
    switch (action) {
      case _SetAction.addDrop:
        // El drop arranca con 80% del peso de su serie (redondeado a 0,5).
        final w = set.weightKg;
        await _repo.addSet(set.workoutExerciseId, SetType.drop,
            parentSetId: set.id,
            weightKg: w == null ? null : (w * 0.8 * 2).round() / 2);
      case _SetAction.toWarmup:
        set.type = SetType.warmup;
        await _repo.updateSet(set);
      case _SetAction.toNormal:
        set.type = SetType.normal;
        await _repo.updateSet(set);
      case _SetAction.delete:
        await _repo.deleteSet(set.id);
    }
    await _load();
  }

  /// Borrado por gesto. Quitamos la fila del modelo YA (síncrono) para
  /// que Dismissible no se queje, y luego borramos en la DB.
  Future<void> _dismissSet(WorkoutExercise we, WorkoutSet set) async {
    HapticFeedback.mediumImpact();
    setState(() => we.sets
        .removeWhere((s) => s.id == set.id || s.parentSetId == set.id));
    await _repo.deleteSet(set.id); // CASCADE borra sus drops
  }

  Future<void> _toggleDone(WorkoutSet set) async {
    final before = _prSetIds();
    setState(() => set.done = !set.done);
    await _repo.updateSet(set);
    if (!set.done) return;

    final isNewPr = _prSetIds().contains(set.id) && !before.contains(set.id);
    if (isNewPr) {
      HapticFeedback.heavyImpact();
      _celebratePr(set);
    } else {
      HapticFeedback.lightImpact();
    }
    _startRest();
  }

  void _celebratePr(WorkoutSet set) {
    final e1rm = estimate1rm(set.weightKg!, set.reps!).round();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: Hx.lime,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Hx.bg),
            const SizedBox(width: 10),
            Text('¡NUEVO PR! · 1RM est. $e1rm kg',
                style: Hx.disp(20, color: Hx.bg)),
          ],
        ),
      ));
  }

  Future<void> _finish() async {
    final doneCount =
        _exercises.expand((e) => e.sets).where((s) => s.done).length;
    final ok = await confirm(
      context,
      title: '¿Terminar entreno?',
      message: doneCount == 0
          ? 'No has marcado ninguna serie como hecha.'
          : '$doneCount series completadas.',
      confirmLabel: 'Terminar',
      destructive: false,
    );
    if (!ok) return;
    // Foto del progreso ANTES de terminar: el resumen la compara con la
    // de después para mostrar la XP ganada y si subiste de nivel.
    final before = await _repo.getProgress();
    await _repo.finishWorkout(widget.workoutId);
    if (!mounted) return;
    // pushReplacement: "atrás" desde el resumen vuelve a la app, no aquí.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          WorkoutSummaryScreen(workoutId: widget.workoutId, before: before),
    ));
  }

  // ═════════════════════ UI ═════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final workout = _workout!;
    final allSets = _exercises.expand((e) => e.sets).toList();
    final done = allSets.where((s) => s.done).length;
    final prIds = _prSetIds();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Minimizar (sigue en curso)',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name.toUpperCase(), style: Hx.disp(22)),
            _ElapsedClock(startedAt: workout.startedAt),
          ],
        ),
        actions: [
          FilledButton(onPressed: _finish, child: const Text('Terminar')),
          const SizedBox(width: 12),
        ],
        // Barra de progreso pegada bajo la AppBar.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: allSets.isEmpty ? 0 : done / allSets.length),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, f, _) => LinearProgressIndicator(
              value: f,
              minHeight: 4,
              backgroundColor: Hx.line,
              color: Hx.lime,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        children: [
          if (_exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: Text('Toca "Añadir ejercicio" para empezar.',
                      style: TextStyle(color: Hx.muted))),
            ),
          for (final we in _exercises)
            _ExerciseCard(
              key: ValueKey(we.id),
              exercise: we,
              prSetIds: prIds,
              onAddSet: (type) => _addSet(we, type),
              onRemove: () => _removeExercise(we),
              onSetAction: _onSetAction,
              onToggleDone: _toggleDone,
              onDismiss: (s) => _dismissSet(we, s),
              onSetEdited: (s) {
                _repo.updateSet(s);
                // Si la serie ya estaba hecha, editar kg/reps puede
                // crear o quitar un PR: repintamos para recalcularlo.
                if (s.done) setState(() {});
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Hx.surface2,
        foregroundColor: Hx.lime,
        onPressed: _addExercises,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir ejercicio',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      // La barra de descanso entra deslizándose desde abajo.
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => SizeTransition(
            sizeFactor: anim, axisAlignment: -1, child: child),
        child: _restTimer == null
            ? const SizedBox.shrink()
            : _RestBar(
                secondsLeft: _restLeft,
                total: _restTotal,
                onAdd15: () => setState(() {
                  _restLeft += 15;
                  _restTotal += 15;
                }),
                onSkip: _skipRest,
              ),
      ),
    );
  }
}

// ═════════════════════════════ Reloj ═════════════════════════════

/// Se repinta solo él cada segundo (no toda la pantalla). Calcula contra
/// la hora de inicio guardada: exacto aunque retomes horas después.
class _ElapsedClock extends StatefulWidget {
  final DateTime startedAt;
  const _ElapsedClock({required this.startedAt});

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(formatDuration(DateTime.now().difference(widget.startedAt)),
        style: const TextStyle(fontSize: 12, color: Hx.muted));
  }
}

// ═════════════════════════ Barra de descanso ═════════════════════════

class _RestBar extends StatelessWidget {
  final int secondsLeft;
  final int total;
  final VoidCallback onAdd15;
  final VoidCallback onSkip;

  const _RestBar({
    required this.secondsLeft,
    required this.total,
    required this.onAdd15,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Hx.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación LINEAL de 1 s entre ticks: la barra baja suave en
            // vez de a saltos de un segundo.
            TweenAnimationBuilder<double>(
              tween: Tween(end: secondsLeft / total),
              duration: const Duration(seconds: 1),
              builder: (context, f, _) => LinearProgressIndicator(
                value: f,
                minHeight: 3,
                backgroundColor: Hx.line,
                color: Hx.orange,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Hx.orange),
                  const SizedBox(width: 10),
                  Text('DESCANSO', style: Hx.label(color: Hx.orange)),
                  const SizedBox(width: 10),
                  Text(formatDuration(Duration(seconds: secondsLeft)),
                      style: Hx.disp(28)),
                  const Spacer(),
                  TextButton(onPressed: onAdd15, child: const Text('+15s')),
                  TextButton(onPressed: onSkip, child: const Text('Saltar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ Tarjeta de ejercicio ═════════════════════════

/// Stateless: los datos bajan (parámetros), los eventos suben (callbacks).
class _ExerciseCard extends StatelessWidget {
  final WorkoutExercise exercise;
  final Set<int> prSetIds;
  final void Function(SetType type) onAddSet;
  final VoidCallback onRemove;
  final void Function(WorkoutSet set, _SetAction action) onSetAction;
  final void Function(WorkoutSet set) onToggleDone;
  final void Function(WorkoutSet set) onDismiss;
  final void Function(WorkoutSet set) onSetEdited;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.prSetIds,
    required this.onAddSet,
    required this.onRemove,
    required this.onSetAction,
    required this.onToggleDone,
    required this.onDismiss,
    required this.onSetEdited,
  });

  List<_SetAction> _actionsFor(WorkoutSet set) {
    final hasDrops = exercise.sets.any((s) => s.parentSetId == set.id);
    return switch (set.type) {
      SetType.warmup => [_SetAction.toNormal, _SetAction.delete],
      SetType.normal => [
          _SetAction.addDrop,
          if (!hasDrops) _SetAction.toWarmup,
          _SetAction.delete,
        ],
      SetType.drop => [_SetAction.delete],
    };
  }

  Widget _row(WorkoutSet set, String label, {bool indent = false}) {
    return _SetRow(
      key: ValueKey(set.id),
      set: set,
      label: label,
      indent: indent,
      isPr: prSetIds.contains(set.id),
      actions: _actionsFor(set),
      onAction: (a) => onSetAction(set, a),
      onToggleDone: () => onToggleDone(set),
      onEdited: () => onSetEdited(set),
      onDismiss: () => onDismiss(set),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Raíces (sin padre): calentamientos primero, luego por posición.
    final topLevel = exercise.sets.where((s) => s.parentSetId == null).toList()
      ..sort((a, b) {
        final rankA = a.type == SetType.warmup ? 0 : 1;
        final rankB = b.type == SetType.warmup ? 0 : 1;
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.position.compareTo(b.position);
      });

    final rows = <Widget>[];
    var n = 0;
    for (final set in topLevel) {
      final String label;
      if (set.type == SetType.warmup) {
        label = 'W';
      } else {
        n++;
        label = '$n';
      }
      rows.add(_row(set, label));
      for (final drop in exercise.sets.where((s) => s.parentSetId == set.id)) {
        rows.add(_row(drop, 'D', indent: true));
      }
    }

    final doneHere = exercise.sets.where((s) => s.done).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: Hx.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(exercise.exerciseName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16))),
              Text('$doneHere/${exercise.sets.length}',
                  style: Hx.disp(16,
                      color: doneHere == exercise.sets.length &&
                              exercise.sets.isNotEmpty
                          ? Hx.lime
                          : Hx.muted)),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, color: Hx.dim),
                  onPressed: onRemove),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: Row(
              children: [
                SizedBox(width: 44, child: Text('SERIE', style: Hx.label())),
                Expanded(
                    child: Center(child: Text('KG', style: Hx.label()))),
                const SizedBox(width: 8),
                Expanded(
                    child: Center(child: Text('REPS', style: Hx.label()))),
                const SizedBox(width: 48),
              ],
            ),
          ),
          ...rows,
          Row(
            children: [
              TextButton.icon(
                onPressed: () => onAddSet(SetType.normal),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Serie'),
              ),
              TextButton.icon(
                onPressed: () => onAddSet(SetType.warmup),
                icon: const Icon(Icons.add_rounded, size: 18, color: Hx.muted),
                label: const Text('Calentamiento',
                    style: TextStyle(color: Hx.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════ Fila de serie ═════════════════════════════

/// Stateful: es dueña de sus TextEditingController (el cursor no salta).
class _SetRow extends StatefulWidget {
  final WorkoutSet set;
  final String label;
  final bool indent;
  final bool isPr;
  final List<_SetAction> actions;
  final ValueChanged<_SetAction> onAction;
  final VoidCallback onToggleDone;
  final VoidCallback onEdited;
  final VoidCallback onDismiss;

  const _SetRow({
    super.key,
    required this.set,
    required this.label,
    required this.isPr,
    required this.actions,
    required this.onAction,
    required this.onToggleDone,
    required this.onEdited,
    required this.onDismiss,
    this.indent = false,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weight =
      TextEditingController(text: kg(widget.set.weightKg));
  late final TextEditingController _reps =
      TextEditingController(text: widget.set.reps?.toString() ?? '');

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  static String _labelFor(_SetAction a) => switch (a) {
        _SetAction.addDrop => 'Añadir drop set',
        _SetAction.toWarmup => 'Marcar como calentamiento',
        _SetAction.toNormal => 'Marcar como serie normal',
        _SetAction.delete => 'Borrar serie',
      };

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final labelColor = switch (set.type) {
      SetType.warmup => Hx.orange,
      SetType.drop => Hx.violet,
      SetType.normal => Hx.text,
    };

    // Dismissible: deslizar a la izquierda = borrar la serie.
    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Hx.danger,
        child: const Icon(Icons.delete_outline, color: Hx.bg),
      ),
      // AnimatedContainer: al marcar ✓ el fondo pasa a lima suavemente.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.only(
            left: widget.indent ? 16 : 0, right: 8, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: set.done ? Hx.limeTint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: widget.indent ? 28 : 44,
              child: PopupMenuButton<_SetAction>(
                tooltip: 'Opciones de la serie',
                color: Hx.surface2,
                onSelected: widget.onAction,
                itemBuilder: (_) => [
                  for (final a in widget.actions)
                    PopupMenuItem(value: a, child: Text(_labelFor(a))),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label, style: Hx.disp(20, color: labelColor)),
                    // Etiqueta PR que aparece con un "pop" elástico.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (c, a) => ScaleTransition(
                          scale: CurvedAnimation(
                              parent: a, curve: Curves.elasticOut),
                          child: c),
                      child: widget.isPr
                          ? Container(
                              key: const ValueKey('pr'),
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                  color: Hx.lime,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('PR',
                                  style: Hx.disp(11, color: Hx.bg)),
                            )
                          : const SizedBox.shrink(key: ValueKey('no')),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _weight,
                textAlign: TextAlign.center,
                style: Hx.disp(20, weight: FontWeight.w700),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(hintText: '–'),
                onChanged: (text) {
                  // "82,5" -> 82.5 (teclados en español usan coma).
                  set.weightKg = double.tryParse(text.replaceAll(',', '.'));
                  widget.onEdited();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _reps,
                textAlign: TextAlign.center,
                style: Hx.disp(20, weight: FontWeight.w700),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: '–'),
                onChanged: (text) {
                  set.reps = int.tryParse(text);
                  widget.onEdited();
                },
              ),
            ),
            // ✓ con "pop" de escala al marcar.
            IconButton(
              onPressed: widget.onToggleDone,
              icon: AnimatedScale(
                scale: set.done ? 1.15 : 1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(
                  set.done
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 28,
                  color: set.done ? Hx.lime : Hx.dim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
