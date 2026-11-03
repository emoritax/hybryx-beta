// ─────────────────────────────────────────────────────────────────────
// seed_exercises.dart — Catálogo inicial de ejercicios de gimnasio.
// Se inserta UNA sola vez, cuando se crea la base de datos.
// ─────────────────────────────────────────────────────────────────────

/// Grupos musculares disponibles (filtros y dropdown de "nuevo ejercicio").
/// `const` = se calcula en compilación, vive una sola vez en memoria.
const muscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps',
  'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Core',
];

/// Tipos de equipo.
const equipmentTypes = [
  'Barbell', 'Dumbbell', 'Machine', 'Cable', 'Bodyweight',
  'EZ Bar', 'Smith Machine', 'Kettlebell', 'Other',
];

/// Cada ejercicio es un "record" de Dart 3: (nombre, músculo, equipo).
/// Un record es como una tupla de Python: agrupa valores sin crear clase.
/// Solo ejercicios de peso × reps: nada por tiempo (plank) ni distancia
/// (cardio), porque la beta solo registra kg y repeticiones.
const seedExercises = [
  // ── Chest ──
  ('Barbell Bench Press', 'Chest', 'Barbell'),
  ('Incline Barbell Bench Press', 'Chest', 'Barbell'),
  ('Decline Barbell Bench Press', 'Chest', 'Barbell'),
  ('Dumbbell Bench Press', 'Chest', 'Dumbbell'),
  ('Incline Dumbbell Bench Press', 'Chest', 'Dumbbell'),
  ('Dumbbell Fly', 'Chest', 'Dumbbell'),
  ('Cable Crossover', 'Chest', 'Cable'),
  ('Pec Deck', 'Chest', 'Machine'),
  ('Chest Press Machine', 'Chest', 'Machine'),
  ('Push-Up', 'Chest', 'Bodyweight'),
  ('Chest Dip', 'Chest', 'Bodyweight'),
  // ── Back ──
  ('Deadlift', 'Back', 'Barbell'),
  ('Barbell Row', 'Back', 'Barbell'),
  ('One-Arm Dumbbell Row', 'Back', 'Dumbbell'),
  ('Pull-Up', 'Back', 'Bodyweight'),
  ('Chin-Up', 'Back', 'Bodyweight'),
  ('Lat Pulldown', 'Back', 'Cable'),
  ('Seated Cable Row', 'Back', 'Cable'),
  ('T-Bar Row', 'Back', 'Barbell'),
  ('Seated Machine Row', 'Back', 'Machine'),
  ('Straight-Arm Pulldown', 'Back', 'Cable'),
  ('Back Extension', 'Back', 'Bodyweight'),
  ('Barbell Shrug', 'Back', 'Barbell'),
  ('Dumbbell Shrug', 'Back', 'Dumbbell'),
  // ── Shoulders ──
  ('Overhead Press', 'Shoulders', 'Barbell'),
  ('Seated Dumbbell Shoulder Press', 'Shoulders', 'Dumbbell'),
  ('Arnold Press', 'Shoulders', 'Dumbbell'),
  ('Shoulder Press Machine', 'Shoulders', 'Machine'),
  ('Dumbbell Lateral Raise', 'Shoulders', 'Dumbbell'),
  ('Cable Lateral Raise', 'Shoulders', 'Cable'),
  ('Dumbbell Front Raise', 'Shoulders', 'Dumbbell'),
  ('Rear Delt Fly', 'Shoulders', 'Dumbbell'),
  ('Reverse Pec Deck', 'Shoulders', 'Machine'),
  ('Face Pull', 'Shoulders', 'Cable'),
  ('Upright Row', 'Shoulders', 'Barbell'),
  // ── Biceps ──
  ('Barbell Curl', 'Biceps', 'Barbell'),
  ('EZ Bar Curl', 'Biceps', 'EZ Bar'),
  ('Dumbbell Curl', 'Biceps', 'Dumbbell'),
  ('Hammer Curl', 'Biceps', 'Dumbbell'),
  ('Incline Dumbbell Curl', 'Biceps', 'Dumbbell'),
  ('Preacher Curl', 'Biceps', 'EZ Bar'),
  ('Concentration Curl', 'Biceps', 'Dumbbell'),
  ('Cable Curl', 'Biceps', 'Cable'),
  // ── Triceps ──
  ('Triceps Pushdown', 'Triceps', 'Cable'),
  ('Rope Triceps Pushdown', 'Triceps', 'Cable'),
  ('Overhead Cable Triceps Extension', 'Triceps', 'Cable'),
  ('Dumbbell Overhead Triceps Extension', 'Triceps', 'Dumbbell'),
  ('Skull Crusher', 'Triceps', 'EZ Bar'),
  ('Close-Grip Bench Press', 'Triceps', 'Barbell'),
  ('Triceps Dip', 'Triceps', 'Bodyweight'),
  ('Triceps Kickback', 'Triceps', 'Dumbbell'),
  // ── Quads ──
  ('Back Squat', 'Quads', 'Barbell'),
  ('Front Squat', 'Quads', 'Barbell'),
  ('Smith Machine Squat', 'Quads', 'Smith Machine'),
  ('Goblet Squat', 'Quads', 'Dumbbell'),
  ('Leg Press', 'Quads', 'Machine'),
  ('Hack Squat', 'Quads', 'Machine'),
  ('Leg Extension', 'Quads', 'Machine'),
  ('Bulgarian Split Squat', 'Quads', 'Dumbbell'),
  ('Walking Lunge', 'Quads', 'Dumbbell'),
  // ── Hamstrings ──
  ('Romanian Deadlift', 'Hamstrings', 'Barbell'),
  ('Dumbbell Romanian Deadlift', 'Hamstrings', 'Dumbbell'),
  ('Lying Leg Curl', 'Hamstrings', 'Machine'),
  ('Seated Leg Curl', 'Hamstrings', 'Machine'),
  ('Good Morning', 'Hamstrings', 'Barbell'),
  // ── Glutes ──
  ('Barbell Hip Thrust', 'Glutes', 'Barbell'),
  ('Glute Bridge', 'Glutes', 'Bodyweight'),
  ('Sumo Deadlift', 'Glutes', 'Barbell'),
  ('Cable Glute Kickback', 'Glutes', 'Cable'),
  ('Hip Abduction Machine', 'Glutes', 'Machine'),
  ('Kettlebell Swing', 'Glutes', 'Kettlebell'),
  // ── Calves ──
  ('Standing Calf Raise', 'Calves', 'Machine'),
  ('Seated Calf Raise', 'Calves', 'Machine'),
  ('Leg Press Calf Raise', 'Calves', 'Machine'),
  // ── Core ──
  ('Crunch', 'Core', 'Bodyweight'),
  ('Cable Crunch', 'Core', 'Cable'),
  ('Hanging Leg Raise', 'Core', 'Bodyweight'),
  ('Ab Wheel Rollout', 'Core', 'Other'),
  ('Decline Sit-Up', 'Core', 'Bodyweight'),
  ('Russian Twist', 'Core', 'Bodyweight'),
];
