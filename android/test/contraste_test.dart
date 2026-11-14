import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/theme/app_cores.dart';

/// Razão de contraste da WCAG entre duas cores (1 a 21).
double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  final paletas = {
    'aluno claro': AppCores.claro,
    'aluno escuro': AppCores.escuro,
    'professor claro': AppCores.professorClaro,
    'professor escuro': AppCores.professorEscuro,
  };
  for (final p in paletas.entries) {
    test('contraste AA: ${p.key}', () {
      final c = p.value;
      final pares = {
        'texto do cartão principal': (c.sobrePrimaria, c.primaria, 4.5),
        'texto suave do cartão principal': (c.sobrePrimariaSuave, c.primaria, 4.5),
        'botão de destaque': (c.sobreDestaque, c.destaque, 4.5),
        'aba ativa': (c.navAtivo, c.navAtivoFundo, 4.5),
        'aba ativa sobre a barra': (c.navAtivo, c.superficie, 4.5),
        'etiqueta': (c.chipTexto, c.chipFundo, 4.5),
        'perigo': (c.perigo, c.perigoFundo, 4.5),
      };
      for (final e in pares.entries) {
        final (frente, fundo, minimo) = e.value;
        expect(contraste(frente, fundo), greaterThanOrEqualTo(minimo), reason: '${p.key}: ${e.key}');
      }
    });
  }

  test('no professor, o botão de destaque aparece sobre o cartão âmbar', () {
    for (final c in [AppCores.professorClaro, AppCores.professorEscuro]) {
      expect(contraste(c.destaque, c.primaria), greaterThanOrEqualTo(3));
    }
  });
}
