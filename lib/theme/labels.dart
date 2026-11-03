// ─────────────────────────────────────────────────────────────────────
// labels.dart — Textos en español para datos que en la DB están en inglés.
//
// La DB guarda 'Chest', 'Barbell'... (estable, sirve para el backend y
// para otros idiomas). La UI los TRADUCE al mostrarlos. Separar "dato" de
// "cómo se muestra" es lo que permite cambiar de idioma sin migrar datos.
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'hx.dart';

const muscleEs = {
  'Chest': 'Pecho',
  'Back': 'Espalda',
  'Shoulders': 'Hombros',
  'Biceps': 'Bíceps',
  'Triceps': 'Tríceps',
  'Quads': 'Cuádriceps',
  'Hamstrings': 'Isquios',
  'Glutes': 'Glúteos',
  'Calves': 'Pantorrillas',
  'Core': 'Core',
};

const equipmentEs = {
  'Barbell': 'Barra',
  'Dumbbell': 'Mancuerna',
  'Machine': 'Máquina',
  'Cable': 'Polea',
  'Bodyweight': 'Peso corporal',
  'EZ Bar': 'Barra EZ',
  'Smith Machine': 'Smith',
  'Kettlebell': 'Kettlebell',
  'Other': 'Otro',
};

/// `?? key`: si falta la traducción, mostramos el original (no se rompe).
String muscleLabel(String key) => muscleEs[key] ?? key;
String equipmentLabel(String key) => equipmentEs[key] ?? key;

/// Familias de movimiento → color de la "banda" de cada carta del mazo.
/// Agrupar por patrón (empuje/tirón/pierna) es como piensa un atleta.
enum MoveFamily { push, pull, legs, core }

MoveFamily familyOf(String muscle) => switch (muscle) {
      'Chest' || 'Shoulders' || 'Triceps' => MoveFamily.push,
      'Back' || 'Biceps' => MoveFamily.pull,
      'Core' => MoveFamily.core,
      _ => MoveFamily.legs, // Quads, Hamstrings, Glutes, Calves
    };

Color familyColor(MoveFamily f) => switch (f) {
      MoveFamily.push => Hx.blue,
      MoveFamily.pull => Hx.orange,
      MoveFamily.legs => Hx.violet,
      MoveFamily.core => Hx.lime,
    };

String familyLabel(MoveFamily f) => switch (f) {
      MoveFamily.push => 'Empuje',
      MoveFamily.pull => 'Tirón',
      MoveFamily.legs => 'Pierna',
      MoveFamily.core => 'Core',
    };

Color muscleColor(String muscle) => familyColor(familyOf(muscle));

// ── Fechas en español (sin paquete intl, para no sumar dependencias) ──
const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// 2026-11-02 -> "2 nov 2026"
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "hace 5 min", "hace 2 h", "hace 3 días"
String timeAgo(DateTime d, DateTime now) {
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} días';
}

/// 05:07 o 1:05:07
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// 1240 -> "1.240" (separador de miles al estilo colombiano).
String thousands(num n) {
  final s = n.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    // Insertamos un punto cada 3 cifras contando desde la derecha.
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 80.0 -> "80", 82.5 -> "82.5"
String kg(double? w) {
  if (w == null) return '';
  return w == w.roundToDouble() ? w.toInt().toString() : w.toString();
}
