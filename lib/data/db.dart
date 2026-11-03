// ─────────────────────────────────────────────────────────────────────
// db.dart — Abre la base de datos SQLite local y crea las tablas.
//
// Equivale a tu `database.py` + `Base.metadata.create_all()` del backend,
// pero el archivo .db vive DENTRO del celular (carpeta privada de la app).
// ─────────────────────────────────────────────────────────────────────

// join() une carpeta + nombre de archivo con el separador correcto.
import 'package:path/path.dart';
// Database, openDatabase, getDatabasesPath, Batch...
import 'package:sqflite/sqflite.dart';

import 'seed_exercises.dart';

/// Patrón Singleton: una ÚNICA conexión para toda la app.
/// ¿Por qué? Abrir SQLite cuesta, y dos conexiones escribiendo al tiempo
/// pueden pisarse. Con una sola instancia todos comparten la misma.
class AppDatabase {
  // Constructor privado (`._()`): nadie fuera de este archivo puede hacer
  // `AppDatabase()`. La única forma de obtenerla es `AppDatabase.instance`.
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  // La conexión real. Empieza en null y se llena la primera vez.
  Database? _db;

  /// Getter asíncrono: `await AppDatabase.instance.database`.
  /// `??=` significa "si _db es null, asígnale esto; si no, déjalo".
  /// Así abrimos la DB solo la primera vez (inicialización perezosa).
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    // Carpeta estándar de bases de datos de la app en Android
    // (/data/data/<paquete>/databases). Solo la app puede leerla.
    final dir = await getDatabasesPath();
    final path = join(dir, 'hybryx_beta.db');

    return openDatabase(
      path,
      // Versión del esquema. v1 = beta-2. v2 agrega la tabla `settings`.
      // sqflite guarda el número dentro del .db y, al abrir, compara:
      //   archivo no existe        -> onCreate (instalación nueva)
      //   archivo con versión < 2  -> onUpgrade (ya tenías beta-2)
      version: 2,
      // onConfigure corre ANTES que todo en cada apertura.
      // SQLite trae las foreign keys APAGADAS por defecto (!). Sin esta
      // línea, ON DELETE CASCADE no haría nada y quedarían filas huérfanas.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      // La MIGRACIÓN (tu Alembic): lleva un .db viejo a la versión nueva
      // SIN borrar datos. Por esto, actualizar a beta-3 conserva tus
      // entrenos. Cada `if` aplica un salto de versión, en orden.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSettings(db);
      },
    );
  }

  /// Tabla clave/valor para preferencias (alias del usuario, etc.).
  /// Clave/valor en vez de columnas: agregar una preferencia nueva no
  /// requiere migración, solo una fila nueva.
  static Future<void> _createSettings(DatabaseExecutor db) => db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

  Future<void> _onCreate(Database db, int version) async {
    // Un Batch acumula muchas operaciones y las ejecuta juntas en una
    // transacción: ~90 inserts en un solo viaje, mucho más rápido.
    final batch = db.batch();

    // ── Catálogo de ejercicios ──
    // COLLATE NOCASE en UNIQUE: "bench press" y "Bench Press" cuentan
    // como el mismo nombre -> evita duplicados al crear personalizados.
    batch.execute('''
      CREATE TABLE exercises (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
        muscle_group TEXT    NOT NULL,
        equipment    TEXT    NOT NULL,
        is_custom    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── Rutinas (plantillas) ──
    batch.execute('''
      CREATE TABLE routines (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ── Ejercicios de cada rutina ──
    // CASCADE: borrar la rutina borra sus ítems.
    // RESTRICT: NO deja borrar un ejercicio que una rutina usa.
    batch.execute('''
      CREATE TABLE routine_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id  INTEGER NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
        position    INTEGER NOT NULL,
        target_sets INTEGER NOT NULL DEFAULT 3,
        target_reps INTEGER NOT NULL DEFAULT 10
      )
    ''');

    // ── Entrenos (sesiones reales) ──
    // SET NULL: si borras la rutina, el entreno hecho NO se borra
    // (es historia); solo pierde la referencia a la rutina.
    batch.execute('''
      CREATE TABLE workouts (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id  INTEGER REFERENCES routines(id) ON DELETE SET NULL,
        name        TEXT NOT NULL,
        started_at  TEXT NOT NULL,
        finished_at TEXT
      )
    ''');

    // ── Ejercicios dentro de un entreno ──
    batch.execute('''
      CREATE TABLE workout_exercises (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id  INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
        position    INTEGER NOT NULL
      )
    ''');

    // ── Series ──
    // parent_set_id apunta a la MISMA tabla (auto-referencia): así un
    // drop set "cuelga" de su serie normal. CASCADE: si borras la serie
    // normal, se van sus drops. CHECK limita set_type a 3 valores.
    batch.execute('''
      CREATE TABLE workout_sets (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
        parent_set_id       INTEGER REFERENCES workout_sets(id) ON DELETE CASCADE,
        position            INTEGER NOT NULL,
        set_type            TEXT    NOT NULL CHECK (set_type IN ('warmup', 'normal', 'drop')),
        weight_kg           REAL,
        reps                INTEGER,
        done                INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ── Sembrar el catálogo ──
    // `for (final (name, muscle, equipment) in ...)` es un "pattern" de
    // Dart 3: desarma cada record en tres variables de una vez.
    for (final (name, muscle, equipment) in seedExercises) {
      batch.insert('exercises', {
        'name': name,
        'muscle_group': muscle,
        'equipment': equipment,
        'is_custom': 0,
      });
    }

    // noResult: true = no necesitamos los ids devueltos; ahorra memoria.
    await batch.commit(noResult: true);

    // Instalación nueva: también crea lo que agregaron las migraciones.
    await _createSettings(db);
  }
}
