// ─────────────────────────────────────────────────────────────────────
// repo.dart — TODAS las consultas a la base de datos en un solo lugar.
//
// Patrón "Repository": las pantallas NUNCA escriben SQL; le piden cosas
// al repo ("dame las rutinas", "guarda esta serie"). Es lo mismo que tus
// funciones CRUD del backend. Ventaja: el día que HYBRYX sincronice con
// tu API FastAPI, solo cambias ESTE archivo y las pantallas ni se enteran.
// ─────────────────────────────────────────────────────────────────────

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'db.dart';

class Repo {
  // Singleton, igual que AppDatabase (ver explicación en db.dart).
  Repo._();
  static final Repo instance = Repo._();

  // Atajo privado para no escribir `AppDatabase.instance.database` siempre.
  Future<Database> get _db => AppDatabase.instance.database;

  // ═══════════════════════════ EXERCISES ═══════════════════════════

  Future<List<Exercise>> getExercises() async {
    final db = await _db;
    // query() arma el SELECT por nosotros: SELECT * FROM exercises ORDER BY ...
    final rows = await db.query('exercises', orderBy: 'muscle_group, name');
    // `Exercise.fromMap` sin paréntesis = pasamos la función como valor
    // ("tear-off"); map() la aplica a cada fila.
    return rows.map(Exercise.fromMap).toList();
  }

  /// Crea un ejercicio personalizado. Si el nombre ya existe, sqflite
  /// lanza DatabaseException (por el UNIQUE) y quien llama la atrapa.
  Future<Exercise> addCustomExercise({
    required String name,
    required String muscleGroup,
    required String equipment,
  }) async {
    final db = await _db;
    final draft = Exercise(
      name: name.trim(), // trim() quita espacios al inicio/final
      muscleGroup: muscleGroup,
      equipment: equipment,
      isCustom: true,
    );
    // insert() devuelve el id que SQLite asignó.
    final id = await db.insert('exercises', draft.toMap());
    // Devolvemos un objeto completo, ahora sí con id.
    return Exercise(
      id: id,
      name: draft.name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      isCustom: true,
    );
  }

  /// Devuelve false si no se pudo borrar porque está en uso.
  Future<bool> deleteCustomExercise(int id) async {
    final db = await _db;
    try {
      // `is_custom = 1` en el WHERE: blindaje extra para que nunca se
      // borre un ejercicio del catálogo base aunque la UI fallara.
      // `?` + whereArgs = parámetros seguros (evita SQL injection).
      await db.delete('exercises',
          where: 'id = ? AND is_custom = 1', whereArgs: [id]);
      return true;
    } on DatabaseException {
      // ON DELETE RESTRICT disparó: el ejercicio está en una rutina/entreno.
      return false;
    }
  }

  // ═══════════════════════════ ROUTINES ═══════════════════════════

  Future<List<Routine>> getRoutines() async {
    final db = await _db;
    // rawQuery = SQL escrito a mano (query() no sabe hacer JOIN/GROUP BY).
    // LEFT JOIN: incluye rutinas aunque tengan 0 ítems (COUNT da 0).
    final rows = await db.rawQuery('''
      SELECT r.id, r.name, r.created_at, COUNT(ri.id) AS item_count
      FROM routines r
      LEFT JOIN routine_items ri ON ri.routine_id = r.id
      GROUP BY r.id
      ORDER BY r.created_at DESC
    ''');
    return rows.map(Routine.fromMap).toList();
  }

  Future<int> createRoutine(String name) async {
    final db = await _db;
    return db.insert('routines', {
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> renameRoutine(int id, String name) async {
    final db = await _db;
    await db.update('routines', {'name': name.trim()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteRoutine(int id) async {
    final db = await _db;
    // CASCADE se lleva los routine_items automáticamente.
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RoutineItem>> getRoutineItems(int routineId) async {
    final db = await _db;
    // JOIN para traer el nombre del ejercicio en la misma consulta.
    final rows = await db.rawQuery('''
      SELECT ri.exercise_id, e.name AS exercise_name,
             ri.target_sets, ri.target_reps
      FROM routine_items ri
      JOIN exercises e ON e.id = ri.exercise_id
      WHERE ri.routine_id = ?
      ORDER BY ri.position
    ''', [routineId]);
    return rows.map(RoutineItem.fromMap).toList();
  }

  /// Estrategia "borrar todo y reinsertar". ¿Por qué? El editor permite
  /// reordenar, quitar y agregar libremente. Calcular qué cambió (diff)
  /// es complejo; reemplazar la lista entera es simple y, con ~10 ítems,
  /// instantáneo. La transacción garantiza "todo o nada": si algo falla
  /// a la mitad, no queda la rutina medio borrada.
  Future<void> saveRoutineItems(int routineId, List<RoutineItem> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      // OJO: dentro de la transacción se usa `txn`, NUNCA `db`.
      // Usar `db` aquí bloquearía la app (espera a que termine la
      // transacción que a su vez lo espera a él = deadlock).
      await txn.delete('routine_items',
          where: 'routine_id = ?', whereArgs: [routineId]);
      for (var i = 0; i < items.length; i++) {
        await txn.insert('routine_items', {
          'routine_id': routineId,
          'exercise_id': items[i].exerciseId,
          'position': i, // el índice en la lista ES el orden
          'target_sets': items[i].targetSets,
          'target_reps': items[i].targetReps,
        });
      }
    });
  }

  // ═══════════════════════════ WORKOUTS ═══════════════════════════

  /// El entreno sin terminar (si existe). Permite "Resume" si cerraste
  /// la app o el celular se apagó a mitad del gym.
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

  /// Crea el entreno. Si viene de una rutina, COPIA sus ejercicios y crea
  /// las series objetivo. Copiamos (no referenciamos) para que editar la
  /// rutina después no altere entrenos ya hechos.
  Future<int> startWorkout({Routine? routine}) async {
    final db = await _db;
    return db.transaction((txn) async {
      final workoutId = await txn.insert('workouts', {
        'routine_id': routine?.id, // `?.` = si routine es null, da null
        'name': routine?.name ?? 'Empty Workout',
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
              // Pre-llenamos las reps objetivo; el peso queda vacío.
              'reps': item['target_reps'],
            });
          }
        }
      }
      return workoutId;
    });
  }

  /// Carga ejercicios + series de un entreno con SOLO 2 consultas.
  /// Lo ingenuo sería 1 consulta por ejercicio (problema N+1, el mismo
  /// que resolviste con `selectinload` en SQLAlchemy). Aquí traemos todas
  /// las series de golpe y las agrupamos en Dart con un Map.
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

    // Agrupar: id del workout_exercise -> lista de sus series.
    final setsByExercise = <int, List<WorkoutSet>>{};
    for (final row in setRows) {
      final set = WorkoutSet.fromMap(row);
      // putIfAbsent: si la llave no existe, crea la lista vacía; luego add.
      setsByExercise.putIfAbsent(set.workoutExerciseId, () => []).add(set);
    }

    return exerciseRows.map((row) {
      final id = row['id'] as int;
      return WorkoutExercise(
        id: id,
        exerciseId: row['exercise_id'] as int,
        exerciseName: row['exercise_name'] as String,
        sets: setsByExercise[id] ?? [], // ejercicio sin series -> lista vacía
      );
    }).toList();
  }

  /// Agrega un ejercicio al final del entreno, con 1 serie normal vacía
  /// para que el usuario pueda escribir de una vez.
  Future<void> addExerciseToWorkout(int workoutId, int exerciseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      // COALESCE(MAX(position), -1) + 1: siguiente posición libre.
      // Si no hay ninguna, MAX da NULL -> COALESCE lo vuelve -1 -> +1 = 0.
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
    // CASCADE borra sus series (y los drops de esas series).
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

  /// Se llama en CADA cambio (cada tecla en kg/reps, cada ✓). Guardar al
  /// instante = si la app se cierra a mitad de entreno, no pierdes nada.
  /// SQLite local es rapidísimo, así que no hace falta "debounce".
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
  }

  Future<void> discardWorkout(int workoutId) async {
    final db = await _db;
    // CASCADE limpia workout_exercises y workout_sets.
    await db.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }
}
