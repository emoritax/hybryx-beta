// ─────────────────────────────────────────────────────────────────────
// routines_screen.dart — "Rutinas (el mazo)" del diseño 2.
//
//  • Pastillas de rutinas arriba (mantén presionada para renombrar/borrar)
//  • TU MAZO: cartas horizontales. Mantén presionada y ARRASTRA para
//    reordenar; toca una carta para editar series × reps.
//  • CATÁLOGO: busca, filtra y toca un ejercicio para meterlo al mazo.
//  Todo se guarda al instante (sin botón Guardar).
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../data/seed_exercises.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';
import '../widgets/dialogs.dart';
import '../widgets/motion.dart';
import 'exercise_picker_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _repo = Repo.instance;

  bool _loading = true;
  List<Routine> _routines = [];
  int? _selectedId;
  List<RoutineItem> _deck = [];
  List<Exercise> _catalog = [];
  String _query = '';
  String? _muscle; // filtro; null = todos

  /// Cuando ESTA pantalla escribe, el repo toca la campana y nos llamaría
  /// a recargar. No queremos: recargar crea objetos nuevos y las cartas
  /// repetirían su animación de entrada. Con esta bandera ignoramos el
  /// aviso que provocamos nosotros mismos.
  bool _ignoreNextChange = false;

  @override
  void initState() {
    super.initState();
    _load();
    _repo.changes.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repo.changes.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (_ignoreNextChange) {
      _ignoreNextChange = false;
      return;
    }
    _load();
  }

  Routine? get _selected {
    final found = _routines.where((r) => r.id == _selectedId);
    return found.isEmpty ? null : found.first;
  }

  Future<void> _load() async {
    final routines = await _repo.getRoutines();
    final catalog = await _repo.getExercises();
    // Mantener la selección si sigue existiendo; si no, la primera.
    var selected = _selectedId;
    if (!routines.any((r) => r.id == selected)) {
      selected = routines.isEmpty ? null : routines.first.id;
    }
    final deck =
        selected == null ? <RoutineItem>[] : await _repo.getRoutineItems(selected);
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _catalog = catalog;
      _selectedId = selected;
      _deck = deck;
      _loading = false;
    });
  }

  Future<void> _persistDeck() async {
    final id = _selectedId;
    if (id == null) return;
    _ignoreNextChange = true;
    await _repo.saveRoutineItems(id, _deck);
  }

  // ═════════════════════ Rutinas ═════════════════════

  Future<void> _createRoutine() async {
    final name = await showTextPrompt(context,
        title: 'Nueva rutina', label: 'Ej: Empuje · Fuerza');
    if (name == null) return;
    // Ignoramos el aviso de la campana y recargamos NOSOTROS después de
    // fijar la selección, para que la rutina nueva quede seleccionada.
    _ignoreNextChange = true;
    _selectedId = await _repo.createRoutine(name);
    await _load();
  }

  Future<void> _routineMenu(Routine r) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.name.toUpperCase(), style: Hx.disp(24)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renombrar'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Hx.danger),
              title: const Text('Eliminar', style: TextStyle(color: Hx.danger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'rename') {
      final name = await showTextPrompt(context,
          title: 'Renombrar', initial: r.name);
      if (name != null) await _repo.renameRoutine(r.id, name);
    } else {
      final ok = await confirm(context,
          title: '¿Eliminar "${r.name}"?',
          message: 'Los entrenos ya hechos con ella se conservan.');
      if (ok) await _repo.deleteRoutine(r.id);
    }
  }

  // ═════════════════════ Mazo ═════════════════════

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      // Al mover hacia adelante, newIndex cuenta el hueco del que salió.
      if (newIndex > oldIndex) newIndex -= 1;
      _deck.insert(newIndex, _deck.removeAt(oldIndex));
    });
    HapticFeedback.selectionClick();
    _persistDeck();
  }

  Future<void> _addToDeck(Exercise e) async {
    final r = _selected;
    if (r == null) {
      _toast('Crea una rutina primero');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _deck.add(RoutineItem(
        exerciseId: e.id!, exerciseName: e.name, muscleGroup: e.muscleGroup)));
    await _persistDeck();
    _toast('${e.name} → ${r.name}');
  }

  Future<void> _addFromPicker() async {
    if (_selected == null) return;
    final picked = await Navigator.push<List<Exercise>>(context,
        MaterialPageRoute(builder: (_) => const ExercisePickerScreen()));
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final e in picked) {
        _deck.add(RoutineItem(
            exerciseId: e.id!, exerciseName: e.name, muscleGroup: e.muscleGroup));
      }
    });
    await _persistDeck();
  }

  /// Hoja para editar series × reps de una carta, o quitarla.
  Future<void> _editCard(RoutineItem item) async {
    HapticFeedback.selectionClick();
    final remove = await showModalBottomSheet<bool>(
      context: context,
      // StatefulBuilder: un mini-State solo para la hoja, así los [-][+]
      // repintan la hoja sin reconstruir toda la pantalla.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.exerciseName.toUpperCase(),
                    textAlign: TextAlign.center, style: Hx.disp(26)),
                const SizedBox(height: 4),
                Text(muscleLabel(item.muscleGroup),
                    style: TextStyle(color: muscleColor(item.muscleGroup))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Stepper3(
                      label: 'Series',
                      value: item.targetSets,
                      min: 1,
                      max: 10,
                      onChanged: (v) => setSheet(() => item.targetSets = v),
                    ),
                    Stepper3(
                      label: 'Reps',
                      value: item.targetReps,
                      min: 1,
                      max: 50,
                      onChanged: (v) => setSheet(() => item.targetReps = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.delete_outline, color: Hx.danger),
                  label: const Text('Quitar del mazo',
                      style: TextStyle(color: Hx.danger)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Al cerrar la hoja (por arrastre, por fuera o por "Quitar") guardamos.
    if (remove == true) _deck.remove(item);
    setState(() {}); // repinta las cartas con los nuevos números
    await _persistDeck();
  }

  // ═════════════════════ Catálogo ═════════════════════

  List<Exercise> get _filtered {
    final q = _query.toLowerCase();
    return _catalog
        .where((e) =>
            (_muscle == null || e.muscleGroup == _muscle) &&
            e.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _createCustom() async {
    final created = await showAddExerciseDialog(context);
    if (created != null) _toast('${created.name} creado');
  }

  Future<void> _deleteCustom(Exercise e) async {
    HapticFeedback.mediumImpact();
    final ok = await confirm(context, title: '¿Eliminar "${e.name}"?');
    if (!ok) return;
    final deleted = await _repo.deleteCustomExercise(e.id!);
    if (!deleted) _toast('Está en una rutina o entreno, no se puede borrar');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar() // si hay uno visible, lo reemplaza
      ..showSnackBar(SnackBar(
          content: Text(msg), duration: const Duration(milliseconds: 1400)));
  }

  // ═════════════════════ UI ═════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _filtered;
    final selected = _selected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Encabezado ──
        Row(
          children: [
            Text('RUTINAS', style: Hx.disp(34)),
            const Spacer(),
            FilledButton.icon(
              onPressed: _createRoutine,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Pastillas de rutinas ──
        if (_routines.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _routines.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _routinePill(_routines[i]),
            ),
          ),
        const SizedBox(height: 14),

        // ── Mazo ──
        if (selected == null) _emptyRoutines() else _deckSection(selected),
        const SizedBox(height: 22),

        // ── Catálogo ──
        Row(
          children: [
            Text('CATÁLOGO DE EJERCICIOS', style: Hx.label()),
            const Spacer(),
            GestureDetector(
              onTap: _createCustom,
              child: const Text('+ Personalizado',
                  style: TextStyle(
                      color: Hx.lime, fontWeight: FontWeight.w500, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: Hx.dim),
            hintText: 'Buscar ejercicio (${_catalog.length})',
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('Todos', null),
              for (final m in muscleGroups) _filterChip(muscleLabel(m), m),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // GridView dentro de ListView: shrinkWrap (alto según contenido)
        // y sin scroll propio (scrollea el ListView de afuera).
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 96, // alto fijo de cada tarjeta
          ),
          itemBuilder: (context, i) => _catalogCard(filtered[i]),
        ),
        const SizedBox(height: 14),
        _legend(),
      ],
    );
  }

  Widget _routinePill(Routine r) {
    final on = r.id == _selectedId;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        _selectedId = r.id;
        await _load();
      },
      onLongPress: () => _routineMenu(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Hx.limeTint : Hx.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? Hx.lime : Hx.line, width: 1.5),
        ),
        child: Text(r.name,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: on ? Hx.lime : Hx.text)),
      ),
    );
  }

  Widget _emptyRoutines() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: Hx.card(radius: 20),
      child: Column(
        children: [
          const Icon(Icons.style_outlined, size: 40, color: Hx.lime),
          const SizedBox(height: 10),
          Text('SIN RUTINAS AÚN', style: Hx.disp(26)),
          const SizedBox(height: 4),
          const Text('Crea una y arma su mazo con el catálogo de abajo.',
              textAlign: TextAlign.center, style: TextStyle(color: Hx.muted)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _createRoutine, child: const Text('Crear rutina')),
        ],
      ),
    );
  }

  Widget _deckSection(Routine r) {
    final totalSets = _deck.fold<int>(0, (s, it) => s + it.targetSets);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: Hx.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text('Tu mazo · ${r.name}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Text('${_deck.length} cartas · ~${(totalSets * 2.5).round()} min',
                    style: const TextStyle(fontSize: 12, color: Hx.muted)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text('Mantén presionada una carta para moverla',
              style: TextStyle(fontSize: 11, color: Hx.dim)),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            // Lista horizontal reordenable: en Android se arrastra tras
            // mantener presionado (ReorderableDelayedDragStartListener).
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _deck.length,
              onReorder: _reorder,
              // Cómo se ve la carta mientras la arrastras: más grande.
              proxyDecorator: (child, index, animation) => ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.08).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: Material(color: Colors.transparent, child: child),
              ),
              footer: _addCard(),
              itemBuilder: (context, i) {
                final item = _deck[i];
                return Padding(
                  // La key va en el widget RAÍZ de cada ítem (requisito).
                  key: ObjectKey(item),
                  padding: const EdgeInsets.only(right: 8),
                  child: FadeSlideIn(
                    index: i,
                    dy: 0.25,
                    child: _deckCard(i, item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _deckCard(int i, RoutineItem item) {
    final color = muscleColor(item.muscleGroup);
    return GestureDetector(
      onTap: () => _editCard(item),
      child: Container(
        width: 104,
        clipBehavior: Clip.antiAlias, // recorta la banda a las esquinas
        decoration: BoxDecoration(
          color: Hx.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Hx.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 5, color: color), // banda de color
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}', style: Hx.disp(18, color: color)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(item.exerciseName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.2)),
                    ),
                    Text('${item.targetSets}×${item.targetReps}',
                        style: Hx.disp(18, color: Hx.lime)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addCard() {
    return GestureDetector(
      onTap: _addFromPicker,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Hx.line2, width: 1.5),
        ),
        child: const Icon(Icons.add_rounded, color: Hx.lime, size: 30),
      ),
    );
  }

  Widget _filterChip(String label, String? muscle) {
    final on = _muscle == muscle;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _muscle = muscle),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Hx.lime : Hx.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? Hx.lime : Hx.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? Hx.bg : Hx.muted)),
        ),
      ),
    );
  }

  Widget _catalogCard(Exercise e) {
    final color = muscleColor(e.muscleGroup);
    return Material(
      color: Hx.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      // InkWell = efecto de onda al tocar.
      child: InkWell(
        onTap: () => _addToDeck(e),
        onLongPress: e.isCustom ? () => _deleteCustom(e) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        muscleLabel(e.muscleGroup).toUpperCase() +
                            (e.isCustom ? ' · PROPIO' : ''),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: color)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(e.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2)),
                    ),
                    Text(equipmentLabel(e.equipment),
                        style: const TextStyle(fontSize: 11, color: Hx.muted)),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: Hx.dim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final f in MoveFamily.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: familyColor(f),
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 6),
              Text(familyLabel(f),
                  style: const TextStyle(fontSize: 12, color: Hx.muted)),
            ],
          ),
      ],
    );
  }
}
