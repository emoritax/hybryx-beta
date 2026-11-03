// ─────────────────────────────────────────────────────────────────────
// routine_editor_screen.dart — Armar una rutina: agregar ejercicios,
// reordenarlos (mantén presionado y arrastra), ajustar sets × reps.
//
// Los cambios viven en memoria (_items) hasta que tocas Guardar.
// Si intentas salir con cambios sin guardar, te pregunta.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'exercise_library_screen.dart';

class RoutineEditorScreen extends StatefulWidget {
  final int routineId;
  final String initialName;

  const RoutineEditorScreen({
    super.key,
    required this.routineId,
    required this.initialName,
  });

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  final _repo = Repo.instance;
  // `late` = "la inicializo después, antes de usarla" (en initState).
  late String _name;
  List<RoutineItem> _items = [];
  bool _loading = true;
  bool _dirty = false; // ¿hay cambios sin guardar?

  @override
  void initState() {
    super.initState();
    // `widget` da acceso a los parámetros del StatefulWidget.
    _name = widget.initialName;
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.getRoutineItems(widget.routineId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addExercises() async {
    // push<List<Exercise>>: le decimos qué tipo devolverá la pantalla.
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
          builder: (_) => const ExerciseLibraryScreen(pickMode: true)),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final e in picked) {
        _items.add(RoutineItem(exerciseId: e.id!, exerciseName: e.name));
      }
      _dirty = true;
    });
  }

  Future<void> _rename() async {
    final name =
        await showTextPrompt(context, title: 'Rename routine', initial: _name);
    if (name == null) return;
    await _repo.renameRoutine(widget.routineId, name); // se guarda ya
    if (!mounted) return; // setState en un State destruido lanza error
    setState(() => _name = name);
  }

  Future<void> _save() async {
    await _repo.saveRoutineItems(widget.routineId, _items);
    if (!mounted) return;
    _dirty = false;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // PopScope intercepta el botón "atrás" de Android.
    // canPop: false (si hay cambios) -> el sistema NO cierra la pantalla
    // y nos llama a onPopInvokedWithResult para decidir nosotros.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // ya salió (no había cambios)
        final discard = await confirm(context,
            title: 'Discard changes?', confirmLabel: 'Discard');
        // Navigator.pop() manual NO pasa por PopScope, así que sí cierra.
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_name),
          actions: [
            IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit),
                onPressed: _rename),
            IconButton(
                tooltip: 'Save',
                icon: const Icon(Icons.save),
                onPressed: _save),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Add exercises to this routine.'))
                // ReorderableListView: lista que se reordena arrastrando.
                // En Android: mantener presionado una tarjeta y moverla.
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        // Detalle de Flutter: al mover hacia ABAJO,
                        // newIndex cuenta el hueco del ítem que sacamos,
                        // por eso hay que restarle 1.
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                        _dirty = true;
                      });
                    },
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return Card(
                        // La lista reordenable EXIGE una key única por
                        // ítem para seguirlo mientras se mueve. ObjectKey
                        // usa la identidad del objeto (sirve aunque el
                        // mismo ejercicio esté dos veces).
                        key: ObjectKey(item),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(item.exerciseName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() {
                                      _items.removeAt(i);
                                      _dirty = true;
                                    }),
                                  ),
                                ],
                              ),
                              // Wrap = como Row, pero si no cabe, baja de
                              // línea (pantallas angostas).
                              Wrap(
                                spacing: 16,
                                children: [
                                  _Stepper(
                                    label: 'Sets',
                                    value: item.targetSets,
                                    min: 1,
                                    max: 10,
                                    onChanged: (v) => setState(() {
                                      item.targetSets = v;
                                      _dirty = true;
                                    }),
                                  ),
                                  _Stepper(
                                    label: 'Reps',
                                    value: item.targetReps,
                                    min: 1,
                                    max: 50,
                                    onChanged: (v) => setState(() {
                                      item.targetReps = v;
                                      _dirty = true;
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExercises,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ),
    );
  }
}

/// Mini control  [-] 3 [+]. Stateless: no guarda el número, solo lo
/// muestra y avisa al padre con onChanged (el padre es el dueño del dato).
class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged; // = void Function(int)

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove),
          // En el mínimo, null deshabilita el botón.
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
