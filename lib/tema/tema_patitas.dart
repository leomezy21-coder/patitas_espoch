import 'package:flutter/material.dart';

/// Define el tema visual institucional de Patitas ESPOCH utilizando Material 3.
/// Incluye la paleta calida del diseno oficial en Figma (crema, marron, naranja
/// y verde institucional) junto con los colores base de los modulos generales.
class TemaPatitas {
  // Paleta base institucional y de modulos generales
  static const Color colorVerdePrimario = Color(0xFF1E6B52);
  static const Color colorVerdeOscuro = Color(0xFF134836);
  static const Color colorVerdeClaro = Color(0xFFE8F5EE);
  static const Color colorAzulPolitecnico = Color(0xFF2C4A6F);
  static const Color colorFondoClaro = Color(0xFFF7F9FA);
  static const Color colorSuperficie = Color(0xFFFFFFFF);
  static const Color colorBorde = Color(0xFFD0D7DE);
  static const Color colorTextoPrincipal = Color(0xFF1F2937);
  static const Color colorTextoSecundario = Color(0xFF4B5563);
  static const Color colorAcento = Color(0xFFD97724);

  // Paleta calida del diseno oficial Figma (Bloque 1: Bienvenida y Autenticacion)
  static const Color colorCremaFondo = Color(0xFFFFFDF7);
  static const Color colorCremaCampo = Color(0xFFFAF8F3);
  static const Color colorBordeCampo = Color(0xFFDED8CE);
  static const Color colorMarronOscuro = Color(0xFF5A240E);
  static const Color colorMarronMedio = Color(0xFF7A411E);
  static const Color colorNaranjaPrimario = Color(0xFFF37021);
  static const Color colorNaranjaOscuro = Color(0xFFE05A0B);
  static const Color colorDuraznoClaro = Color(0xFFFDE6C4);
  static const Color colorVerdeSalviaClaro = Color(0xFFD4E4CF);
  static const Color colorVerdeEsmeralda = Color(0xFF1B6F50);
  static const Color colorGrisCampo = Color(0xFF767980);
  static const Color colorSombraCalida = Color(0x185A240E);

  /// Construye y retorna la configuracion del tema claro de la aplicacion.
  static ThemeData obtenerTemaClaro() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colorVerdePrimario,
        primary: colorVerdePrimario,
        onPrimary: Colors.white,
        secondary: colorAzulPolitecnico,
        onSecondary: Colors.white,
        tertiary: colorNaranjaPrimario,
        surface: colorSuperficie,
        surfaceTint: Colors.transparent,
      ),
      scaffoldBackgroundColor: colorFondoClaro,
      appBarTheme: const AppBarTheme(
        backgroundColor: colorSuperficie,
        foregroundColor: colorTextoPrincipal,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorTextoPrincipal,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorSuperficie,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: colorBorde, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorSuperficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorBorde, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorBorde, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorVerdePrimario, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        labelStyle: const TextStyle(color: colorTextoSecundario, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorVerdePrimario,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorVerdePrimario,
          side: const BorderSide(color: colorVerdePrimario, width: 1.2),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorAzulPolitecnico,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
