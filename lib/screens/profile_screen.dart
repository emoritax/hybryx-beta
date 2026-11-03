// ─────────────────────────────────────────────────────────────────────
// profile_screen.dart — "Perfil" (diseño 1), con TUS datos reales.
//
//  • Tarjeta: iniciales, @alias (toca el lápiz para cambiarlo), nivel + XP
//  • 3 números que cuentan hacia arriba: Entrenos · PRs · Racha máx.
//  • MEJORES MARCAS: tus PR por ejercicio (1RM estimado)
//  • HISTORIAL: desliza un entreno a la izquierda para borrarlo
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/progress.dart';
import '../data/repo.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';
import '../widgets/dialogs.dart';
import '../widgets/motion.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = Repo.instance;
  bool _loading = true;
  String _alias = '';
  Progress? _progress;
  List<WorkoutSummary> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
    _repo.changes.addListener(_load);
  }

  @override
  void dispose() {
    _repo.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final alias = await _repo.getAlias();
    final progress = await _repo.getProgress();
    final history = await _repo.getRecentWorkouts();
    if (!mounted) return;
    setState(() {
      _alias = alias;
      _progress = progress;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _editAlias() async {
    final v = await showTextPrompt(context,
        title: 'Tu alias', initial: _alias, label: 'Sin @ ni espacios');
    if (v == null) return;
    // Normalizamos: sin @, sin espacios, minúsculas (como un @usuario).
    final clean = v.replaceAll('@', '').replaceAll(' ', '').toLowerCase();
    if (clean.isNotEmpty) await _repo.setAlias(clean);
  }

  /// Iniciales para el avatar: "emoritax" -> "EM".
  String get _initials {
    final s = _alias.trim();
    if (s.isEmpty) return '?';
    return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final p = _progress!;

    var i = 0;
    Widget step(Widget w) => FadeSlideIn(index: i++, child: w);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        step(Text('PERFIL', style: Hx.disp(34))),
        const SizedBox(height: 14),
        step(_identityCard(p)),
        const SizedBox(height: 12),
        step(Row(
          children: [
            _stat(p.workouts, 'Entrenos'),
            const SizedBox(width: 8),
            _stat(p.prCount, 'PRs'),
            const SizedBox(width: 8),
            _stat(p.bestWeekStreak, 'Racha máx.', suffix: ' sem'),
          ],
        )),
        const SizedBox(height: 22),
        step(Text('MEJORES MARCAS', style: Hx.label())),
        const SizedBox(height: 8),
        if (p.bestLifts.isEmpty)
          step(_empty('Termina un entreno con peso y reps para ver tus marcas.'))
        else
          step(Container(
            decoration: Hx.card(),
            child: Column(
              children: [
                for (var j = 0; j < p.bestLifts.length; j++)
                  _liftRow(p.bestLifts[j], last: j == p.bestLifts.length - 1),
              ],
            ),
          )),
        const SizedBox(height: 22),
        step(Row(
          children: [
            Text('HISTORIAL', style: Hx.label()),
            const Spacer(),
            if (_history.isNotEmpty)
              const Text('Desliza ← para borrar',
                  style: TextStyle(fontSize: 11, color: Hx.dim)),
          ],
        )),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          step(_empty('Aún no hay entrenos terminados.'))
        else
          for (final w in _history) _historyRow(w),
        const SizedBox(height: 16),
        Center(
          child: Text(
              'XP: +$xpPerWorkout por entreno · +$xpPerSet por serie · +$xpPerPr por PR',
              style: const TextStyle(fontSize: 11, color: Hx.dim)),
        ),
      ],
    );
  }

  Widget _identityCard(Progress p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Hx.card(radius: 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Hx.line,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Hx.lime, width: 2),
                ),
                child: Text(_initials, style: Hx.disp(28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@$_alias',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 2),
                    const Text('Gym · Beta local',
                        style: TextStyle(fontSize: 12, color: Hx.muted)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: _editAlias,
                  icon: const Icon(Icons.edit_outlined, color: Hx.muted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LevelBadge(level: p.level),
              const SizedBox(width: 8),
              Expanded(child: AnimatedBar(fraction: p.levelFraction, height: 8)),
              const SizedBox(width: 8),
              Text('${thousands(p.xpIntoLevel)}/${thousands(p.xpForLevel)} XP',
                  style: const TextStyle(fontSize: 11, color: Hx.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(int value, String label, {String suffix = ''}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: Hx.card(),
        child: Column(
          children: [
            AnimatedCount(
                value: value,
                suffix: suffix,
                style: Hx.disp(30, color: Hx.lime)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Hx.muted)),
          ],
        ),
      ),
    );
  }

  Widget _liftRow(BestLift l, {required bool last}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Hx.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: muscleColor(l.muscleGroup),
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${shortDate(l.date)} · ${kg(l.weightKg)} kg × ${l.reps}',
                    style: const TextStyle(fontSize: 12, color: Hx.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${l.e1rm.round()} kg', style: Hx.disp(22, color: Hx.lime)),
              const Text('1RM est.',
                  style: TextStyle(fontSize: 10, color: Hx.dim)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyRow(WorkoutSummary w) {
    // Dismissible = gesto de deslizar para descartar. confirmDismiss
    // pregunta ANTES; si devuelve false, la fila vuelve a su lugar.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(w.id),
        direction: DismissDirection.endToStart, // solo hacia la izquierda
        confirmDismiss: (_) {
          HapticFeedback.mediumImpact();
          return confirm(context,
              title: '¿Borrar "${w.name}"?',
              message: 'Se recalculan tu XP, nivel y marcas.');
        },
        // Hay que sacar la fila de la lista YA (síncrono): si el próximo
        // frame aún la dibuja, Flutter lanza "dismissed widget is still
        // part of the tree". Luego el repo recalcula todo.
        onDismissed: (_) {
          setState(() => _history.removeWhere((x) => x.id == w.id));
          _repo.deleteWorkout(w.id);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: Hx.danger, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline, color: Hx.bg),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: Hx.card(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.name.toUpperCase(),
                        style: Hx.disp(20, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(shortDate(w.startedAt),
                        style: const TextStyle(fontSize: 12, color: Hx.muted)),
                  ],
                ),
              ),
              _mini(Icons.timer_outlined, formatDuration(w.duration)),
              const SizedBox(width: 12),
              _mini(Icons.check_circle_outline, '${w.doneSets}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: Hx.dim),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      );

  Widget _empty(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: Hx.card(),
        child: Text(text, style: const TextStyle(color: Hx.muted)),
      );
}
