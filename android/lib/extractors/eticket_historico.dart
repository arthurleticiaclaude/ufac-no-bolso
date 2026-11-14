import 'package:html/parser.dart' as html;

import '../data/historico.dart';

String _limpo(String texto) => texto.replaceAll(RegExp(r'\s+'), ' ').trim();

/// O histórico escreve "R$ 5.00" e o saldo "R$ 12,50": aceita os dois.
double? _valor(String texto) {
  final m = RegExp(r'R\$\s*([\d.,]+)').firstMatch(texto);
  if (m == null) return null;
  final bruto = m[1]!;
  final normal = bruto.contains(',') ? bruto.replaceAll('.', '').replaceAll(',', '.') : bruto;
  return double.tryParse(normal);
}

/// Null se a página não for o histórico. Lista vazia é quem nunca usou o RU.
List<RegistroRefeicao>? lerHistoricoRefeicoes(String pagina) {
  final doc = html.parse(pagina);
  final tabela = doc.querySelector('#historico-table');
  if (tabela == null) return doc.querySelector('h1')?.text.contains('Refeições') == true ? const [] : null;
  return [
    for (final linha in tabela.querySelectorAll('tbody tr'))
      if (linha.children.length >= 6)
        RegistroRefeicao(
          data: _limpo(linha.children[0].text),
          hora: _limpo(linha.children[1].text),
          refeicao: _limpo(linha.children[2].text),
          prato: _limpo(linha.children[3].text),
          valor: _valor(linha.children[4].text),
          status: _limpo(linha.children[5].text),
        ),
  ];
}

/// Null se a página não for o histórico de crédito.
List<RegistroRecarga>? lerHistoricoRecargas(String pagina) {
  final doc = html.parse(pagina);
  final ehHistorico = doc.querySelectorAll('h1').any((h) => h.text.contains('Crédito'));
  if (!ehHistorico) return null;
  final registros = <RegistroRecarga>[];
  for (final linha in doc.querySelectorAll('table tr')) {
    final textos = linha.querySelectorAll('h6').map((h) => _limpo(h.text)).toList();
    String depoisDe(String rotulo) {
      final achado = textos.where((t) => t.contains(rotulo)).firstOrNull;
      return achado == null ? '' : achado.substring(achado.indexOf(rotulo) + rotulo.length).trim();
    }

    if (textos.isEmpty) continue;
    registros.add(
      RegistroRecarga(
        valor: _valor(textos.first),
        forma: depoisDe('Pagamento:'),
        data: depoisDe('Data:'),
        hora: depoisDe('Hora:'),
        situacao: depoisDe('Situação:'),
      ),
    );
  }
  return registros;
}
