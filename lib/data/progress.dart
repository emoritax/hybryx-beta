// ─────────────────────────────────────────────────────────────────────
// progress.dart — El "motor" de gamificación: XP, niveles, rachas y PRs.
//
// Son funciones PURAS: reciben datos y devuelven un resultado, sin tocar
// la base de datos ni la pantalla. Ventajas:
//   1. Se pueden probar con tests unitarios fácilmente.
//   2. El día que el backend calcule los rankings, esta lógica se porta
//      casi línea por línea a Python.
// ─────────────────────────────────────────────────────────────────────

import '../models/models.dart';

// ── Reglas de XP (ajustables: es lo que hay que balancear en la beta) ──
const xpPerWorkout = 50; // por terminar un entreno
const xpPerSet = 5; // por cada serie marcada ✓
const xpPerPr = 25; // por cada récord personal

/// 1RM estimado con la fórmula de Epley: peso × (1 + reps/30).
/// ¿Por qué? Para comparar 100 kg × 5 contra 110 kg × 2 necesitamos una
/// sola medida. Epley estima cuánto levantarías a 1 repetición.
double estimate1rm(double weightKg, int reps) =>
    reps <= 1 ? weightKg : weightKg * (1 + reps / 30);

/// XP que pide cada nivel: 200, 300, 400... sube 100 por nivel.
/// Curva creciente = los primeros niveles llegan rápido (enganchan) y los
/// altos cuestan (dan estatus).
int xpNeededFor(int level) => 200 + 100 * (level - 1);

/// Convierte XP total en (nivel, XP dentro del nivel, XP del nivel).
/// Devuelve un *record* con nombres: `r.level`, `r.into`, `r.needed`.
({int level, int into, int needed}) levelFromXp(int xp) {
  var level = 1;
  var rest = xp;
  // Restamos el costo de cada nivel mientras alcance.
  while (rest >= xpNeededFor(level)) {
    rest -= xpNeededFor(level);
    level++;
  }
  return (level: level, into: rest, needed: xpNeededFor(level));
}

/// Lunes (00:00) de la semana de `d`. weekday: lunes=1 ... domingo=7.
/// Construimos con DateTime(y, m, d - n) en vez de restar Duration para
/// que Dart normalice el día (ej. día 0 = último del mes anterior).
DateTime weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calcula todo el progreso.
/// [finished]: entrenos terminados, ORDENADOS por fecha ascendente.
/// [sets]: series hechas (sin calentamiento, con peso y reps > 0), en el
///         mismo orden cronológico.
/// [doneSetCount]: total de series ✓ (incluye calentamientos) para la XP.
Progress computeProgress({
  required List<Workout> finished,
  required List<SetRecord> sets,
  required int doneSetCount,
  required DateTime now,
}) {
  // ── 1. Récords personales ──
  // Agrupamos series por entreno para comparar "el mejor de hoy" contra
  // "el mejor de antes". Si comparáramos serie por serie, 3 series
  // subiendo de peso en el mismo día contarían como 3 PRs.
  final byWorkout = <int, List<SetRecord>>{};
  for (final s in sets) {
    byWorkout.putIfAbsent(s.workoutId, () => []).add(s);
  }

  final best = <int, BestLift>{}; // exerciseId -> mejor marca hasta ahora
  var prCount = 0;
  for (final w in finished) {
    // Mejor serie de cada ejercicio EN este entreno.
    final top = <int, SetRecord>{};
    for (final s in byWorkout[w.id] ?? const <SetRecord>[]) {
      final current = top[s.exerciseId];
      if (current == null ||
          estimate1rm(s.weightKg, s.reps) >
              estimate1rm(current.weightKg, current.reps)) {
        top[s.exerciseId] = s;
      }
    }
    for (final s in top.values) {
      final value = estimate1rm(s.weightKg, s.reps);
      final prev = best[s.exerciseId];
      if (prev == null || value > prev.e1rm) {
        // La PRIMERA vez que haces un ejercicio es tu línea base, no un
        // récord. Solo cuenta como PR si superas una marca previa.
        if (prev != null) prCount++;
        best[s.exerciseId] = BestLift(
          exerciseId: s.exerciseId,
          exerciseName: s.exerciseName,
          muscleGroup: s.muscleGroup,
          weightKg: s.weightKg,
          reps: s.reps,
          e1rm: value,
          date: w.startedAt,
        );
      }
    }
  }

  // ── 2. Racha semanal ──
  // En gym se descansa, así que una racha DIARIA castigaría el descanso.
  // Medimos semanas consecutivas con al menos un entreno.
  final weeks = finished.map((w) => weekStart(w.startedAt)).toSet();
  final thisWeek = weekStart(now);
  // Si esta semana aún no entrenas, la racha sigue viva (tienes hasta el
  // domingo): empezamos a contar desde la semana pasada.
  var cursor = weeks.contains(thisWeek) ? thisWeek : _addDays(thisWeek, -7);
  var weekStreak = 0;
  while (weeks.contains(cursor)) {
    weekStreak++;
    cursor = _addDays(cursor, -7);
  }

  // Mejor racha histórica: recorrer semanas ordenadas contando seguidas.
  final sortedWeeks = weeks.toList()..sort();
  var bestWeekStreak = 0;
  var run = 0;
  DateTime? previous;
  for (final w in sortedWeeks) {
    run = (previous != null && _addDays(previous, 7) == w) ? run + 1 : 1;
    if (run > bestWeekStreak) bestWeekStreak = run;
    previous = w;
  }

  // ── 3. Días entrenados esta semana (L..D) ──
  final days = List<bool>.generate(7, (i) {
    final day = _addDays(thisWeek, i);
    return finished.any((w) => _sameDay(w.startedAt, day));
  });

  // ── 4. XP y nivel ──
  final xp =
      finished.length * xpPerWorkout + doneSetCount * xpPerSet + prCount * xpPerPr;
  final lvl = levelFromXp(xp);

  // ── 5. Mejores marcas: las 5 más recientes ──
  final lifts = best.values.toList()
    ..sort((a, b) => b.date.compareTo(a.date)); // descendente

  return Progress(
    workouts: finished.length,
    doneSets: doneSetCount,
    prCount: prCount,
    xp: xp,
    level: lvl.level,
    xpIntoLevel: lvl.into,
    xpForLevel: lvl.needed,
    weekStreak: weekStreak,
    bestWeekStreak: bestWeekStreak,
    thisWeek: days,
    bestLifts: lifts.take(5).toList(),
  );
}
