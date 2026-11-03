// ─────────────────────────────────────────────────────────────────────
// exercise_picker_screen.dart — Selector de ejercicios (varios a la vez).
// Lo abren el entreno en vivo ("Añadir ejercicio") y la carta "+" del
// mazo. Devuelve List<Exercise> con Navigator.pop(context, lista).
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../data/seed_exercises.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';
import '../widgets/dialogs.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  List<Exercise> _all = [];
  bool _loading = true;
  String _query = '';
  String? _muscle;
  // Set literal {} = LinkedHashSet: recuerda el ORDEN en que tocaste.
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await Repo.instance.getExercises();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  List<Exercise> get _filtered {
    final q = _query.toLowerCase();
    return _all
        .where((e) =>
            (_muscle == null || e.muscleGroup == _muscle) &&
            e.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _createCustom() async {
    final created = await showAddExerciseDialog(context);
    if (created == null) return;
    await _load();
    if (mounted) setState(() => _selected.add(created.id!));
  }

  void _confirm() {
    final picked =
        _selected.map((id) => _all.firstWhere((e) => e.id == id)).toList();
    Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('AÑADIR EJERCICIOS', style: Hx.disp(24)),
        actions: [
          IconButton(
              tooltip: 'Ejercicio personalizado',
              onPressed: _createCustom,
              icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: Hx.dim),
                        hintText: 'Buscar'),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip('Todos', null),
                      for (final m in muscleGroups) _chip(muscleLabel(m), m),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final on = _selected.contains(e.id);
                      return ListTile(
                        onTap: () => setState(() {
                          if (on) {
                            _selected.remove(e.id);
                          } else {
                            _selected.add(e.id!);
                          }
                        }),
                        // Barrita de color del grupo muscular.
                        leading: Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                              color: muscleColor(e.muscleGroup),
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        title: Text(e.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${muscleLabel(e.muscleGroup)} · ${equipmentLabel(e.equipment)}',
                            style: const TextStyle(color: Hx.muted)),
                        // AnimatedSwitcher: el check aparece con un "pop".
                        trailing: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: Icon(
                            on
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            key: ValueKey(on),
                            color: on ? Hx.lime : Hx.dim,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      // AnimatedScale: el botón aparece creciendo cuando eliges algo.
      floatingActionButton: AnimatedScale(
        scale: _selected.isEmpty ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: FloatingActionButton.extended(
          backgroundColor: Hx.lime,
          foregroundColor: Hx.bg,
          onPressed: _selected.isEmpty ? null : _confirm,
          icon: const Icon(Icons.check_rounded),
          label: Text('Añadir (${_selected.length})',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _chip(String label, String? muscle) {
    final on = _muscle == muscle;
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: Hx.lime,
        labelStyle: TextStyle(
            color: on ? Hx.bg : Hx.muted, fontWeight: FontWeight.w700),
        onSelected: (_) => setState(() => _muscle = muscle),
      ),
    );
  }
}
