import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../config.dart';

Refeicao? _refeicaoDoTitulo(String titulo) {
  final t = titulo.toLowerCase();
  if (t.contains('café') || t.contains('cafe')) return Refeicao.cafe;
  if (t.contains('almoço') || t.contains('almoco')) return Refeicao.almoco;
  if (t.contains('jant')) return Refeicao.jantar;
  return null;
}

/// Texto com as quebras de linha: desde 12/11/2026 o eTICKET publica um item por linha (com <br>).
String _textoComQuebras(Element el) {
  final copia = el.clone(true);
  for (final br in copia.querySelectorAll('br')) {
    br.replaceWith(Text('\n'));
  }
  return copia.text.trim();
}

/// Lê a página logada `/eticket/menu/`. A ordem das refeições muda, então o nome é o que vale.
/// Percorre a página em ordem, então aceita o cardápio aninhado em outros blocos.
/// Devolve null se a página não tiver o formato esperado.
Map<Refeicao, String>? lerEticketCardapio(String pagina) {
  final textos = <Refeicao, String>{};
  Refeicao? atual;
  for (final el in html.parse(pagina).querySelectorAll('.meal-title, .cardapio')) {
    if (el.classes.contains('meal-title')) {
      atual = _refeicaoDoTitulo(el.text);
    } else if (atual != null && !textos.containsKey(atual)) {
      textos[atual] = _textoComQuebras(el);
    }
  }
  return textos.isEmpty ? null : textos;
}
