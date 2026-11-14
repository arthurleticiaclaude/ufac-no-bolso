import 'package:html/parser.dart' as html;

import '../config.dart';

Refeicao? _refeicaoDoTitulo(String titulo) {
  final t = titulo.toLowerCase();
  if (t.contains('café') || t.contains('cafe')) return Refeicao.cafe;
  if (t.contains('almoço') || t.contains('almoco')) return Refeicao.almoco;
  if (t.contains('jant')) return Refeicao.jantar;
  return null;
}

/// Lê a página logada `/eticket/menu/`. A ordem das refeições muda, então o nome é o que vale.
/// Devolve null se a página não tiver o formato esperado.
Map<Refeicao, String>? lerEticketCardapio(String pagina) {
  final textos = <Refeicao, String>{};
  for (final titulo in html.parse(pagina).querySelectorAll('.meal-title')) {
    final refeicao = _refeicaoDoTitulo(titulo.text);
    var irmao = titulo.nextElementSibling;
    while (irmao != null && !irmao.classes.contains('meal-title')) {
      if (irmao.classes.contains('cardapio')) {
        if (refeicao != null) textos[refeicao] = irmao.text.trim();
        break;
      }
      irmao = irmao.nextElementSibling;
    }
  }
  return textos.isEmpty ? null : textos;
}
