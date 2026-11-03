// ─────────────────────────────────────────────────────────────────────
// live_workout_screen.dart — El corazón de la beta: registrar el entreno.
//
//  • Cronómetro general desde que empezó el entreno.
//  • Por ejercicio: series con kg, reps y ✓ (hecha).
//  • Tipos: W = warm-up, 1/2/3 = normales, D = drop set (debajo de su serie).
//  • Al marcar ✓ arranca el descanso (90 s) con +15 s y Skip.
//  • TODO se guarda en SQLite al instante; "atrás" no pierde nada.
// ─────────────────────────────────────────────────────────────────────

// dart:async trae Timer (para cronómetro y descanso).
import 'dart:async';

import 'package:flutter/material.dart';
// services.dart: HapticFeedback (vibración) y TextInputFormatter.
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'exercise_library_screen.dart';

/// Acciones del menú de cada serie (al tocar su etiqueta W/1/D).
enum _SetAction { addDrop, toWarmup, toNormal, delete }

/// Formatea una duración como 05:07 o 1:05:07.
/// remainder(60) = módulo: minutos que sobran después de las horas.
/// padLeft(2, '0') = rellena con cero a la izquierda: 5 -> "05".
String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class LiveWorkoutScreen extends StatefulWidget {
  final int workoutId;
  const LiveWorkoutScreen({super.key, required this.workoutId});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  static const _defaultRestSeconds = 90;
  final _repo = Repo.instance;

  Workout? _workout;
  List<WorkoutExercise> _exercises = [];
  bool _loading = true;

  // ── Descanso ──
  Timer? _restTimer; // null = no hay descanso corriendo
  int _restLeft = 0; // segundos que faltan

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Un Timer.periodic sigue disparando aunque la pantalla se cierre.
  // Si no lo cancelamos, llamaría setState sobre un State muerto = crash.
  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  /// Recarga todo desde la DB. Se usa tras agregar/borrar cosas
  /// (cambios de ESTRUCTURA). Para escribir kg/reps NO recargamos:
  /// solo guardamos (ver _SetRow), así el teclado no se cierra.
  Future<void> _load() async {
    final workout = await _repo.getWorkout(widget.workoutId);
    final exercises = await _repo.getWorkoutExercises(widget.workoutId);
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _exercises = exercises;
      _loading = false;
    });
  }

  // ═════════════════════ Descanso ═════════════════════

  void _startRest([int seconds = _defaultRestSeconds]) {
    _restTimer?.cancel(); // si ya había uno, lo reiniciamos
    setState(() => _restLeft = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restLeft <= 1) {
        timer.cancel();
        HapticFeedback.heavyImpact(); // vibra: "¡a la siguiente serie!"
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
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
          builder: (_) => const ExerciseLibraryScreen(pickMode: true)),
    );
    if (picked == null || picked.isEmpty) return;
    for (final e in picked) {
      await _repo.addExerciseToWorkout(widget.workoutId, e.id!);
    }
    await _load();
  }

  Future<void> _removeExercise(WorkoutExercise we) async {
    final ok = await confirm(context, title: 'Remove ${we.exerciseName}?');
    if (!ok) return;
    await _repo.removeWorkoutExercise(we.id);
    await _load();
  }

  /// Nueva serie normal o warm-up. Una normal copia kg/reps de la última
  /// normal: en el gym casi siempre repites el mismo peso.
  Future<void> _addSet(WorkoutExercise we, SetType type) async {
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
    // switch sobre enum: el compilador avisa si olvidas un caso.
    switch (action) {
      case _SetAction.addDrop:
        await _repo.addSet(set.workoutExerciseId, SetType.drop,
            parentSetId: set.id);
      case _SetAction.toWarmup:
        set.type = SetType.warmup;
        await _repo.updateSet(set);
      case _SetAction.toNormal:
        set.type = SetType.normal;
        await _repo.updateSet(set);
      case _SetAction.delete:
        await _repo.deleteSet(set.id); // CASCADE borra sus drops
    }
    // (En Dart 3 los `case` no necesitan `break`.)
    await _load();
  }

  Future<void> _toggleDone(WorkoutSet set) async {
    setState(() => set.done = !set.done); // UI primero: se siente instantáneo
    await _repo.updateSet(set);
    if (set.done) _startRest();
  }

  Future<void> _finish() async {
    // expand() aplana: lista de ejercicios -> lista de TODAS las series.
    final doneCount =
        _exercises.expand((e) => e.sets).where((s) => s.done).length;
    final ok = await confirm(
      context,
      title: 'Finish workout?',
      message: doneCount == 0
          ? 'No sets are marked as done.'
          : '$doneCount sets completed.',
      confirmLabel: 'Finish',
    );
    if (!ok) return;
    await _repo.finishWorkout(widget.workoutId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ═════════════════════ UI ═════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final workout = _workout!; // `!`: después de cargar nunca es null

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name),
            // Widget aparte para el reloj: así SOLO él se repinta cada
            // segundo, no la pantalla entera con todos los campos.
            _ElapsedClock(startedAt: workout.startedAt),
          ],
        ),
        actions: [
          FilledButton(onPressed: _finish, child: const Text('Finish')),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        // Margen inferior grande para que el botón flotante no tape la
        // última serie.
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
        children: [
          if (_exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Tap "Add exercise" to begin.')),
            ),
          for (final we in _exercises)
            _ExerciseCard(
              // key por id: si se borra un ejercicio de en medio, Flutter
              // sabe exactamente qué tarjeta quitar (y no mezcla campos).
              key: ValueKey(we.id),
              exercise: we,
              onAddSet: (type) => _addSet(we, type),
              onRemove: () => _removeExercise(we),
              onSetAction: _onSetAction,
              onToggleDone: _toggleDone,
              onSetEdited: _repo.updateSet,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercises,
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
      // La barra de descanso solo existe mientras hay descanso.
      bottomNavigationBar: _restTimer == null
          ? null
          : _RestBar(
              secondsLeft: _restLeft,
              onAdd15: () => setState(() => _restLeft += 15),
              onSkip: _skipRest,
            ),
    );
  }
}

// ═════════════════════════════ Reloj ═════════════════════════════

/// Muestra el tiempo desde `startedAt`. Calcula contra la hora de inicio
/// guardada (no cuenta "ticks"), por eso es exacto aunque retomes el
/// entreno horas después o la app haya estado cerrada.
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
    // setState vacío = "repíntate" (el texto se recalcula en build).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    return Text(_formatDuration(elapsed),
        style: Theme.of(context).textTheme.bodySmall);
  }
}

// ═════════════════════════ Barra de descanso ═════════════════════════

class _RestBar extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onAdd15; // VoidCallback = void Function()
  final VoidCallback onSkip;

  const _RestBar({
    required this.secondsLeft,
    required this.onAdd15,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      // SafeArea: evita que la barra quede debajo de la barra de gestos
      // del sistema en celulares sin botones.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.timer),
              const SizedBox(width: 12),
              Text('Rest ${_formatDuration(Duration(seconds: secondsLeft))}',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(), // empuja los botones a la derecha
              TextButton(onPressed: onAdd15, child: const Text('+15s')),
              TextButton(onPressed: onSkip, child: const Text('Skip')),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ Tarjeta de ejercicio ═════════════════════════

/// Stateless: no es dueña de nada. Recibe el ejercicio y "callbacks"
/// (funciones del padre) para avisar qué pasó. Patrón clave en Flutter:
/// los datos bajan (parámetros), los eventos suben (callbacks).
class _ExerciseCard extends StatelessWidget {
  final WorkoutExercise exercise;
  final void Function(SetType type) onAddSet;
  final VoidCallback onRemove;
  final void Function(WorkoutSet set, _SetAction action) onSetAction;
  final void Function(WorkoutSet set) onToggleDone;
  final Future<void> Function(WorkoutSet set) onSetEdited;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.onAddSet,
    required this.onRemove,
    required this.onSetAction,
    required this.onToggleDone,
    required this.onSetEdited,
  });

  /// Qué opciones mostrar en el menú de una serie según su tipo.
  List<_SetAction> _actionsFor(WorkoutSet set) {
    final hasDrops = exercise.sets.any((s) => s.parentSetId == set.id);
    return switch (set.type) {
      SetType.warmup => [_SetAction.toNormal, _SetAction.delete],
      // Una normal con drops no puede pasar a warm-up (no tendría sentido).
      SetType.normal => [
          _SetAction.addDrop,
          if (!hasDrops) _SetAction.toWarmup,
          _SetAction.delete,
        ],
      SetType.drop => [_SetAction.delete],
    };
  }

  @override
  Widget build(BuildContext context) {
    // 1) Series "raíz" (sin padre). Orden: warm-ups primero, luego por
    //    posición. Así un warm-up agregado tarde igual sale arriba.
    final topLevel = exercise.sets.where((s) => s.parentSetId == null).toList()
      ..sort((a, b) {
        // `..` (cascada): llama sort sobre la lista y devuelve la lista.
        final rankA = a.type == SetType.warmup ? 0 : 1;
        final rankB = b.type == SetType.warmup ? 0 : 1;
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.position.compareTo(b.position);
      });

    // 2) Construimos filas: cada raíz seguida de sus drops.
    final rows = <Widget>[];
    var normalNumber = 0; // solo las normales se numeran 1, 2, 3...
    for (final set in topLevel) {
      final String label;
      if (set.type == SetType.warmup) {
        label = 'W';
      } else {
        normalNumber++;
        label = '$normalNumber';
      }
      rows.add(_SetRow(
        key: ValueKey(set.id),
        set: set,
        label: label,
        actions: _actionsFor(set),
        onAction: (a) => onSetAction(set, a),
        onToggleDone: () => onToggleDone(set),
        onEdited: () => onSetEdited(set),
      ));
      // Drops de esta serie (ya vienen ordenados por posición desde SQL).
      for (final drop in exercise.sets.where((s) => s.parentSetId == set.id)) {
        rows.add(_SetRow(
          key: ValueKey(drop.id),
          set: drop,
          label: 'D',
          indent: true,
          actions: _actionsFor(drop),
          onAction: (a) => onSetAction(drop, a),
          onToggleDone: () => onToggleDone(drop),
          onEdited: () => onSetEdited(drop),
        ));
      }
    }

    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(exercise.exerciseName,
                        style: textTheme.titleMedium)),
                IconButton(
                    icon: const Icon(Icons.close), onPressed: onRemove),
              ],
            ),
            // Encabezados de columna, mismos anchos que _SetRow.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const SizedBox(width: 44, child: Text('Set')),
                  Expanded(child: Center(child: Text('kg', style: textTheme.labelMedium))),
                  const SizedBox(width: 8),
                  Expanded(child: Center(child: Text('Reps', style: textTheme.labelMedium))),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            ...rows, // spread: mete todas las filas aquí
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => onAddSet(SetType.normal),
                  icon: const Icon(Icons.add),
                  label: const Text('Set'),
                ),
                TextButton.icon(
                  onPressed: () => onAddSet(SetType.warmup),
                  icon: const Icon(Icons.add),
                  label: const Text('Warm-up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════ Fila de serie ═════════════════════════════

/// Stateful porque cada fila es dueña de sus 2 TextEditingController
/// (kg y reps). El controller guarda el texto y la posición del cursor;
/// si lo recreáramos en cada build, el cursor saltaría al escribir.
class _SetRow extends StatefulWidget {
  final WorkoutSet set;
  final String label; // 'W', '1', '2', 'D'
  final bool indent; // drops van con sangría
  final List<_SetAction> actions;
  final ValueChanged<_SetAction> onAction;
  final VoidCallback onToggleDone;
  final VoidCallback onEdited;

  const _SetRow({
    super.key,
    required this.set,
    required this.label,
    required this.actions,
    required this.onAction,
    required this.onToggleDone,
    required this.onEdited,
    this.indent = false,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _formatWeight(widget.set.weightKg));
    _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  /// 80.0 -> "80"; 82.5 -> "82.5"; null -> "".
  static String _formatWeight(double? w) {
    if (w == null) return '';
    return w == w.roundToDouble() ? w.toInt().toString() : w.toString();
  }

  static String _labelFor(_SetAction a) => switch (a) {
        _SetAction.addDrop => 'Add drop set',
        _SetAction.toWarmup => 'Mark as warm-up',
        _SetAction.toNormal => 'Mark as normal set',
        _SetAction.delete => 'Delete set',
      };

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final colors = Theme.of(context).colorScheme;

    return Container(
      // Fondo verdoso cuando la serie está hecha: feedback visual rápido.
      color: set.done ? colors.tertiaryContainer : null,
      padding: EdgeInsets.only(left: widget.indent ? 16 : 0, right: 8, top: 2, bottom: 2),
      child: Row(
        children: [
          // ── Etiqueta + menú ──
          SizedBox(
            width: widget.indent ? 28 : 44,
            child: PopupMenuButton<_SetAction>(
              tooltip: 'Set options',
              onSelected: widget.onAction,
              itemBuilder: (_) => [
                for (final a in widget.actions)
                  PopupMenuItem(value: a, child: Text(_labelFor(a))),
              ],
              child: Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  // Warm-up y drop en otro color para distinguirlos.
                  color: set.type == SetType.normal ? null : colors.primary,
                ),
              ),
            ),
          ),
          // ── kg ──
          Expanded(
            child: TextField(
              controller: _weight,
              textAlign: TextAlign.center,
              // Teclado numérico con punto decimal.
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Solo dígitos, punto y coma (teclados en español usan coma).
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                  isDense: true, hintText: '-', border: OutlineInputBorder()),
              onChanged: (text) {
                // "82,5" -> "82.5" -> 82.5. tryParse da null si no es número.
                set.weightKg = double.tryParse(text.replaceAll(',', '.'));
                widget.onEdited(); // guarda en SQLite
              },
            ),
          ),
          const SizedBox(width: 8),
          // ── reps ──
          Expanded(
            child: TextField(
              controller: _reps,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  isDense: true, hintText: '-', border: OutlineInputBorder()),
              onChanged: (text) {
                set.reps = int.tryParse(text);
                widget.onEdited();
              },
            ),
          ),
          // ── ✓ ──
          IconButton(
            onPressed: widget.onToggleDone,
            icon: Icon(
              set.done ? Icons.check_circle : Icons.check_circle_outline,
              color: set.done ? colors.tertiary : null,
            ),
          ),
        ],
      ),
    );
  }
}
