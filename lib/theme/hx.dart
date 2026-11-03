// ─────────────────────────────────────────────────────────────────────
// hx.dart — Sistema de diseño de HYBRYX: colores, tipografías y tema.
//
// ¿Por qué centralizarlo? Si mañana el lima cambia de tono, se cambia en
// UN lugar y toda la app se actualiza. Los valores salen del diseño de
// "Navegación principal" (#0E1116 de fondo, #C6F432 de acento, etc.).
// ─────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Clase solo con constantes `static`: se usa como `Hx.lime`, sin instanciar.
abstract final class Hx {
  // ── Superficies (de más oscura a más clara) ──
  static const navBg = Color(0xFF0A0D11); // barra inferior
  static const bg = Color(0xFF0E1116); // fondo de pantalla
  static const surface = Color(0xFF171B22); // tarjetas
  static const surface2 = Color(0xFF1D222B); // cartas del mazo, inputs
  static const line = Color(0xFF232A33); // bordes y separadores
  static const line2 = Color(0xFF2C3440); // bordes más visibles

  // ── Texto ──
  static const text = Color(0xFFE8ECF1);
  static const muted = Color(0xFF9AA3AE); // texto secundario
  static const dim = Color(0xFF7D8794); // íconos inactivos

  // ── Acentos ──
  static const lime = Color(0xFFC6F432); // color de marca
  static const limeDark = Color(0xFF7FA012); // "sombra 3D" del botón lima
  static const limeTint = Color(0xFF1E2614); // fondo de algo seleccionado
  static const orange = Color(0xFFFF9A4D); // racha / fuego
  static const orangeTint = Color(0xFF231A12);
  static const blue = Color(0xFF8FB2FF);
  static const violet = Color(0xFFC9A3FF);
  static const danger = Color(0xFFFF6B6B);

  // ── Familias de fuente (nombres declarados en pubspec.yaml) ──
  static const display = 'BarlowCondensed';
  static const body = 'DMSans';

  /// Atajo para títulos/números estilo deportivo.
  /// height: 1 quita el espacio extra arriba/abajo de la fuente.
  static TextStyle disp(double size,
          {FontWeight weight = FontWeight.w800, Color? color, double? spacing}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1,
        letterSpacing: spacing,
      );

  /// Etiquetas en mayúscula espaciada ("RUTINA DE HOY").
  static TextStyle label({Color color = muted}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: color,
      );

  /// Decoración estándar de tarjeta: fondo + borde fino + esquinas.
  static BoxDecoration card({double radius = 16, Color? border}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? line),
      );

  /// El ThemeData de la app: configura TODOS los widgets de Material para
  /// que ya salgan con nuestros colores (botones, inputs, diálogos...).
  static ThemeData theme() {
    final scheme = const ColorScheme.dark(
      primary: lime,
      onPrimary: bg, // texto encima del lima
      secondary: orange,
      surface: surface,
      onSurface: text,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: body,
      // Transición tipo "zoom" de Android al abrir pantallas.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      }),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0, // sin cambio de color al hacer scroll
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        isDense: true,
        hintStyle: const TextStyle(color: dim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lime, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true, // la "rayita" para arrastrar y cerrar
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating, // flota sobre la barra
        backgroundColor: surface2,
        contentTextStyle: const TextStyle(color: text, fontFamily: body),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: bg,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: body),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: lime),
      ),
    );
  }
}
