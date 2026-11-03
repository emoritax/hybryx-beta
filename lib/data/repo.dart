// ─────────────────────────────────────────────────────────────────────
// repo.dart — TODAS las consultas a la base de datos en un solo lugar.
//
// Patrón "Repository": las pantallas NUNCA escriben SQL; le piden cosas
// al repo ("dame las rutinas", "guarda esta serie"). Es lo mismo que tus
// funciones CRUD del backend. El día que HYBRYX sincronice con FastAPI,
// solo cambia ESTE archivo.
//
// NUEVO en beta-3: `changes`. Cada escritura "toca la campana" y las
// pantallas que escuchan se recargan solas (patrón Observer). Así el
// Perfil se actualiza al terminar un entreno sin que nadie le avise.
// ─────────────────────────────────────────────────────────────────────

// foundation.dart trae ValueNotifier sin cargar toda la librería de UI.
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'db.dart';
import 'progress.dart';

class Repo {
  // Singleton (ver explicación en db.dart).
  Repo._();
  static final Repo instance = Repo._();

  Future<Database> get _db => AppDatabase.instance.database;

  /// La "campana". ValueNotifier avisa a sus listeners cada vez que su
  /// `value` cambia; subimos un contador solo para provocar ese aviso.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  void _bump() => changes.value++;

  // ═══════════════════════════ SETTINGS ═══════════════════════════

  Future<String> getAlias() async {
    final db = await _db;
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: ['alias']);
    return rows.isEmpty ? 'atleta' : rows.first['value'] as String;
  }

  Future<void> setAlias(String alias) async {
    final db = await _db;
    // REPLACE = si la clave existe la sobrescribe, si no la crea ("upsert").
    await db.insert('settings', {'key': 'alias', 'value': alias.trim()},
        conflictAlgorithm: ConflictAlgorithm.replace);
    _bump();
  }

  // ═══════════════════════════ EXERCISES ═══════════════════════════

  Future<List<Exercise>> getExercises() async {
    final db = await _db;
    final rows = await db.query('exercises', orderBy: 'muscle_group, name');
    return rows.map(Exercise.fromMap).toList();
  }

  /// Si el nombre ya existe, sqflite lanza DatabaseException (UNIQUE).
  Future<Exercise> addCustomExercise({
    required String name,
    required String muscleGroup,
    required String equipment,
  }) async {
    final db = await _db;
    final draft = Exercise(
      name: name.trim(),
      muscleGroup: muscleGroup,
      equipment: equipment,
      isCustom: true,
    );
    final id = await db.insert('exercises', draft.toMap());
    _bump();
    return Exercise(
      id: id,
      name: draft.name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      isCustom: true,
    );
  }

  /// false si no se pudo borrar porque está en uso (ON DELETE RESTRICT).
  Future<bool> deleteCustomExercise(int id) async {
    final db = await _db;
    try {
      await db.delete('exercises',
          where: 'id = ? AND is_custom = 1', whereArgs: [id]);
      _bump();
      return true;
    } on DatabaseException {
      return false;
    }
  }

  // ═══════════════════════════ ROUTINES ═══════════════════════════

  Future<List<Routine>> getRoutines() async {
    final db = await _db;
    // LEFT JOIN: incluye rutinas aunque tengan 0 ítems (COUNT da 0).
    // ASC: el orden de creación es el orden de la rotación (Empuje,
    // Tirón, Pierna...).
    final rows = await db.rawQuery('''
      SELECT r.id, r.name, r.created_at, COUNT(ri.id) AS item_count
      FROM routines r
      LEFT JOIN routine_items ri ON ri.routine_id = r.id
      GROUP BY r.id
      ORDER BY r.created_at ASC
    ''');
    return rows.map(Routine.fromMap).toList();
  }

  Future<int> createRoutine(String name) async {
    final db = await _db;
    final id = await db.insert('routines', {
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    _bump();
    return id;
  }

  Future<void> renameRoutine(int id, String name) async {
    final db = await _db;
    await db.update('routines', {'name': name.trim()},
        where: 'id = ?', whereArgs: [id]);
    _bump();
  }

  Future<void> deleteRoutine(int id) async {
    final db = await _db;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
    _bump();
  }

  Future<List<RoutineItem>> getRoutineItems(int routineId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT ri.exercise_id, e.name AS exercise_name, e.muscle_group,
             ri.target_sets, ri.target_reps
      FROM routine_items ri
      JOIN exercises e ON e.id = ri.exercise_id
      WHERE ri.routine_id = ?
      ORDER BY ri.position
    ''', [routineId]);
    return rows.map(RoutineItem.fromMap).toList();
  }

  /// "Borrar todo y reinsertar" dentro de una transacción (todo o nada).
  /// Más simple que calcular un diff, e instantáneo con ~10 ítems.
  Future<void> saveRoutineItems(int routineId, List<RoutineItem> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Dentro de la transacción se usa `txn`, NUNCA `db` (deadlock).
      await txn.delete('routine_items',
          where: 'routine_id = ?', whereArgs: [routineId]);
      for (var i = 0; i < items.length; i++) {
        await txn.insert('routine_items', {
          'routine_id': routineId,
          'exercise_id': items[i].exerciseId,
          'position': i,
          'target_sets': items[i].targetSets,
          'target_reps': items[i].targetReps,
        });
      }
    });
    _bump();
  }

  /// La rutina que usaste por última vez (para sugerir la siguiente).
  Future<int?> getLastUsedRoutineId() async {
    final db = await _db;
    final rows = await db.query('workouts',
        columns: ['routine_id'],
        where: 'routine_id IS NOT NULL AND finished_at IS NOT NULL',
        orderBy: 'started_at DESC',
        limit: 1);
    return rows.isEmpty ? null : rows.first['routine_id'] as int?;
  }

  // ═══════════════════════════ WORKOUTS ═══════════════════════════

  Future<Workout?> getActiveWorkout() async {
    final db = await _db;
    final rows = await db.query('workouts',
        where: 'finished_at IS NULL', orderBy: 'started_at DESC', limit: 1);
    return rows.isEmpty ? null : Workout.fromMap(rows.first);
  }

  Future<Workout> getWorkout(int id) async {
    final db = await _db;
    final rows = await db.query('workouts', where: 'id = ?', whereArgs: [id]);
    return Workout.fromMap(rows.first);
  }

  /// Crea el entreno y, si viene de rutina, COPIA sus ejercicios y series.
  Future<int> startWorkout({Routine? routine}) async {
    final db = await _db;
    final id = await db.transaction((txn) async {
      final workoutId = await txn.insert('workouts', {
        'routine_id': routine?.id,
        'name': routine?.name ?? 'Entreno libre',
        'started_at': DateTime.now().toIso8601String(),
      });
      if (routine != null) {
        final items = await txn.query('routine_items',
            where: 'routine_id = ?',
            whereArgs: [routine.id],
            orderBy: 'position');
        for (final item in items) {
          final weId = await txn.insert('workout_exercises', {
            'workout_id': workoutId,
            'exercise_id': item['exercise_id'],
            'position': item['position'],
          });
          final setCount = item['target_sets'] as int;
          for (var s = 0; s < setCount; s++) {
            await txn.insert('workout_sets', {
              'workout_exercise_id': weId,
              'position': s,
              'set_type': SetType.normal.name,
              'reps': item['target_reps'],
            });
          }
        }
      }
      return workoutId;
    });
    _bump();
    return id;
  }

  /// Ejercicios + series con SOLO 2 consultas (evita el problema N+1).
  Future<List<WorkoutExercise>> getWorkoutExercises(int workoutId) async {
    final db = await _db;
    final exerciseRows = await db.rawQuery('''
      SELECT we.id, we.exercise_id, e.name AS exercise_name
      FROM workout_exercises we
      JOIN exercises e ON e.id = we.exercise_id
      WHERE we.workout_id = ?
      ORDER BY we.position
    ''', [workoutId]);
    final setRows = await db.rawQuery('''
      SELECT ws.*
      FROM workout_sets ws
      JOIN workout_exercises we ON we.id = ws.workout_exercise_id
      WHERE we.workout_id = ?
      ORDER BY ws.position
    ''', [workoutId]);

    final setsByExercise = <int, List<WorkoutSet>>{};
    for (final row in setRows) {
      final set = WorkoutSet.fromMap(row);
      setsByExercise.putIfAbsent(set.workoutExerciseId, () => []).add(set);
    }
    return exerciseRows.map((row) {
      final id = row['id'] as int;
      return WorkoutExercise(
        id: id,
        exerciseId: row['exercise_id'] as int,
        exerciseName: row['exercise_name'] as String,
        sets: setsByExercise[id] ?? [],
      );
    }).toList();
  }

  Future<void> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      // COALESCE(MAX(position), -1) + 1 = siguiente posición libre.
      final next = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COALESCE(MAX(position), -1) + 1 FROM workout_exercises WHERE workout_id = ?',
              [workoutId])) ??
          0;
      final weId = await txn.insert('workout_exercises', {
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'position': next,
      });
      await txn.insert('workout_sets', {
        'workout_exercise_id': weId,
        'position': 0,
        'set_type': SetType.normal.name,
      });
    });
  }

  Future<void> removeWorkoutExercise(int workoutExerciseId) async {
    final db = await _db;
    await db.delete('workout_exercises',
        where: 'id = ?', whereArgs: [workoutExerciseId]);
  }

  Future<void> addSet(
    int workoutExerciseId,
    SetType type, {
    int? parentSetId,
    double? weightKg,
    int? reps,
  }) async {
    final db = await _db;
    final next = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COALESCE(MAX(position), -1) + 1 FROM workout_sets WHERE workout_exercise_id = ?',
            [workoutExerciseId])) ??
        0;
    await db.insert('workout_sets', {
      'workout_exercise_id': workoutExerciseId,
      'parent_set_id': parentSetId,
      'position': next,
      'set_type': type.name,
      'weight_kg': weightKg,
      'reps': reps,
    });
  }

  /// Se llama en CADA tecla. A propósito NO toca la campana: un entreno
  /// en curso no cambia el progreso (solo cuentan los terminados), y
  /// recargar las otras pestañas en cada tecla sería trabajo inútil.
  Future<void> updateSet(WorkoutSet set) async {
    final db = await _db;
    await db.update('workout_sets', set.toUpdateMap(),
        where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> deleteSet(int setId) async {
    final db = await _db;
    await db.delete('workout_sets', where: 'id = ?', whereArgs: [setId]);
  }

  Future<void> finishWorkout(int workoutId) async {
    final db = await _db;
    await db.update(
        'workouts', {'finished_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [workoutId]);
    _bump();
  }

  /// Descarta un entreno en curso o borra uno del historial.
  Future<void> deleteWorkout(int workoutId) async {
    final db = await _db;
    await db.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
    _bump();
  }

  // ═══════════════════════════ PROGRESO ═══════════════════════════

  /// Series válidas para récords: hechas, no calentamiento, peso y reps
  /// > 0, de entrenos terminados. [excludeWorkoutId] sirve para comparar
  /// el entreno en curso contra "todo lo anterior".
  Future<List<SetRecord>> _setRecords({int? excludeWorkoutId}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT w.id AS workout_id, we.exercise_id, e.name AS exercise_name,
             e.muscle_group, ws.weight_kg, ws.reps
      FROM workout_sets ws
      JOIN workout_exercises we ON we.id = ws.workout_exercise_id
      JOIN workouts w           ON w.id = we.workout_id
      JOIN exercises e          ON e.id = we.exercise_id
      WHERE w.finished_at IS NOT NULL
        AND ws.done = 1
        AND ws.set_type != 'warmup'
        AND ws.weight_kg > 0
        AND ws.reps > 0
        AND w.id != ?
      ORDER BY w.started_at, ws.position
    ''', [excludeWorkoutId ?? -1]); // -1 = no excluir ninguno
    return rows.map(SetRecord.fromMap).toList();
  }

  /// Todo el progreso (XP, nivel, racha, PRs). Lo pesado (recorrer
  /// series) se hace en Dart con funciones puras de progress.dart.
  Future<Progress> getProgress() async {
    final db = await _db;
    final workoutRows = await db.query('workouts',
        where: 'finished_at IS NOT NULL', orderBy: 'started_at ASC');
    final doneSets = Sqflite.firstIntValue(await db.rawQuery('''
          SELECT COUNT(*) FROM workout_sets ws
          JOIN workout_exercises we ON we.id = ws.workout_exercise_id
          JOIN workouts w ON w.id = we.workout_id
          WHERE ws.done = 1 AND w.finished_at IS NOT NULL
        ''')) ??
        0;
    return computeProgress(
      finished: workoutRows.map(Workout.fromMap).toList(),
      sets: await _setRecords(),
      doneSetCount: doneSets,
      now: DateTime.now(),
    );
  }

  /// Mejor 1RM estimado por ejercicio, sin contar [excludeWorkoutId].
  /// El entreno en vivo lo usa para detectar PRs al instante.
  Future<Map<int, double>> getBestE1rmByExercise({int? excludeWorkoutId}) async {
    final best = <int, double>{};
    for (final s in await _setRecords(excludeWorkoutId: excludeWorkoutId)) {
      final v = estimate1rm(s.weightKg, s.reps);
      if (v > (best[s.exerciseId] ?? 0)) best[s.exerciseId] = v;
    }
    return best;
  }

  /// Historial para el perfil: subconsulta que cuenta series hechas.
  Future<List<WorkoutSummary>> getRecentWorkouts({int limit = 20}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT w.id, w.name, w.started_at, w.finished_at,
        (SELECT COUNT(*) FROM workout_sets ws
           JOIN workout_exercises we ON we.id = ws.workout_exercise_id
          WHERE we.workout_id = w.id AND ws.done = 1) AS done_sets
      FROM workouts w
      WHERE w.finished_at IS NOT NULL
      ORDER BY w.started_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(WorkoutSummary.fromMap).toList();
  }
}
