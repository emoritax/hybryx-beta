// ─────────────────────────────────────────────────────────────────────
// dialogs.dart — Diálogos reutilizables: pedir texto, confirmar, crear
// ejercicio personalizado y el control  [-] 3 [+].
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // DatabaseException

import '../data/repo.dart';
import '../data/seed_exercises.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';

/// Pide un texto. Devuelve null si se cancela.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Nombre',
}) {
  // No se dispose()-a: la animación de salida aún lo usa al cerrar.
  // Sin listeners, el recolector de basura lo limpia.
  final controller = TextEditingController(text: initial);

  void submit(BuildContext ctx) {
    final text = controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(ctx, text);
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: Hx.disp(26)),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => submit(ctx),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Hx.muted))),
        FilledButton(onPressed: () => submit(ctx), child: const Text('Guardar')),
      ],
    ),
  );
}

/// Sí/No. true solo si confirma.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Eliminar',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: Hx.disp(24)),
      content: message == null
          ? null
          : Text(message, style: const TextStyle(color: Hx.muted)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Hx.muted))),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Hx.danger, foregroundColor: Hx.bg)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false; // tocar afuera = no
}

/// Diálogo de ejercicio personalizado. Devuelve el Exercise creado.
Future<Exercise?> showAddExerciseDialog(BuildContext context) {
  return showDialog<Exercise>(
      context: context, builder: (_) => const _AddExerciseDialog());
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _name = TextEditingController();
  String _muscle = muscleGroups.first;
  String _equipment = equipmentTypes.first;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await Repo.instance.addCustomExercise(
          name: name, muscleGroup: _muscle, equipment: _equipment);
      if (!mounted) return;
      Navigator.pop(context, created);
    } on DatabaseException catch (e) {
      setState(() {
        _saving = false;
        _error = e.isUniqueConstraintError()
            ? 'Ya existe un ejercicio con ese nombre'
            : 'No se pudo guardar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nuevo ejercicio', style: Hx.disp(26)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Nombre (en inglés)', errorText: _error),
          ),
          const SizedBox(height: 12),
          // Guardamos la clave en inglés ('Chest') pero mostramos 'Pecho'.
          DropdownButtonFormField<String>(
            initialValue: _muscle,
            decoration: const InputDecoration(labelText: 'Músculo'),
            items: [
              for (final m in muscleGroups)
                DropdownMenuItem(value: m, child: Text(muscleLabel(m))),
            ],
            onChanged: (v) => setState(() => _muscle = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _equipment,
            decoration: const InputDecoration(labelText: 'Equipo'),
            items: [
              for (final e in equipmentTypes)
                DropdownMenuItem(value: e, child: Text(equipmentLabel(e))),
            ],
            onChanged: (v) => setState(() => _equipment = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Hx.muted))),
        FilledButton(
            onPressed: _saving ? null : _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Control  [-] 3 [+]. Stateless: el padre es dueño del número.
class Stepper3 extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const Stepper3({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, int? next) => IconButton.filledTonal(
          style: IconButton.styleFrom(
              backgroundColor: Hx.surface2, foregroundColor: Hx.text),
          onPressed: next == null ? null : () => onChanged(next),
          icon: Icon(icon, size: 18),
        );

    return Column(
      children: [
        Text(label.toUpperCase(), style: Hx.label()),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.remove, value > min ? value - 1 : null),
            // AnimatedSwitcher: el número nuevo entra con un fade+zoom.
            SizedBox(
              width: 48,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Text('$value',
                    key: ValueKey(value),
                    textAlign: TextAlign.center,
                    style: Hx.disp(30, color: Hx.lime)),
              ),
            ),
            btn(Icons.add, value < max ? value + 1 : null),
          ],
        ),
      ],
    );
  }
}
