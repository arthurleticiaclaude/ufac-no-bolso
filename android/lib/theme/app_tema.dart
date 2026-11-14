import 'package:flutter/material.dart';

import 'app_cores.dart';
import 'app_medidas.dart';
import 'app_texto.dart';

class AppTema {
  static final claro = _tema(AppCores.claro, Brightness.light);
  static final escuro = _tema(AppCores.escuro, Brightness.dark);
  // No professor, o âmbar é claro demais para texto sobre o branco: os botões de texto, chaves
  // e links do Material usam o tom escuro da aba ativa, e o âmbar fica para os cartões.
  static final professorClaro = _tema(AppCores.professorClaro, Brightness.light, acao: AppCores.professorClaro.navAtivo);
  static final professorEscuro = _tema(AppCores.professorEscuro, Brightness.dark, acao: AppCores.professorEscuro.navAtivo);

  static ThemeData _tema(AppCores c, Brightness brilho, {Color? acao}) {
    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      fontFamily: AppTexto.familia,
      scaffoldBackgroundColor: c.fundo,
      extensions: [c],
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primaria,
        brightness: brilho,
        primary: acao ?? c.primaria,
        onPrimary: acao == null ? null : c.superficie,
        surface: c.superficie,
        onSurface: c.texto,
        error: c.perigo,
      ),
      textTheme: TextTheme(bodyMedium: AppTexto.corpo).apply(bodyColor: c.texto, displayColor: c.texto),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.navAtivoFundo,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => AppTexto.rotulo.copyWith(
              color: s.contains(WidgetState.selected) ? c.navAtivo : c.secundario,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? c.navAtivo : c.secundario,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppMedidas.raioBotao)),
      ),
    );
  }
}
