import 'package:flutter/painting.dart';

/// Tipografia da seção 6. A fonte é variável, então o peso vai também em fontVariations.
class AppTexto {
  static const familia = 'PlusJakartaSans';

  static TextStyle _estilo(double tamanho, int peso, {double? altura}) => TextStyle(
        fontFamily: familia,
        fontSize: tamanho,
        height: altura,
        fontWeight: FontWeight.values[(peso ~/ 100) - 1],
        fontVariations: [FontVariation('wght', peso.toDouble())],
      );

  static final saldo = _estilo(38, 800, altura: 1.1);
  static final tituloTela = _estilo(25, 800, altura: 1.2);
  static final tituloCartao = _estilo(18, 700, altura: 1.25);
  static final corpo = _estilo(15, 500, altura: 1.35);
  static final corpoForte = _estilo(15, 700, altura: 1.3);
  static final apoio = _estilo(14, 500, altura: 1.35);
  static final rotulo = _estilo(12, 600, altura: 1.25);
}
