import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../data/academico.dart';

class DadosIdentificacao {
  const DadosIdentificacao(this.identificacao, this.matricula);
  final Identificacao identificacao;
  final String matricula;
}

/// O número interno que o portal usa nos endereços (não é a matrícula de 11 dígitos).
String? lerIdInterno(String pagina) {
  final valor = html.parse(pagina).querySelector('input#matricula')?.attributes['value']?.trim();
  return valor != null && RegExp(r'^\d+$').hasMatch(valor) ? valor : null;
}

/// O link "Mais Relatórios" da página de Relatórios, como endereço completo.
String? lerEnderecoMaisRelatoriosDe(String pagina) {
  final doc = html.parse(pagina);
  final link = doc.querySelectorAll('a').where((a) => a.querySelector('.linkmaisrelatorios') != null).firstOrNull;
  final destino = link?.attributes['href'];
  return destino == null ? null : Uri.parse('https://portal.ufac.br').resolve(destino).toString();
}

/// O endereço de Comunicações muda por sistema, então vem do botão da página inicial.
String? lerEnderecoComunicacoes(String pagina) {
  final m = RegExp(r'''/comunicacoes/noticia/list\.action[^'"]*''').firstMatch(pagina);
  if (m == null) return null;
  return 'https://portal.ufac.br${m[0]!.replaceAll('&amp;', '&')}';
}

String _limpo(String texto) => texto.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Portal às vezes escreve tudo em maiúsculas: "MARIA DE SOUZA" vira "Maria de Souza".
String nomeApresentavel(String nome) {
  if (nome != nome.toUpperCase()) return nome;
  const minusculas = {'de', 'da', 'do', 'das', 'dos', 'e'};
  return nome.split(' ').map((p) {
    final m = p.toLowerCase();
    return minusculas.contains(m) || m.isEmpty ? m : '${m[0].toUpperCase()}${m.substring(1)}';
  }).join(' ');
}

/// Lê a página de Relatórios, que traz o quadro com matrícula, curso e período.
DadosIdentificacao? lerIdentificacao(String pagina) {
  final doc = html.parse(pagina);
  final nome = _limpo(doc.querySelector('#menu .ui-button-text, #menu button')?.text ?? '');
  final campos = <String, String>{};
  for (final td in doc.querySelectorAll('table.table-topo td')) {
    final rotulo = td.querySelector('span.label')?.text ?? '';
    campos[_limpo(rotulo)] = _limpo(td.text.replaceFirst(rotulo, ''));
  }
  final matricula = campos['Matrícula:'];
  final curso = campos['Curso:'];
  final periodo = campos['Período Atual:'];
  final semestre = campos['Período de Matrícula:'];
  if (nome.isEmpty || matricula == null || curso == null || periodo == null || semestre == null) return null;
  if (!RegExp(r'^\d{6,}$').hasMatch(matricula)) return null;
  return DadosIdentificacao(
    Identificacao(nome: nomeApresentavel(nome), curso: curso, periodo: periodo, semestre: semestre),
    matricula,
  );
}

class DisciplinaDoSemestre {
  const DisciplinaDoSemestre(this.disciplina, this.situacao, this.urlNotas, {this.urlTurma});
  final String disciplina, situacao;
  final String? urlNotas, urlTurma;
}

/// A carga horária fica na página da turma ("Carga Horária ...: 60").
int? lerCargaHoraria(String pagina) {
  for (final rotulo in html.parse(pagina).querySelectorAll('span.label')) {
    if (!_limpo(rotulo.text).startsWith('Carga Horária')) continue;
    final valor = rotulo.parent?.text.replaceFirst(rotulo.text, '') ?? '';
    final n = int.tryParse(RegExp(r'\d+').firstMatch(valor)?[0] ?? '');
    if (n != null && n > 0) return n;
  }
  return null;
}

class ListaDeNotas {
  const ListaDeNotas(this.semestre, this.disciplinas);
  final String semestre;
  final List<DisciplinaDoSemestre> disciplinas;
}

/// Lê a página de Notas. O semestre mais recente vem primeiro; os antigos ficam de fora
/// para não fazer dezenas de pedidos à Ufac.
ListaDeNotas? lerListaDeNotas(String pagina) {
  final titulo = html.parse(pagina).querySelector('a.accordionTurma');
  final tabela = titulo?.parent?.nextElementSibling?.querySelector('table.table-turmas');
  if (titulo == null || tabela == null) return null;
  final disciplinas = <DisciplinaDoSemestre>[];
  for (final linha in tabela.querySelectorAll('tbody tr')) {
    final celulas = linha.children;
    if (celulas.length < 2) continue;
    final link = linha
        .querySelectorAll('a')
        .map((a) => RegExp(r"/aluno/ajax/aluno/nota/notaturma\.action\?[^']+").firstMatch(a.attributes['href'] ?? ''))
        .where((m) => m != null)
        .firstOrNull;
    disciplinas.add(
      DisciplinaDoSemestre(
        _limpo(celulas[0].text).replaceFirst(RegExp(r'\s*\([^()]*\)$'), ''),
        _limpo(celulas[1].text),
        link == null ? null : 'https://portal.ufac.br${link[0]}',
        urlTurma: switch (linha.querySelector('a[href*="turma.action?turma="]')?.attributes['href']) {
          final destino? => Uri.parse('https://portal.ufac.br').resolve(destino).toString(),
          null => null,
        },
      ),
    );
  }
  return ListaDeNotas(_limpo(titulo.text), disciplinas);
}

/// Lê o quadro de notas de uma disciplina. Se ainda não houver quadro, volta sem notas,
/// só com o que já veio da lista.
NotasDisciplina lerNotasDaDisciplina(String pagina, DisciplinaDoSemestre d) {
  final doc = html.parse(pagina);
  final notas = <NotaAvaliacao>[];
  final resumo = <ItemNota>[];
  final quadro = doc.querySelector('table.nota');
  // O quadro tem tabelas dentro de tabelas: só vale a linha direta de cada parte.
  List<Element> colunasDe(String parte) {
    final secao = quadro?.children.where((e) => e.localName == parte).firstOrNull;
    return secao == null || secao.children.isEmpty ? const [] : secao.children.first.children;
  }

  final titulos = colunasDe('thead');
  final valores = colunasDe('tbody');
  for (var i = 0; i < titulos.length && i < valores.length; i++) {
    // Cada coluna tem uma tabela interna: um cabeçalho por célula e o valor na mesma posição.
    final cabecalhos = titulos[i].querySelectorAll('td');
    final dados = valores[i].querySelectorAll('td');
    final itens = <ItemNota>[
      for (var j = 0; j < cabecalhos.length; j++)
        ItemNota(
          _limpo(cabecalhos[j].querySelector('.labelAvaliacao')?.text ?? cabecalhos[j].text),
          _limpo(cabecalhos[j].querySelector('.labelPercentagem')?.text ?? ''),
          j < dados.length ? _limpo(dados[j].text) : '',
        ),
    ];
    final titulo = _limpo(titulos[i].querySelector('.labelNota')?.text ?? '');
    if (titulo.isEmpty) {
      resumo.addAll(itens);
      continue;
    }
    final m = RegExp(r'^(.*?)\s*\(([^)]*)\)$').firstMatch(titulo);
    notas.add(NotaAvaliacao(m?[1] ?? titulo, m?[2] ?? '', itens));
  }
  final info = <String, String>{};
  final colunas = doc.querySelector('.divInfo')?.children ?? const <Element>[];
  if (colunas.length >= 2) {
    final rotulos = colunas[0].children;
    final dados = colunas[1].children;
    for (var i = 0; i < rotulos.length && i < dados.length; i++) {
      info[_limpo(rotulos[i].text)] = _limpo(dados[i].text);
    }
  }
  String campo(String inicio) =>
      info.entries.where((e) => e.key.startsWith(inicio)).map((e) => e.value).firstOrNull ?? '';
  final situacao = campo('Situação');
  return NotasDisciplina(
    disciplina: d.disciplina,
    situacao: situacao.isEmpty ? d.situacao : situacao,
    notas: notas,
    resumo: resumo,
    media: campo('Média'),
    faltas: campo('Total de Faltas'),
  );
}

DateTime? _dataCurta(String? d, String? m, String? a) {
  if (d == null || m == null || a == null) return null;
  return DateTime(2000 + int.parse(a), int.parse(m), int.parse(d));
}

String _nomeDaAula(Element link) {
  final primeiro = link.nodes.whereType<Text>().map((t) => _limpo(t.text)).where((t) => t.isNotEmpty);
  return primeiro.isEmpty ? '' : primeiro.first;
}

/// Lê o quadro de horários. As colunas vão de domingo a sábado. Null se o quadro não existir.
List<Aula>? lerHorarios(String pagina) {
  final quadro = html.parse(pagina).querySelector('#quadrohorario');
  if (quadro == null) return null;
  final vistas = <String>{};
  final aulas = <Aula>[];
  final padrao = RegExp(r'(\d{2})/(\d{2})/(\d{2})\s*-\s*(\d{2})/(\d{2})/(\d{2}).*?(\d{2}):(\d{2})\s*às\s*(\d{2}):(\d{2})');
  for (final linha in quadro.querySelectorAll('tbody tr')) {
    final celulas = linha.children;
    for (var coluna = 1; coluna < celulas.length && coluna <= 7; coluna++) {
      for (final link in celulas[coluna].querySelectorAll('.turmaqh a')) {
        final m = padrao.firstMatch(link.attributes['title'] ?? '');
        final nome = _nomeDaAula(link);
        if (m == null || nome.isEmpty) return null;
        final aula = Aula(
          disciplina: nome,
          diaSemana: coluna == 1 ? DateTime.sunday : coluna - 1,
          inicioMin: int.parse(m[7]!) * 60 + int.parse(m[8]!),
          fimMin: int.parse(m[9]!) * 60 + int.parse(m[10]!),
          valeDe: _dataCurta(m[1], m[2], m[3]),
          valeAte: _dataCurta(m[4], m[5], m[6]),
        );
        // A mesma aula pode aparecer em mais de uma faixa do quadro.
        if (vistas.add('${aula.disciplina}|${aula.diaSemana}|${aula.inicioMin}')) aulas.add(aula);
      }
    }
  }
  return aulas;
}
