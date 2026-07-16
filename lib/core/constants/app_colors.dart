import 'package:flutter/material.dart';

/// Paleta visual extraída del logotipo de Kommerze.
class AppColors {
  AppColors._();

  // Colores de marca
  static const Color navy = Color(0xFF00143D);
  static const Color navySoft = Color(0xFF082B63);
  static const Color primaryBlue = Color(0xFF0647CF);
  static const Color brightBlue = Color(0xFF1682F3);
  static const Color primaryLight = Color(0xFFDCEBFF);
  static const Color primarySurface = Color(0xFFF3F8FF);

  // Superficies y texto
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF7FAFF);
  static const Color textDark = navy;
  static const Color textGrey = Color(0xFF52647F);
  static const Color borderGrey = Color(0xFFD7E2F0);

  // Estados
  static const Color success = Color(0xFF16835B);
  static const Color warning = Color(0xFFD18B00);
  static const Color error = Color(0xFFC62828);
  static const Color successSoft = Color(0xFFEAF7F1);
  static const Color errorSoft = Color(0xFFFFEEEE);

  // Alias usados por los componentes existentes
  static const Color primario = primaryBlue;
  static const Color primarioTransparente = Color(0x330647CF);
  static const Color blanco100 = white;
  static const Color claro1 = primarySurface;
  static const Color claro2 = borderGrey;
  static const Color fondo = lightBackground;
  static const Color negro100 = navy;
  static const Color gris1 = textGrey;
  static const Color gris2 = navySoft;
  static const Color gris3 = Color(0x3D52647F);
  static const Color estatusBien = success;
  static const Color estatusBienFondo = Color(0x3316835B);
  static const Color estatusPendiente = warning;
  static const Color estatusPendienteFondo = Color(0x33D18B00);
  static const Color estatusMal = error;
  static const Color estatusMalFondo = Color(0x33C62828);
  static const Color linkBlue = brightBlue;
  static const Color primaryColor = primaryBlue;
  static const Color colorPrimario = primaryBlue;
  static const Color bgColor = lightBackground;
  static const Color claroSecundario = borderGrey;
  static const Color gradienteInicio = white;
  static const Color gradienteFin = Color(0xFFE9F2FF);
}
