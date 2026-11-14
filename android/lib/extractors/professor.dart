import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../data/professor.dart';
import 'portal.dart' show nomeApresentavel;

// Extratores do Portal do Professor. Cada um devolve null quando a página não tem
// o formato esperado, para o app nunca mostrar dado errado.

String _limpo(String? texto) => (texto ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

const _dias = {
  'segunda': 1,
  'terça': 2,
  'terca': 2,
  'quarta': 3,
  'quinta': 4,
  'sexta': 5,
  'sábado': 6,
  'sabado': 6,
  'domingo': 7,
};

int? diaDaSemana(String texto) => _dias[_limpo(texto).toLowerCase().split(RegExp(r'[-,\s]')).first];

/// "08:00" vira 480.
int? minutos(String texto) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(texto);
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

DateTime? _data(String texto) {
  final m = RegExp(r'(\d{2})/(\d{2})/(\d{4})').firstMatch(texto);
  return m == null ? null : DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
}

int? _inteiro(String texto) => int.tryParse(RegExp(r'\d+').firstMatch(texto)?[0] ?? '');

/// O nome no botão do topo, presente em todas as páginas do portal.
String? lerNomeProfessor(String pagina) {
  final nome = _limpo(html.parse(pagina).querySelector('.menu-botao button, #menu button')?.text);
  return nome.isEmpty ? null : nomeApresentavel(nome);
}

/// "Minhas turmas" (de Frequência ou de Notas). A coluna Situação muda de sentido conforme a página.
List<TurmaProfessor>? lerTurmasProfessor(String pagina) {
  final tabela = html.parse(pagina).querySelector('table#turmasLiberadas');
  if (tabela == null) return null;
  final cabecalho = tabela.querySelectorAll('thead th').map((th) => _limpo(th.text)).toList();
  final col = {for (var i = 0; i < cabecalho.length; i++) cabecalho[i]: i};
  final iDisciplina = col['Disciplina'], iSituacao = col['Situação'], iPeriodo = col['Período'];
  if (iDisciplina == null || iSituacao == null) return null;
  final turmas = <TurmaProfessor>[];
  for (final tr in tabela.querySelectorAll('tbody tr')) {
    final tds = tr.querySelectorAll('td');
    if (tds.length <= iSituacao || tds.length <= iDisciplina) continue;
    final link = tr.querySelectorAll('a[href]').where((a) => a.attributes['href']!.contains('turma.action')).firstOrNull;
    final id = RegExp(r'turma=(\d+)').firstMatch(link?.attributes['href'] ?? '')?[1];
    if (link == null || id == null) continue;
    final celula = tds[iDisciplina];
    final bruto = _limpo(celula.querySelector('strong')?.text ?? celula.text);
    final m = RegExp(r'^(.*?)\s*\(\s*([^)]+?)\s*\)\s*$').firstMatch(bruto);
    turmas.add(TurmaProfessor(
      id: id,
      disciplina: m?[1] ?? bruto,
      codigo: m?[2],
      nome: _limpo(link.text),
      curso: _limpo(celula.querySelector('.curso')?.text).ifEmptyNull,
      periodo: iPeriodo == null ? null : _limpo(tds[iPeriodo].text).ifEmptyNull,
      situacaoFrequencia: _limpo(tds[iSituacao].text).ifEmptyNull,
    ));
  }
  return turmas;
}

/// "Detalhes da Turma": dados gerais, totais, docentes, horários e modelo de notas.
DetalheTurma? lerDetalheTurma(String pagina) {
  final doc = html.parse(pagina);
  final campos = <String, String>{};
  for (final rotulo in doc.querySelectorAll('span.label')) {
    final chave = _limpo(rotulo.text).replaceAll(':', '');
    final td = rotulo.parent;
    if (td == null) continue;
    var valor = _limpo(td.text.replaceFirst(rotulo.text, ''));
    if (valor.isEmpty) {
      final proximo = td.nextElementSibling;
      if (proximo != null) valor = _limpo(proximo.text);
    }
    if (valor.isNotEmpty) campos.putIfAbsent(chave, () => valor);
  }

  Element? tabelaCom(String th) => doc
      .querySelectorAll('table')
      .where((t) => t.querySelectorAll('th').any((e) => _limpo(e.text) == th))
      .firstOrNull;

  final horarios = <HorarioTurma>[];
  for (final tr in tabelaCom('Hora Início')?.querySelectorAll('tbody tr') ?? const <Element>[]) {
    final tds = tr.querySelectorAll('td').map((e) => _limpo(e.text)).toList();
    if (tds.length < 3) continue;
    final dia = diaDaSemana(tds[0]), ini = minutos(tds[1]), fim = minutos(tds[2]);
    if (dia == null || ini == null || fim == null) continue;
    horarios.add(HorarioTurma(
      diaSemana: dia,
      inicioMin: ini,
      fimMin: fim,
      tipo: tds.length > 3 ? tds[3].ifEmptyNull : null,
      valeDe: tds.length > 4 ? _data(tds[4]) : null,
      valeAte: tds.length > 5 ? _data(tds[5]) : null,
    ));
  }

  final docentes = <(String, String)>[];
  for (final tr in tabelaCom('Nome do Docente')?.querySelectorAll('tbody tr') ?? const <Element>[]) {
    final tds = tr.querySelectorAll('td').map((e) => _limpo(e.text)).toList();
    if (tds.length >= 2 && tds[0].isNotEmpty) docentes.add((nomeApresentavel(tds[0]), tds[1]));
  }

  final grupos = <GrupoNotas>[];
  for (final link in doc.querySelectorAll('table.tableNotas a.linkNota')) {
    final celula = link.parent!;
    final peso = RegExp(r'\(([\d.,]+%)\)').firstMatch(celula.text)?[1] ?? '';
    final linha = celula.parent!;
    final conteudo = linha.nextElementSibling;
    final avaliacoes = <AvaliacaoModelo>[];
    for (final tr in conteudo?.querySelectorAll('table.tableavaliacao tr') ?? const <Element>[]) {
      final tds = tr.querySelectorAll('td').map((e) => _limpo(e.text)).toList();
      if (tds.length >= 3) avaliacoes.add(AvaliacaoModelo(tds[0], tds[1], tds[2]));
    }
    grupos.add(GrupoNotas(_limpo(link.text), peso, avaliacoes));
  }

  if (campos['Disciplina'] == null && horarios.isEmpty) return null;
  return DetalheTurma(
    curso: campos['Curso'],
    disciplina: campos['Disciplina'],
    tipo: campos['Tipo de Turma'],
    periodo: campos['Período'],
    cargaHorariaRealizada: _inteiro(campos['Carga Horária Realizada'] ?? ''),
    vagas: _inteiro(campos['Vagas Totais'] ?? ''),
    matriculas: _inteiro(campos['Total de Matrículas'] ?? ''),
    docentes: docentes,
    horarios: horarios,
    modeloNotas: grupos,
  );
}

/// Os meses da Agenda da Turma, com o índice que o portal usa para carregar cada um.
List<MesAgenda> lerMesesAgenda(String pagina) => [
      for (final a in html.parse(pagina).querySelectorAll('a.mesesAccordion'))
        if (int.tryParse(a.attributes['index'] ?? '') case final indice?)
          if (int.tryParse(a.attributes['ano'] ?? '') case final ano?)
            if (int.tryParse(a.attributes['mes'] ?? '') case final mes?)
              MesAgenda(indice: indice, ano: ano, mes: mes, anoMes: a.attributes['anomes'] ?? ''),
    ];

/// As aulas de um mês (resposta em trecho de HTML). Null se não for a tabela esperada.
List<AulaAgenda>? lerAulasDoMes(String pagina, {required int ano, required int mes}) {
  final doc = html.parse(pagina);
  final temCabecalho = doc.querySelectorAll('th').any((th) => _limpo(th.text) == 'Situação');
  final linhas = doc.querySelectorAll('tr.row');
  if (!temCabecalho && linhas.isEmpty) return null;
  final aulas = <AulaAgenda>[];
  for (final tr in linhas) {
    final tds = tr.querySelectorAll('td');
    if (tds.length < 4) continue;
    final dia = _inteiro(RegExp(r'dia\s+(\d+)').firstMatch(tds[0].text)?[1] ?? '');
    final horas = RegExp(r'(\d{1,2}:\d{2})\D+(\d{1,2}:\d{2})').firstMatch(tds[2].text);
    final situacao = _limpo(tds[3].text).toLowerCase();
    if (dia == null || horas == null || !situacao.contains('lançada')) continue;
    final conteudo = _limpo(tr.querySelector('a.add-cont-min')?.text);
    final chamada = tr.querySelectorAll('a[href]').where((a) => a.attributes['href']!.contains('horaaula.action')).firstOrNull;
    aulas.add(AulaAgenda(
      data: DateTime(ano, mes, dia),
      inicioMin: minutos(horas[1]!)!,
      fimMin: minutos(horas[2]!)!,
      chamadaLancada: !situacao.contains('não lançada'),
      periodos: tds.length > 4 ? _inteiro(tds[4].text) : null,
      conteudo: conteudo.isEmpty || conteudo.toLowerCase() == 'sem conteúdo' ? null : conteudo,
      idAgenda: RegExp(r'agenda=(\d+)').firstMatch(chamada?.attributes['href'] ?? '')?[1],
    ));
  }
  return aulas;
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
