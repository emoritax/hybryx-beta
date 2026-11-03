// ─────────────────────────────────────────────────────────────────────
// dialogs.dart — Diálogos reutilizables: pedir un texto, confirmar
// una acción y crear un ejercicio personalizado.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // para atrapar DatabaseException

import '../data/repo.dart';
import '../data/seed_exercises.dart';
import '../models/models.dart';

/// Pide un texto (ej. nombre de rutina). Devuelve null si se cancela.
/// showDialog devuelve un Future que se completa con lo que se pase a
/// Navigator.pop(context, valor) al cerrar el diálogo.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Name',
}) {
  // Nota: este controller no se dispose()-a. Si lo liberáramos al cerrar,
  // la animación de salida del diálogo aún lo usa y Flutter lanza error.
  // No tiene listeners, así que el recolector de basura lo limpia solo.
  final controller = TextEditingController(text: initial);

  // Función local: valida y cierra. Evita repetir lógica en 2 lugares.
  void submit(BuildContext ctx) {
    final text = controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(ctx, text);
  }

  return showDialog<String>(
    context: context,
    // `ctx` es el contexto DEL diálogo; con él cerramos el diálogo,
    // no la pantalla de atrás.
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true, // abre el teclado de una
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => submit(ctx), // "Enter" del teclado = OK
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => submit(ctx), child: const Text('OK')),
      ],
    ),
  );
}

/// Diálogo Sí/No. Devuelve true solo si el usuario confirma.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      // `if` dentro de parámetros no se puede; usamos ternario con null.
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  // Si tocan fuera del diálogo, result es null -> lo tratamos como "no".
  return result ?? false;
}

/// Abre el diálogo de "nuevo ejercicio". Devuelve el Exercise creado.
Future<Exercise?> showAddExerciseDialog(BuildContext context) {
  return showDialog<Exercise>(
    context: context,
    builder: (_) => const _AddExerciseDialog(),
  );
}

/// Stateful porque el diálogo tiene estado propio: músculo elegido,
/// equipo elegido, mensaje de error y si está guardando.
class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _name = TextEditingController();
  String _muscle = muscleGroups.first;
  String _equipment = equipmentTypes.first;
  String? _error; // texto rojo bajo el campo; null = sin error
  bool _saving = false; // desactiva "Save" para evitar doble toque

  // Los controllers reservan recursos: hay que liberarlos al destruir
  // el State. Regla: lo que creas en el State, lo limpias en dispose().
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await Repo.instance.addCustomExercise(
          name: name, muscleGroup: _muscle, equipment: _equipment);
      // Tras un `await` la pantalla pudo cerrarse. `mounted` dice si este
      // State sigue en pantalla; usar context sin chequear puede crashear.
      if (!mounted) return;
      Navigator.pop(context, created);
    } on DatabaseException catch (e) {
      setState(() {
        _saving = false;
        // isUniqueConstraintError(): el UNIQUE de `name` saltó.
        _error = e.isUniqueConstraintError()
            ? 'An exercise with that name already exists'
            : 'Could not save the exercise';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New exercise'),
      content: Column(
        mainAxisSize: MainAxisSize.min, // altura justa, no toda la pantalla
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Name (English)', errorText: _error),
          ),
          const SizedBox(height: 12), // espacio vertical fijo
          DropdownButtonFormField<String>(
            initialValue: _muscle,
            decoration: const InputDecoration(labelText: 'Muscle group'),
            // Convertimos cada String en una opción del dropdown.
            items: [
              for (final m in muscleGroups)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            // `v!` = "sé que no es null" (siempre elegimos algo).
            onChanged: (v) => setState(() => _muscle = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _equipment,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: [
              for (final e in equipmentTypes)
                DropdownMenuItem(value: e, child: Text(e)),
            ],
            onChanged: (v) => setState(() => _equipment = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        // onPressed: null => botón deshabilitado (gris).
        FilledButton(
            onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
