// ─────────────────────────────────────────────────────────────────────
// train_screen.dart — Pestaña central. Desde aquí:
//   • Retomar o descartar un entreno en curso, o
//   • Empezar uno vacío, o uno a partir de una rutina.
// Solo puede haber UN entreno activo a la vez.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'live_workout_screen.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  final _repo = Repo.instance;
  Workout? _active; // entreno sin terminar, si hay
  List<Routine> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Dos consultas independientes: podríamos correrlas en paralelo con
    // Future.wait, pero en SQLite local la diferencia es imperceptible.
    final active = await _repo.getActiveWorkout();
    final routines = await _repo.getRoutines();
    if (!mounted) return;
    setState(() {
      _active = active;
      _routines = routines;
      _loading = false;
    });
  }

  Future<void> _start({Routine? routine}) async {
    final id = await _repo.startWorkout(routine: routine);
    await _open(id);
  }

  Future<void> _open(int workoutId) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveWorkoutScreen(workoutId: workoutId)),
    );
    // Al volver: si terminó, ya no hay activo; si salió con "atrás",
    // sigue activo y aparece la tarjeta "Resume".
    await _load();
  }

  Future<void> _discard(Workout w) async {
    final ok = await confirm(context,
        title: 'Discard workout?',
        message: 'All sets of this workout will be deleted.',
        confirmLabel: 'Discard');
    if (!ok) return;
    await _repo.discardWorkout(w.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active; // copia local: Dart puede "promoverla" a no-null

    return Scaffold(
      appBar: AppBar(title: const Text('HYBRYX')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // `if (...) A else ...[B, C]`: if dentro de una lista.
                // `...` (spread) "desempaca" una lista dentro de otra.
                if (active != null)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Workout in progress',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(active.name),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: () => _discard(active),
                                  child: const Text('Discard')),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _open(active.id),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Resume'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                    onPressed: () => _start(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start empty workout'),
                  ),
                  const SizedBox(height: 24),
                  Text('Start from a routine',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_routines.isEmpty)
                    const Text('Create a routine in the Routines tab.'),
                  for (final r in _routines)
                    Card(
                      child: ListTile(
                        title: Text(r.name),
                        subtitle: Text('${r.itemCount} exercises'),
                        trailing: const Icon(Icons.play_circle),
                        // Rutina vacía = no tiene sentido iniciarla.
                        onTap: r.itemCount == 0
                            ? null
                            : () => _start(routine: r),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
