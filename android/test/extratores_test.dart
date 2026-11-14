import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/config.dart';
import 'package:ufac_no_bolso/data/academico.dart';
import 'package:ufac_no_bolso/data/cardapio.dart';
import 'package:ufac_no_bolso/data/historico.dart';
import 'package:ufac_no_bolso/extractors/eticket_cardapio.dart';
import 'package:ufac_no_bolso/extractors/eticket_historico.dart';
import 'package:ufac_no_bolso/extractors/eticket_inicio.dart';
import 'package:ufac_no_bolso/extractors/portal.dart';
import 'package:ufac_no_bolso/ui/formatos.dart';

void main() {
  _cardapio();
  _portal();
  _notas();
  _historico();
  _faltas();
  _cargaHoraria();
  _limiteDoApp();
  group('lerEticketInicio', () {
    test('le saldo e numero da fixture', () {
      final d = lerEticketInicio(File('fixtures/eticket_home.html').readAsStringSync());
      expect(d?.saldo, 12.5);
      expect(d?.numeroQr, '12345678901');
    });
    test('saldo com milhar', () {
      final html = File('fixtures/eticket_home.html').readAsStringSync().replaceFirst('R\$ 12,50', 'R\$ 1.234,50');
      expect(lerEticketInicio(html)?.saldo, 1234.5);
    });
    test('pagina de login nao vira dado', () {
      expect(lerEticketInicio(File('fixtures/public/eticket_login.html').readAsStringSync()), isNull);
    });
    test('numero com letra nao vira dado', () {
      final html = File('fixtures/eticket_home.html').readAsStringSync().replaceFirst('12345678901', 'abc');
      expect(lerEticketInicio(html), isNull);
    });
  });

  test('mascararNumero mostra so o final', () {
    expect(mascararNumero('12345678901'), '•••••••8901');
    expect(mascararNumero('123'), '123');
  });
}

void _cardapio() {
  group('lerEticketCardapio', () {
    test('le pelo nome, nao pela posicao', () {
      final t = lerEticketCardapio(File('fixtures/eticket_menu.html').readAsStringSync())!;
      expect(t[Refeicao.cafe], startsWith('Café preto'));
      expect(t[Refeicao.almoco], 'Não informado');
      expect(t[Refeicao.jantar], 'Não informado');
    });
    test('pagina publica nao vira cardapio', () {
      expect(lerEticketCardapio(File('fixtures/public/eticket_cardapio_indisponivel.html').readAsStringSync()), isNull);
    });
  });

  group('cardapio do dia', () {
    final hoje = DateTime(2026, 11, 4, 12);
    final completo = {for (final r in Refeicao.values) r: 'Arroz, Feijão.'};
    test('cardapio de ontem nao vale hoje', () {
      final c = CardapioDoDia(DateTime(2026, 11, 3, 18), completo);
      expect(c.valeEm(hoje), isFalse);
      expect(cardapioPendente(c, hoje), isTrue);
    });
    test('refeicao sem cardapio continua pendente', () {
      final c = CardapioDoDia(hoje, {...completo, Refeicao.jantar: 'Não informado'});
      expect(cardapioPendente(c, hoje), isTrue);
    });
    test('completo de hoje nao pede nova leitura', () {
      expect(cardapioPendente(CardapioDoDia(hoje, completo), hoje), isFalse);
    });
    test('sobrevive a gravar e ler', () {
      final c = CardapioDoDia.deMapa(CardapioDoDia(hoje, completo).paraMapa())!;
      expect(c.lidoEm, hoje);
      expect(c.itens(Refeicao.cafe), ['Arroz', 'Feijão']);
    });
  });
}

void _portal() {
  String fixture(String nome) => File('fixtures/$nome').readAsStringSync();

  test('lerIdInterno', () {
    expect(lerIdInterno(fixture('portal_inicio.html')), '11111');
    expect(lerIdInterno(fixture('public/portal_login.html')), isNull);
  });

  group('lerIdentificacao', () {
    test('le a fixture', () {
      final d = lerIdentificacao(fixture('portal_relatorios.html'))!;
      expect(d.identificacao.nome, 'Pessoa Teste de Exemplo');
      expect(d.identificacao.primeiroNome, 'Pessoa');
      expect(d.identificacao.iniciais, 'PE');
      expect(d.identificacao.curso, 'Curso Exemplo');
      expect(d.identificacao.periodo, '3');
      expect(semestreCurto(d.identificacao.semestre), '2º / 2026');
      expect(d.matricula, '12345678901');
    });
    test('pagina de login nao vira dado', () {
      expect(lerIdentificacao(fixture('public/portal_login.html')), isNull);
    });
    test('nome em maiusculas fica apresentavel', () {
      expect(nomeApresentavel('MARIA DE SOUZA'), 'Maria de Souza');
      expect(nomeApresentavel('Maria de Souza'), 'Maria de Souza');
    });
  });

  group('lerHorarios', () {
    test('le dia, nome e hora pela coluna', () {
      final a = lerHorarios(fixture('portal_horarios_ajax.html'))!;
      expect(a, hasLength(3));
      final sabado = a.firstWhere((x) => x.diaSemana == DateTime.saturday);
      expect(sabado.disciplina, 'Disciplina Sabado');
      expect(sabado.inicioMin, 8 * 60);
      expect(sabado.fimMin, 12 * 60);
      expect(sabado.valeDe, DateTime(2026, 8, 3));
      expect(sabado.valeAte, DateTime(2026, 12, 12));
      expect(a.firstWhere((x) => x.diaSemana == DateTime.monday).disciplina, 'Disciplina Segunda');
      expect(a.firstWhere((x) => x.diaSemana == DateTime.tuesday).disciplina, 'Disciplina Terca');
    });
    test('sem quadro devolve null', () {
      expect(lerHorarios(fixture('public/portal_login.html')), isNull);
    });
    test('title fora do formato nao vira dado errado', () {
      expect(lerHorarios(fixture('portal_horarios_ajax.html').replaceFirst('Período: 03/08/26', 'Outro')), isNull);
    });
  });

  group('proximaAula', () {
    final seg = Aula(disciplina: 'Seg', diaSemana: DateTime.monday, inicioMin: 19 * 60, fimMin: 22 * 60 + 40);
    final sab = Aula(disciplina: 'Sab', diaSemana: DateTime.saturday, inicioMin: 8 * 60, fimMin: 12 * 60);
    // 2026-11-02 é segunda.
    test('hoje, perto', () {
      final p = proximaAula([seg, sab], DateTime(2026, 11, 2, 18, 40))!;
      expect(p.aula.disciplina, 'Seg');
      expect(p.rotulo, 'começa em 20 min');
    });
    test('hoje, longe', () {
      expect(proximaAula([seg], DateTime(2026, 11, 2, 10))!.rotulo, 'hoje às 19h');
    });
    test('em andamento', () {
      expect(proximaAula([seg], DateTime(2026, 11, 2, 20))!.rotulo, 'em andamento');
    });
    test('depois da aula passa para a seguinte', () {
      final p = proximaAula([seg, sab], DateTime(2026, 11, 2, 23))!;
      expect(p.aula.disciplina, 'Sab');
      expect(p.rotulo, 'sábado às 8h');
    });
    test('amanha', () {
      expect(proximaAula([sab], DateTime(2026, 11, 6, 12))!.rotulo, 'amanhã às 8h');
    });
    test('fora do periodo da turma nao conta', () {
      final vencida = Aula(
        disciplina: 'Velha',
        diaSemana: DateTime.monday,
        inicioMin: 19 * 60,
        fimMin: 20 * 60,
        valeAte: DateTime(2026, 10, 1),
      );
      expect(proximaAula([vencida], DateTime(2026, 11, 2, 10)), isNull);
    });
    test('sem aulas', () {
      expect(proximaAula([], DateTime(2026, 11, 2)), isNull);
    });
  });
}

void _notas() {
  String fixture(String nome) => File('fixtures/$nome').readAsStringSync();

  group('lerListaDeNotas', () {
    test('so o semestre mais recente', () {
      final l = lerListaDeNotas(fixture('portal_notas.html'))!;
      expect(l.semestre, '2° Semestre / 2026');
      expect(l.disciplinas.map((d) => d.disciplina), ['Disciplina Atual', 'Outra Disciplina']);
      expect(l.disciplinas.first.situacao, 'Matrícula');
      expect(l.disciplinas.first.urlNotas, startsWith('https://portal.ufac.br/aluno/ajax/aluno/nota/notaturma.action?idCurricAluno=900010001'));
      expect(l.disciplinas.first.urlNotas, contains('&ano=2026'));
    });
    test('pagina sem quadro devolve null', () {
      expect(lerListaDeNotas(fixture('public/portal_login.html')), isNull);
    });
  });

  group('lerNotasDaDisciplina', () {
    const d = DisciplinaDoSemestre('Disciplina Atual', 'Matrícula', null);
    test('le notas, media, faltas e situacao', () {
      final n = lerNotasDaDisciplina(fixture('portal_notaturma_ajax.html'), d);
      expect(n.notas.map((a) => a.rotulo), ['Nota 1', 'Nota 2']);
      expect(n.notas.map((a) => a.total), ['7,50', '8,50']);
      expect(n.notas.first.peso, '50.00%');
      expect(n.notas.first.itens.map((i) => '${i.rotulo}|${i.peso}|${i.valor}'), ['Aval. 1|100.00%|7,50', 'Total|100%|7,50']);
      expect(n.resumo.map((i) => '${i.rotulo}|${i.valor}'), ['Média|8,00', 'Exame|', 'Média Final|8,0']);
      expect(n.media, '8,0');
      expect(n.faltas, '4');
      expect(n.situacao, 'Aprovado');
    });
    test('sem quadro fica so com a situacao da lista', () {
      final n = lerNotasDaDisciplina('<html></html>', d);
      expect(n.notas, isEmpty);
      expect(n.situacaoApresentavel, 'Cursando');
      expect(n.media, '');
    });
    test('sobrevive a gravar e ler', () {
      final n = NotasDisciplina.deMapa(lerNotasDaDisciplina(fixture('portal_notaturma_ajax.html'), d).paraMapa());
      expect(n.notas.last.total, '8,50');
      expect(n.notas.first.itens.first.peso, '100.00%');
      expect(n.resumo.last.rotulo, 'Média Final');
      expect(n.faltas, '4');
    });
  });
}

void _historico() {
  String fixture(String nome) => File('fixtures/$nome').readAsStringSync();

  group('lerHistoricoRefeicoes', () {
    test('le as colunas, inclusive refeicao vazia', () {
      final r = lerHistoricoRefeicoes(fixture('eticket_refeicoes.html'))!;
      expect(r, hasLength(2));
      expect(r.first.data, '01/10/2026');
      expect(r.first.refeicao, '');
      expect(r.first.valor, 1.0);
      expect(r.last.refeicao, 'Jantar');
      expect(r.last.prato, startsWith('PRATO'));
    });
    test('outra pagina nao vira historico', () {
      expect(lerHistoricoRefeicoes(fixture('public/eticket_login.html')), isNull);
    });
  });

  group('lerHistoricoRecargas', () {
    test('le valor, forma, data, hora e situacao', () {
      final r = lerHistoricoRecargas(fixture('eticket_historico.html'))!;
      expect(r, hasLength(2));
      expect(r.first.valor, 5.0);
      expect(r.last.valor, 10.0);
      expect(r.first.forma, 'PIX');
      expect(r.first.data, '01/10/2026');
      expect(r.first.hora, '10:20');
      expect(r.first.situacao, 'Exemplo');
    });
    test('outra pagina nao vira historico', () {
      expect(lerHistoricoRecargas(fixture('public/eticket_login.html')), isNull);
    });
  });

  test('historico sobrevive a gravar e ler', () {
    final h = HistoricoRu(
      lidoEm: DateTime(2026, 11, 4),
      refeicoes: lerHistoricoRefeicoes(fixture('eticket_refeicoes.html'))!,
      recargas: lerHistoricoRecargas(fixture('eticket_historico.html'))!,
    );
    final lido = HistoricoRu.deMapa(h.paraMapa());
    expect(lido.refeicoes.last.prato, h.refeicoes.last.prato);
    expect(lido.recargas.first.valor, 5.0);
  });

  test('lerEnderecoComunicacoes vem do botao da pagina inicial', () {
    expect(lerEnderecoComunicacoes(fixture('portal_inicio.html')),
        startsWith('https://portal.ufac.br/comunicacoes/noticia/list.action?'));
    expect(lerEnderecoComunicacoes('<html></html>'), isNull);
  });
}

void _faltas() {
  group('situacaoFaltas', () {
    SituacaoFaltas? s(String f, {int? carga}) =>
        situacaoFaltas(f, cargaHoraria: carga, percentual: 0.25, permitidasSemCarga: 15);
    test('25% da carga horaria', () {
      expect(s('15', carga: 60)!.permitidas, 15);
      expect(s('15', carga: 60)!.nivel, NivelFaltas.atencao);
      expect(s('16', carga: 60)!.nivel, NivelFaltas.limite);
      expect(s('7', carga: 30)!.permitidas, 7);
      expect(s('5', carga: 30)!.nivel, NivelFaltas.tranquilo);
      expect(s('6', carga: 30)!.nivel, NivelFaltas.atencao);
      expect(s('8', carga: 30)!.nivel, NivelFaltas.limite);
      expect(s('8', carga: 30)!.estimado, isFalse);
      expect(s('8')!.estimado, isTrue);
    });
    test('niveis', () {
      expect(s('4')!.nivel, NivelFaltas.tranquilo);
      expect(s('11')!.nivel, NivelFaltas.tranquilo);
      expect(s('12')!.nivel, NivelFaltas.atencao);
      expect(s('15')!.nivel, NivelFaltas.atencao);
      expect(s('16')!.nivel, NivelFaltas.limite);
      expect(s('20')!.nivel, NivelFaltas.limite);
    });
    test('sem numero nao inventa aviso', () {
      expect(s(''), isNull);
      expect(s('–'), isNull);
    });
  });

  test('liga horario e notas pelo nome', () {
    final notas = [
      const NotasDisciplina(disciplina: 'Direito Civil VII', situacao: 'Matrícula', faltas: '6'),
      const NotasDisciplina(disciplina: 'Outra', situacao: 'Matrícula', faltas: '1'),
    ];
    expect(notasDaDisciplina(notas, 'Direito  Civil VII ( CCJSA100 )')?.faltas, '6');
    expect(notasDaDisciplina(notas, 'direito civil vii')?.faltas, '6');
    expect(notasDaDisciplina(notas, 'Direito Civil VI'), isNull);
    expect(notasDaDisciplina(null, 'Outra'), isNull);
  });
}

void _cargaHoraria() {
  String fixture(String nome) => File('fixtures/$nome').readAsStringSync();
  test('carga horaria vem da pagina da turma', () {
    expect(lerCargaHoraria(fixture('portal_turma.html')), 60);
    expect(lerCargaHoraria(fixture('public/portal_login.html')), isNull);
  });
  test('lista de notas guarda o endereco da turma', () {
    final l = lerListaDeNotas(fixture('portal_notas.html'))!;
    expect(l.disciplinas.first.urlTurma, 'https://portal.ufac.br/aluno/aluno/turma.action?turma=10001');
  });
  test('carga horaria sobrevive a gravar e ler', () {
    const n = NotasDisciplina(disciplina: 'X', situacao: 'Matrícula', faltas: '3', cargaHoraria: 60);
    expect(NotasDisciplina.deMapa(n.paraMapa()).cargaHoraria, 60);
    expect(NotasDisciplina.deMapa(n.comCargaHoraria(null).paraMapa()).cargaHoraria, isNull);
  });
}

void _limiteDoApp() {
  test('limite do app: 16 ainda passa, 17 reprova', () {
    SituacaoFaltas s(String f) => situacaoFaltas(f, cargaHoraria: null, percentual: 0, permitidasSemCarga: 16)!;
    expect(s('11').nivel, NivelFaltas.tranquilo);
    expect(s('12').nivel, NivelFaltas.atencao);
    expect(s('16').nivel, NivelFaltas.atencao);
    expect(s('16').permitidas, 16);
    expect(s('17').nivel, NivelFaltas.limite);
  });
}
