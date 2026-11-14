import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../data/biblioteca.dart';

String _limpo(String texto) => texto.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String? _ouNulo(String? texto) {
  final t = _limpo(texto ?? '');
  return t.isEmpty ? null : t;
}

String _semPontoFinal(String t) => t.replaceAll(RegExp(r'\.$'), '');

/// Resultado de "Pesquisar Acervo". Null se a página não for o resultado; lista vazia se nada foi achado.
List<TituloAcervo>? lerResultadoAcervo(String pagina) {
  final doc = html.parse(pagina);
  final tabela = doc.querySelector('table.resultado-pesquisa-geral');
  if (tabela == null) return null;
  final lista = <TituloAcervo>[];
  for (final tr in tabela.querySelectorAll('tbody tr')) {
    final id = tr.attributes['idregistro'];
    final titulo = _ouNulo(tr.querySelector('[idd="titulo"]')?.text);
    if (id == null || titulo == null || tr.children.length < 5) continue;
    final ano = _ouNulo(tr.children[3].text);
    lista.add(
      TituloAcervo(
        idRegistro: id,
        titulo: _semPontoFinal(titulo),
        subtitulo: _ouNulo(tr.querySelector('[idd="subtitulo"]')?.text),
        autor: _ouNulo(tr.querySelector('[idd="autor"]')?.text),
        // "2019." vira "2019".
        ano: ano == null ? null : _semPontoFinal(ano),
        biblioteca: _ouNulo(tr.children[4].text),
      ),
    );
  }
  return lista;
}

/// Exemplares de um título. Null se a resposta não for a tabela de exemplares.
List<Exemplar>? lerExemplares(String pagina) {
  final doc = html.parse(pagina);
  final tabela = doc.querySelector('table.itens');
  if (tabela == null) return null;
  final titulos = [for (final th in tabela.querySelectorAll('thead th')) _limpo(th.text).toLowerCase()];
  int coluna(String inicio) => titulos.indexWhere((t) => t.startsWith(inicio));
  final iLocal = coluna('locali'), iBib = coluna('biblio'), iCol = coluna('cole'), iTipo = coluna('tipo');
  final iReg = coluna('regul'), iSit = coluna('situa');
  if (iLocal < 0 || iSit < 0) return null;
  String? celula(List<Element> cels, int i) => i < 0 || i >= cels.length ? null : _ouNulo(cels[i].text);
  final lista = <Exemplar>[];
  for (final tr in tabela.querySelectorAll('tbody tr')) {
    final local = celula(tr.children, iLocal), situacao = celula(tr.children, iSit);
    if (local == null || situacao == null) continue;
    lista.add(
      Exemplar(
        localizacao: local,
        biblioteca: celula(tr.children, iBib) ?? '',
        situacao: situacao,
        colecao: celula(tr.children, iCol),
        tipo: celula(tr.children, iTipo),
        regulamento: celula(tr.children, iReg),
      ),
    );
  }
  return lista;
}

/// "03/10/2026 14:05:11" vira DateTime. Null se vier vazio ou em outro formato.
DateTime? _dataHora(Object? texto) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{2}):(\d{2}))?').firstMatch('${texto ?? ''}'.trim());
  if (m == null) return null;
  return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!), int.parse(m[4] ?? '0'), int.parse(m[5] ?? '0'));
}

/// Histórico de empréstimos. O site responde JSON; pela WebView ele chega dentro de um <pre>.
/// Null se não der para ler.
List<EmprestimoHistorico>? lerHistoricoBiblioteca(String resposta) {
  var texto = resposta.trim();
  if (!texto.startsWith('{')) texto = html.parse(resposta).body?.text.trim() ?? '';
  try {
    final j = jsonDecode(texto);
    if (j is! Map || j['rows'] is! List) return null;
    final lista = <EmprestimoHistorico>[];
    for (final r in j['rows'] as List) {
      if (r is! Map) continue;
      final nome = _ouNulo('${r['nome'] ?? ''}');
      final retirada = _dataHora(r['dataRetirada']);
      if (nome == null || retirada == null) continue;
      lista.add(
        EmprestimoHistorico(
          // "Título /" fica sem a barra solta do fim.
          titulo: nome.replaceAll(RegExp(r'\s*/\s*$'), ''),
          retirada: retirada,
          devolucao: _dataHora(r['dataEntrega']),
        ),
      );
    }
    return lista;
  } on FormatException {
    return null;
  }
}
