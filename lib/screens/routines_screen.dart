// ─────────────────────────────────────────────────────────────────────
// routines_screen.dart — Lista de rutinas (tu pestaña "cards").
// Crear, abrir para editar y borrar rutinas.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../widgets/dialogs.dart';
import 'routine_editor_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _repo = Repo.instance;
  List<Routine> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routines = await _repo.getRoutines();
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final name = await showTextPrompt(context, title: 'New routine');
    if (name == null) return;
    final id = await _repo.createRoutine(name);
    // Recién creada -> abrimos el editor para agregarle ejercicios.
    await _openEditor(id, name);
  }

  Future<void> _openEditor(int id, String name) async {
    if (!mounted) return;
    // Navigator.push apila una pantalla nueva encima. El `await` espera
    // a que el usuario vuelva (pop) y entonces recargamos la lista.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditorScreen(routineId: id, initialName: name),
      ),
    );
    await _load();
  }

  Future<void> _delete(Routine r) async {
    final ok = await confirm(context,
        title: 'Delete "${r.name}"?',
        message: 'Workouts already done with it are kept.');
    if (!ok) return;
    await _repo.deleteRoutine(r.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routines.isEmpty
              ? const Center(child: Text('No routines yet. Tap "New routine".'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: _routines.length,
                  itemBuilder: (context, i) {
                    final r = _routines[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.name),
                        subtitle: Text('${r.itemCount} exercises'),
                        onTap: () => _openEditor(r.id, r.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(r),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New routine'),
      ),
    );
  }
}
