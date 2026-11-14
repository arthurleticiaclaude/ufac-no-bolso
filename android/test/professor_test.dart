import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/data/professor.dart';
import 'package:ufac_no_bolso/extractors/professor.dart';
import 'package:ufac_no_bolso/session/regras_sessao.dart';

String fixture(String nome) => File('fixtures/$nome').readAsStringSync();

void main() {
  test('nome do professor no topo', () {
    expect(lerNomeProfessor(fixture('professor_turmas_frequencia.html')), 'Maria de Teste Souza');
    expect(lerNomeProfessor('<html></html>'), isNull);
  });

  test('minhas turmas (frequência)', () {
    final t = lerTurmasProfessor(fixture('professor_turmas_frequencia.html'))!;
    expect(t, hasLength(2));
    expect(t[0].id, '1001');
    expect(t[0].disciplina, 'Direito Civil II');
    expect(t[0].codigo, 'CCJ123');
    expect(t[0].nome, 'T. DIR01 - 1A');
    expect(t[0].curso, 'Bacharelado em Direito');
    expect(t[0].periodo, '2° Semestre / 2026');
    expect(t[0].situacaoFrequencia, 'Frequência Parcialmente Lançada');
    expect(t[1].situacaoFrequencia, 'Frequência Não Lançada');
  });

  test('minhas turmas (notas): situação do lançamento', () {
    final t = lerTurmasProfessor(fixture('professor_turmas_notas.html'))!;
    expect(t.map((x) => x.id), ['1001', '1002']);
    expect(t[0].situacaoFrequencia, 'Lançamento Aberto');
    expect(t[0].comNotas(t[0].situacaoFrequencia).lancamentoNotasAberto, isTrue);
    expect(t[1].comNotas(t[1].situacaoFrequencia).lancamentoNotasAberto, isFalse);
  });

  test('página sem a tabela não vira lista vazia', () {
    expect(lerTurmasProfessor('<html><body>Sessão expirada</body></html>'), isNull);
  });

  test('detalhes da turma', () {
    final d = lerDetalheTurma(fixture('professor_turma.html'))!;
    expect(d.curso, 'Bacharelado em Direito');
    expect(d.disciplina, 'Direito Civil II');
    expect(d.tipo, 'Turma Regular');
    expect(d.periodo, '2° Semestre');
    expect(d.cargaHorariaRealizada, 28);
    expect(d.vagas, 40);
    expect(d.matriculas, 35);
    expect(d.docentes, [('Maria de Teste Souza', 'Responsável'), ('João Exemplo Lima', 'Colaborador')]);
    expect(d.horarios, hasLength(2));
    expect(d.horarios[0].diaSemana, 1);
    expect(d.horarios[0].inicioMin, 8 * 60);
    expect(d.horarios[0].fimMin, 10 * 60);
    expect(d.horarios[0].tipo, 'Teórica');
    expect(d.horarios[0].valeDe, DateTime(2026, 8, 3));
    expect(d.horarios[1].diaSemana, 3);
    expect(d.modeloNotas.map((g) => '${g.rotulo} ${g.peso}'), ['Nota 1 50.00%', 'Nota 2 50.00%']);
    expect(d.modeloNotas[1].avaliacoes.map((a) => '${a.codigo}|${a.peso}|${a.nome}'),
        ['Aval. 1|60.00%|Prova', 'Aval. 2|40.00%|Seminário']);
    expect(lerDetalheTurma('<html></html>'), isNull);
  });

  test('meses da agenda', () {
    final m = lerMesesAgenda(fixture('professor_agenda.html'));
    expect(m.map((x) => '${x.indice}:${x.anoMes}'), ['0:2026_10', '1:2026_11']);
    expect(m[1].mes, 11);
  });

  test('aulas do mês e chamadas pendentes', () {
    final a = lerAulasDoMes(fixture('professor_aulas_mes_ajax.html'), ano: 2026, mes: 11)!;
    expect(a, hasLength(3));
    expect(a[0].data, DateTime(2026, 11, 2));
    expect(a[0].chamadaLancada, isTrue);
    expect(a[0].conteudo, 'Contratos: formação');
    expect(a[0].periodos, 2);
    expect(a[1].chamadaLancada, isFalse);
    expect(a[1].conteudo, isNull);
    expect(a[1].idAgenda, '5002');
    expect(a[1].inicioMin, 10 * 60);
    final turma = TurmaCompleta(
      const TurmaProfessor(id: '1', disciplina: 'X', nome: 'T'),
      aulasDoMes: a,
    );
    // Dia 11: a aula do dia 4 já passou sem chamada; a do dia 30 ainda não aconteceu.
    expect(turma.semChamada(DateTime(2026, 11, 11, 9)).map((x) => x.data.day), [4]);
    expect(lerAulasDoMes('<p>erro</p>', ano: 2026, mes: 11), isNull);
  });

  test('horários de todas as turmas viram aulas', () {
    final d = lerDetalheTurma(fixture('professor_turma.html'))!;
    final aulas = aulasDoProfessor([
      TurmaCompleta(const TurmaProfessor(id: '1', disciplina: 'Direito Civil II', nome: 'T. DIR01 - 1A'), detalhe: d),
    ]);
    expect(aulas.map((x) => '${x.disciplina}/${x.diaSemana}'),
        ['Direito Civil II · T. DIR01 - 1A/1', 'Direito Civil II · T. DIR01 - 1A/3']);
  });

  test('cache: ida e volta', () {
    final d = lerDetalheTurma(fixture('professor_turma.html'))!;
    final a = lerAulasDoMes(fixture('professor_aulas_mes_ajax.html'), ano: 2026, mes: 11)!;
    final t = TurmaCompleta(lerTurmasProfessor(fixture('professor_turmas_frequencia.html'))!.first, detalhe: d, aulasDoMes: a);
    final volta = TurmaCompleta.deMapa(t.paraMapa());
    expect(volta.turma.disciplina, 'Direito Civil II');
    expect(volta.detalhe!.horarios.length, 2);
    expect(volta.detalhe!.docentes.first.$1, 'Maria de Teste Souza');
    expect(volta.aulasDoMes!.where((x) => !x.chamadaLancada).length, 2);
  });

  test('regras de sessão do Portal do Professor', () {
    expect(classificar(Sistema.professor, Uri.parse('https://portal.ufac.br/professor/index.action')), EstadoPagina.logado);
    expect(
      classificar(Sistema.professor,
          Uri.parse('https://portal.ufac.br/professor/ajax/professor/frequencia/agenda/agendaturma/buscarDadosAccordion.action')),
      EstadoPagina.logado,
    );
    expect(classificar(Sistema.professor, Uri.parse('https://portal.ufac.br/professor/login.action')), EstadoPagina.naLogin);
    expect(classificar(Sistema.professor, Uri.parse('https://portal.ufac.br/aluno/login.action')), EstadoPagina.naLogin);
    expect(classificar(Sistema.professor, Uri.parse('https://portal.ufac.br/aluno/index.action')), EstadoPagina.outra);
    expect(classificar(Sistema.professor, Uri.parse('https://sistemas.ufac.br/eticket/')), EstadoPagina.outra);
  });
}
