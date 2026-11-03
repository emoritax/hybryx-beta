// ─────────────────────────────────────────────────────────────────────
// exercise_library_screen.dart — Catálogo de ejercicios.
//
// UNA pantalla con DOS modos (para no duplicar búsqueda y filtros):
//   pickMode = false -> pestaña "Exercises": ver, crear, borrar custom.
//   pickMode = true  -> selector: marcas varios y los devuelve a quien
//                       abrió la pantalla (editor de rutina o entreno).
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../data/seed_exercises.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final bool pickMode;
  const ExerciseLibraryScreen({super.key, this.pickMode = false});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _repo = Repo.instance;

  List<Exercise> _all = [];
  bool _loading = true;
  String _query = ''; // texto del buscador
  String? _muscle; // filtro de músculo; null = "All"
  // Set literal `{}` en Dart es un LinkedHashSet: recuerda el ORDEN de
  // inserción. Así los ejercicios se agregan en el orden en que los tocaste.
  final Set<int> _selected = {};

  // initState corre UNA vez al crear la pantalla. Lugar ideal para cargar.
  // No puede ser async, por eso llamamos a _load() sin await.
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await _repo.getExercises();
    if (!mounted) return;
    setState(() {
      _all = exercises;
      _loading = false;
    });
  }

  /// Getter calculado: se recalcula en cada build con filtro + búsqueda.
  /// Con ~80 ejercicios filtrar en memoria es instantáneo; no vale la
  /// pena ir a SQL por cada letra.
  List<Exercise> get _filtered {
    final q = _query.toLowerCase();
    return _all
        .where((e) =>
            (_muscle == null || e.muscleGroup == _muscle) &&
            e.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _addCustom() async {
    final created = await showAddExerciseDialog(context);
    if (created == null) return; // canceló
    await _load();
    if (!mounted) return;
    // En modo selector, lo dejamos ya marcado (probablemente lo quieres).
    if (widget.pickMode) setState(() => _selected.add(created.id!));
  }

  Future<void> _delete(Exercise e) async {
    final ok = await confirm(context, title: 'Delete "${e.name}"?');
    if (!ok) return;
    final deleted = await _repo.deleteCustomExercise(e.id!);
    if (!mounted) return;
    if (!deleted) {
      // SnackBar = mensaje temporal abajo de la pantalla.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('It is used in a routine or workout, can\'t delete.')));
    }
    await _load();
  }

  void _confirmPick() {
    // Convertimos ids -> objetos respetando el orden de selección.
    final picked =
        _selected.map((id) => _all.firstWhere((e) => e.id == id)).toList();
    Navigator.pop(context, picked); // "devuelve" la lista a quien abrió
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered; // calculamos una vez por build

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Add exercises' : 'Exercises'),
        actions: [
          IconButton(
            tooltip: 'New custom exercise',
            icon: const Icon(Icons.add),
            onPressed: _addCustom,
          ),
        ],
      ),
      // Operador ternario para mostrar un spinner mientras carga.
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Buscador ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                // ── Chips de músculo (scroll horizontal) ──
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _muscle == null,
                        onSelected: (_) => setState(() => _muscle = null),
                      ),
                      // "collection for": genera un chip por músculo
                      // directamente dentro de la lista de children.
                      for (final m in muscleGroups)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(m),
                            selected: _muscle == m,
                            onSelected: (_) => setState(() => _muscle = m),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Lista ──
                // Expanded: "ocupa todo el alto que sobre". Sin esto, una
                // ListView dentro de Column da error de tamaño infinito.
                Expanded(
                  // ListView.builder crea solo las filas visibles (lazy):
                  // eficiente aunque haya cientos de ejercicios.
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final subtitle = Text(
                          '${e.muscleGroup} · ${e.equipment}${e.isCustom ? ' · Custom' : ''}');
                      if (widget.pickMode) {
                        return CheckboxListTile(
                          value: _selected.contains(e.id),
                          title: Text(e.name),
                          subtitle: subtitle,
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(e.id!);
                            } else {
                              _selected.remove(e.id);
                            }
                          }),
                        );
                      }
                      return ListTile(
                        title: Text(e.name),
                        subtitle: subtitle,
                        // Solo los custom tienen botón de borrar.
                        trailing: e.isCustom
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(e),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
      // Botón flotante solo en modo selector y con algo marcado.
      floatingActionButton: widget.pickMode && _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _confirmPick,
              icon: const Icon(Icons.check),
              label: Text('Add (${_selected.length})'),
            )
          : null,
    );
  }
}
