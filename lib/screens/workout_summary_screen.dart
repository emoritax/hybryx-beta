// ─────────────────────────────────────────────────────────────────────
// workout_summary_screen.dart — La CELEBRACIÓN al terminar un entreno.
//
// Confeti + vibración, números que cuentan (duración, series, volumen,
// PRs), la XP ganada y la barra de nivel llenándose. Si subiste de
// nivel, aparece un banner con rebote.
//
// Recibe `before` (el progreso ANTES de terminar) y calcula el de
// después: la diferencia es lo que ganaste en este entreno.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repo.dart';
import '../models/models.dart';
import '../theme/hx.dart';
import '../theme/labels.dart';
import '../widgets/confetti.dart';
import '../widgets/motion.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final int workoutId;
  final Progress before;

  const WorkoutSummaryScreen(
      {super.key, required this.workoutId, required this.before});

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  final _repo = Repo.instance;

  Workout? _workout;
  Progress? _after;
  int _sets = 0;
  double _volume = 0;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact(); // ¡celebración!
    _load();
  }

  Future<void> _load() async {
    final workout = await _repo.getWorkout(widget.workoutId);
    final exercises = await _repo.getWorkoutExercises(widget.workoutId);
    final after = await _repo.getProgress();

    // Volumen = Σ peso × reps de las series hechas (sin calentamiento).
    // Es la métrica clásica de "cuánto trabajo hiciste".
    var sets = 0;
    var volume = 0.0;
    for (final s in exercises.expand((e) => e.sets)) {
      if (!s.done) continue;
      sets++;
      if (s.type != SetType.warmup) {
        volume += (s.weightKg ?? 0) * (s.reps ?? 0);
      }
    }
    if (!mounted) return;
    setState(() {
      _workout = workout;
      _after = after;
      _sets = sets;
      _volume = volume;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = _workout;
    final after = _after;
    final before = widget.before;

    return Scaffold(
      // Stack: el contenido abajo y el confeti ENCIMA de todo.
      body: Stack(
        children: [
          SafeArea(
            child: w == null || after == null
                ? const Center(child: CircularProgressIndicator())
                : _content(w, before, after),
          ),
          const Positioned.fill(child: Confetti()),
        ],
      ),
    );
  }

  Widget _content(Workout w, Progress before, Progress after) {
    final duration = w.finishedAt!.difference(w.startedAt);
    final xpGained = after.xp - before.xp;
    final prs = after.prCount - before.prCount;
    final leveledUp = after.level > before.level;

    var i = 0;
    Widget step(Widget child) => FadeSlideIn(index: i++, child: child);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      children: [
        step(const Center(child: HxLogo(size: 72))),
        const SizedBox(height: 18),
        step(Text('¡ENTRENO\nCOMPLETADO!',
            textAlign: TextAlign.center, style: Hx.disp(48, color: Hx.lime))),
        const SizedBox(height: 8),
        step(Text(w.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: Hx.disp(20, weight: FontWeight.w600, color: Hx.muted))),
        const SizedBox(height: 24),

        // ── 4 estadísticas en cuadrícula 2×2 ──
        step(Row(children: [
          _tile(Icons.timer_outlined, 'Duración',
              Text(formatDuration(duration), style: Hx.disp(32))),
          const SizedBox(width: 10),
          _tile(Icons.check_circle_outline, 'Series',
              AnimatedCount(value: _sets, style: Hx.disp(32))),
        ])),
        const SizedBox(height: 10),
        step(Row(children: [
          _tile(Icons.fitness_center_rounded, 'Volumen',
              AnimatedCount(
                  value: _volume.round(), suffix: ' kg', style: Hx.disp(32))),
          const SizedBox(width: 10),
          _tile(Icons.emoji_events_outlined, 'PRs',
              AnimatedCount(
                  value: prs,
                  style: Hx.disp(32, color: prs > 0 ? Hx.lime : Hx.text)),
              highlight: prs > 0),
        ])),
        const SizedBox(height: 16),

        // ── XP y nivel ──
        step(Container(
          padding: const EdgeInsets.all(16),
          decoration: Hx.card(radius: 20, border: Hx.lime),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedCount(
                      value: xpGained,
                      suffix: ' XP',
                      style: Hx.disp(40, color: Hx.lime)),
                  const Text('  ganada',
                      style: TextStyle(color: Hx.muted, fontSize: 13)),
                  const Spacer(),
                  LevelBadge(level: after.level, fontSize: 18),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedBar(fraction: after.levelFraction, height: 10),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                    '${thousands(after.xpIntoLevel)}/${thousands(after.xpForLevel)} XP para Nv. ${after.level + 1}',
                    style: const TextStyle(fontSize: 11, color: Hx.muted)),
              ),
            ],
          ),
        )),

        // ── Banner de nivel nuevo (solo si subiste) ──
        if (leveledUp) ...[
          const SizedBox(height: 12),
          // TweenAnimationBuilder con elasticOut: entra "rebotando".
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.elasticOut,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: Hx.lime, borderRadius: BorderRadius.circular(16)),
              child: Text('¡SUBISTE A NIVEL ${after.level}!',
                  textAlign: TextAlign.center,
                  style: Hx.disp(26, color: Hx.bg)),
            ),
          ),
        ],
        const SizedBox(height: 28),
        step(PushButton(
          title: 'LISTO',
          onTap: () => Navigator.pop(context),
        )),
      ],
    );
  }

  Widget _tile(IconData icon, String label, Widget value,
      {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: Hx.card(border: highlight ? Hx.lime : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: Hx.muted),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: Hx.label()),
            ]),
            const SizedBox(height: 8),
            value,
          ],
        ),
      ),
    );
  }
}
