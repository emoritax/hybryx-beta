// ─────────────────────────────────────────────────────────────────────
// models.dart — Las "formas" de nuestros datos en Dart.
//
// Equivale a tus modelos SQLAlchemy del backend, pero SIN ORM:
// aquí cada clase sabe convertirse desde/hacia un Map, porque sqflite
// entrega y recibe filas como Map<String, Object?> (columna -> valor).
// ─────────────────────────────────────────────────────────────────────

/// Tipos de serie. Un `enum` en vez de un String suelto: si escribes
/// `SetType.warmpu` el compilador te avisa; con 'warmpu' no se daría cuenta.
/// En la base de datos lo guardamos como texto con `.name` ('warmup', ...).
enum SetType { warmup, normal, drop }

// ═════════════════════════ EXERCISE ═════════════════════════

class Exercise {
  // `final` = no cambia después de crearse (inmutable). Más seguro.
  final int? id; // `int?` = puede ser null: antes de guardarse no tiene id
  final String name; // nombre en inglés, ej. "Barbell Bench Press"
  final String muscleGroup; // ej. "Chest"
  final String equipment; // ej. "Barbell"
  final bool isCustom; // true si lo creó el usuario (se puede borrar)

  // Constructor con parámetros nombrados ({...}). `required` obliga a
  // pasarlos; `isCustom` tiene valor por defecto false.
  const Exercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.isCustom = false,
  });

  // `factory` = constructor que puede tener lógica antes de crear el objeto.
  // Recibe una fila de SQLite y la traduce a un Exercise.
  factory Exercise.fromMap(Map<String, Object?> m) => Exercise(
        id: m['id'] as int, // `as int` = "confía, esto es un int"
        name: m['name'] as String,
        muscleGroup: m['muscle_group'] as String, // snake_case en SQL
        equipment: m['equipment'] as String,
        // SQLite no tiene tipo booleano: guardamos 0/1 y comparamos.
        isCustom: (m['is_custom'] as int) == 1,
      );

  // Lo inverso: objeto -> fila. No incluimos 'id' porque SQLite lo
  // genera solo (AUTOINCREMENT) al insertar.
  Map<String, Object?> toMap() => {
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'is_custom': isCustom ? 1 : 0,
      };
}

// ═════════════════════════ ROUTINE ═════════════════════════

class Routine {
  final int id;
  final String name;
  final DateTime createdAt;
  // No es una columna: viene de un COUNT() en la consulta. Lo usamos
  // para mostrar "5 exercises" sin cargar todos los ítems.
  final int itemCount;

  const Routine({
    required this.id,
    required this.name,
    required this.createdAt,
    this.itemCount = 0,
  });

  factory Routine.fromMap(Map<String, Object?> m) => Routine(
        id: m['id'] as int,
        name: m['name'] as String,
        // Guardamos fechas como texto ISO-8601 ("2026-11-02T20:43:00")
        // porque SQLite no tiene tipo fecha. parse() lo convierte de vuelta.
        createdAt: DateTime.parse(m['created_at'] as String),
        // `as int?` + `?? 0`: si la columna no vino, usamos 0.
        itemCount: (m['item_count'] as int?) ?? 0,
      );
}

/// Un ejercicio dentro de una rutina (tu `RoutineItem` del backend).
/// NO es inmutable a propósito: el editor de rutinas cambia sets/reps
/// directamente sobre el objeto y luego guarda la lista completa.
class RoutineItem {
  final int exerciseId;
  final String exerciseName; // viene de un JOIN con exercises
  final String muscleGroup; // para el color de la carta en el mazo
  int targetSets; // series objetivo (todas tipo normal)
  int targetReps; // repeticiones objetivo por serie

  RoutineItem({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    this.targetSets = 3,
    this.targetReps = 10,
  });

  factory RoutineItem.fromMap(Map<String, Object?> m) => RoutineItem(
        exerciseId: m['exercise_id'] as int,
        exerciseName: m['exercise_name'] as String,
        muscleGroup: m['muscle_group'] as String,
        targetSets: m['target_sets'] as int,
        targetReps: m['target_reps'] as int,
      );
}

// ═════════════════════════ WORKOUT ═════════════════════════

/// Una sesión de entrenamiento. Mientras `finishedAt` sea null,
/// el entreno está "en curso" y se puede retomar.
class Workout {
  final int id;
  final int? routineId; // null si fue un entreno vacío (sin rutina)
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const Workout({
    required this.id,
    required this.routineId,
    required this.name,
    required this.startedAt,
    this.finishedAt,
  });

  factory Workout.fromMap(Map<String, Object?> m) => Workout(
        id: m['id'] as int,
        routineId: m['routine_id'] as int?,
        name: m['name'] as String,
        startedAt: DateTime.parse(m['started_at'] as String),
        // Operador ternario: si es null deja null, si no, parsea.
        finishedAt: m['finished_at'] == null
            ? null
            : DateTime.parse(m['finished_at'] as String),
      );
}

/// Un ejercicio dentro de un entreno, con sus series ya cargadas.
class WorkoutExercise {
  final int id;
  final int exerciseId;
  final String exerciseName;
  final List<WorkoutSet> sets; // ordenadas por `position`

  const WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });
}

/// Una serie registrada. Junta tu `RoutineSet` y `DropSet` del backend
/// en UNA tabla: un drop set es simplemente una serie con `parentSetId`
/// apuntando a la serie normal de la que "cuelga".
class WorkoutSet {
  final int id;
  final int workoutExerciseId;
  final int? parentSetId; // solo los drop sets lo tienen
  final int position; // orden de creación
  // Estos 4 cambian mientras entrenas (escribes peso, marcas ✓...).
  SetType type;
  double? weightKg; // null = aún no escrito
  int? reps;
  bool done;

  WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.parentSetId,
    required this.position,
    required this.type,
    this.weightKg,
    this.reps,
    this.done = false,
  });

  factory WorkoutSet.fromMap(Map<String, Object?> m) => WorkoutSet(
        id: m['id'] as int,
        workoutExerciseId: m['workout_exercise_id'] as int,
        parentSetId: m['parent_set_id'] as int?,
        position: m['position'] as int,
        // byName('drop') -> SetType.drop. Lanza error si el texto no existe.
        type: SetType.values.byName(m['set_type'] as String),
        // `num` cubre int y double; toDouble() asegura double siempre.
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        reps: m['reps'] as int?,
        done: (m['done'] as int) == 1,
      );

  // Solo lo que se puede editar. id/position/padres no cambian.
  Map<String, Object?> toUpdateMap() => {
        'set_type': type.name,
        'weight_kg': weightKg,
        'reps': reps,
        'done': done ? 1 : 0,
      };
}

// ═════════════════════════ PROGRESO (datos vivos) ═════════════════════════

/// Una serie hecha, aplanada para cálculos (viene de un JOIN de 4 tablas).
class SetRecord {
  final int workoutId;
  final int exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final double weightKg;
  final int reps;

  const SetRecord({
    required this.workoutId,
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.weightKg,
    required this.reps,
  });

  factory SetRecord.fromMap(Map<String, Object?> m) => SetRecord(
        workoutId: m['workout_id'] as int,
        exerciseId: m['exercise_id'] as int,
        exerciseName: m['exercise_name'] as String,
        muscleGroup: m['muscle_group'] as String,
        weightKg: (m['weight_kg'] as num).toDouble(),
        reps: m['reps'] as int,
      );
}

/// La mejor marca de un ejercicio.
class BestLift {
  final int exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final double weightKg;
  final int reps;
  final double e1rm; // 1RM estimado (ver progress.dart)
  final DateTime date;

  const BestLift({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.weightKg,
    required this.reps,
    required this.e1rm,
    required this.date,
  });
}

/// Todo lo que muestran el encabezado, el perfil y el resumen final.
class Progress {
  final int workouts; // entrenos terminados
  final int doneSets;
  final int prCount;
  final int xp; // XP total acumulada
  final int level;
  final int xpIntoLevel; // XP dentro del nivel actual
  final int xpForLevel; // XP que pide el nivel actual
  final int weekStreak; // semanas seguidas entrenando (actual)
  final int bestWeekStreak;
  final List<bool> thisWeek; // L..D: ¿entrenó ese día?
  final List<BestLift> bestLifts;

  const Progress({
    required this.workouts,
    required this.doneSets,
    required this.prCount,
    required this.xp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForLevel,
    required this.weekStreak,
    required this.bestWeekStreak,
    required this.thisWeek,
    required this.bestLifts,
  });

  /// 0.0–1.0 para la barra de XP.
  double get levelFraction => xpIntoLevel / xpForLevel;
  int get sessionsThisWeek => thisWeek.where((d) => d).length;
}

/// Fila del historial en el perfil.
class WorkoutSummary {
  final int id;
  final String name;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int doneSets;

  const WorkoutSummary({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.finishedAt,
    required this.doneSets,
  });

  Duration get duration => finishedAt.difference(startedAt);

  factory WorkoutSummary.fromMap(Map<String, Object?> m) => WorkoutSummary(
        id: m['id'] as int,
        name: m['name'] as String,
        startedAt: DateTime.parse(m['started_at'] as String),
        finishedAt: DateTime.parse(m['finished_at'] as String),
        doneSets: (m['done_sets'] as int?) ?? 0,
      );
}
