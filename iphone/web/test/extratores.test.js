// Mesmos casos de test/extratores_test.dart e professor_test.dart, contra as mesmas fixtures.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, test } from 'vitest';
import { aulaValeNoDia, proximaAula, semestreCurto, situacaoFaltas, notasDaDisciplina, situacaoApresentavel, totalDaNota, iniciais, primeiroNome } from '../src/lib/dominio/academico.js';
import { cardapioPendente, itensDoCardapio, proximaRefeicao } from '../src/lib/dominio/refeicoes.js';
import { formatarMoeda, mascararNumero, formatarPrazoCurto } from '../src/lib/dominio/formatos.js';
import { nomeApresentavel } from '../src/lib/extratores/comum.js';
import { lerEticketCardapio, lerEticketInicio, lerHistoricoRecargas, lerHistoricoRefeicoes, lerTokenLoginEticket } from '../src/lib/extratores/eticket.js';
import { lerCargaHoraria, lerEnderecoComunicacoes, lerHorarios, lerIdentificacao, lerIdInterno, lerListaDeNotas, lerNotasDaDisciplina } from '../src/lib/extratores/portal.js';
import { lerAulasDoMes, lerDetalheTurma, lerMesesAgenda, lerNomeProfessor, lerTurmasProfessor } from '../src/lib/extratores/professor.js';
import { aulasDoProfessor, semChamada } from '../src/lib/dominio/professor.js';

const fixture = (nome) => readFileSync(resolve(__dirname, "../../fixtures", nome), "utf8");

describe('eTICKET', () => {
  test('lê saldo e número da fixture', () => {
    expect(lerEticketInicio(fixture('eticket_home.html'))).toEqual({ saldo: 12.5, numeroQr: '12345678901' });
  });
  test('saldo com milhar', () => {
    expect(lerEticketInicio(fixture('eticket_home.html').replace('R$ 12,50', 'R$ 1.234,50')).saldo).toBe(1234.5);
  });
  test('página de login não vira dado', () => {
    expect(lerEticketInicio(fixture('public/eticket_login.html'))).toBeNull();
  });
  test('número com letra não vira dado', () => {
    expect(lerEticketInicio(fixture('eticket_home.html').replace('12345678901', 'abc'))).toBeNull();
  });
  test('token do login', () => {
    expect(lerTokenLoginEticket(fixture('public/eticket_login.html'))).toBe('TOKEN_FALSO');
  });
  test('cardápio pelo nome, não pela posição', () => {
    const t = lerEticketCardapio(fixture('eticket_menu.html'));
    expect(t.cafe.startsWith('Café preto')).toBe(true);
    expect(t.almoco).toBe('Não informado');
    expect(t.jantar).toBe('Não informado');
  });
  test('cardápio em linhas, com rótulos e saudação (formato de 12/11/2026)', () => {
    const texto = '-Bife de panela acebolado \n-Arroz a grega \n-Feijão carioca \nSALADA: Alface com repolho \nSOBREMESA: Gelado de coco com maçã caramelizada \n\nBom almoço <3';
    expect(itensDoCardapio(texto)).toEqual(['Bife de panela acebolado', 'Arroz a grega', 'Feijão carioca', 'Salada: Alface com repolho', 'Sobremesa: Gelado de coco com maçã caramelizada']);
  });
  test('cardápio em frase continua igual', () => {
    expect(itensDoCardapio('Café preto, Leite Integral, Pão com ovos mexidos, Melão.')).toEqual(['Café preto', 'Leite Integral', 'Pão com ovos mexidos', 'Melão']);
  });
  test('cardápio com marcação aninhada', () => {
    const t = lerEticketCardapio('<div><div class="x"><h2 class="meal-title">Janta</h2></div><div><p>R$ 1.00</p><div class="cardapio"> Arroz, feijão </div></div><h2 class="meal-title">Café da Manhã</h2><div class="cardapio">Não informado</div></div>');
    expect(t).toEqual({ jantar: 'Arroz, feijão', cafe: 'Não informado' });
  });
  test('página pública com cardápio publicado', () => {
    const t = lerEticketCardapio('<h2 class="meal-title">Café Da Manhã</h2><input class="meal-description" value="Pão, café"><h2 class="meal-title">Almoço</h2><input class="meal-description" value="Indisponível">');
    expect(t).toEqual({ cafe: 'Pão, café', almoco: 'Indisponível' });
  });
  test('página pública não vira cardápio', () => {
    expect(lerEticketCardapio(fixture('public/eticket_cardapio_indisponivel.html'))).toBeNull();
  });
  test('histórico de refeições', () => {
    const r = lerHistoricoRefeicoes(fixture('eticket_refeicoes.html'));
    expect(r).toHaveLength(2);
    expect(r[0].data).toBe('01/10/2026');
    expect(r[0].refeicao).toBe('');
    expect(r[0].valor).toBe(1);
    expect(r[1].refeicao).toBe('Jantar');
    expect(r[1].prato.startsWith('PRATO')).toBe(true);
    expect(lerHistoricoRefeicoes(fixture('public/eticket_login.html'))).toBeNull();
  });
  test('histórico de recargas', () => {
    const r = lerHistoricoRecargas(fixture('eticket_historico.html'));
    expect(r).toHaveLength(2);
    expect(r.map((x) => x.valor)).toEqual([5, 10]);
    expect(r[0]).toMatchObject({ forma: 'PIX', data: '01/10/2026', hora: '10:20', situacao: 'Exemplo' });
    expect(lerHistoricoRecargas(fixture('public/eticket_login.html'))).toBeNull();
  });
});

describe('cardápio do dia', () => {
  const hoje = new Date(2026, 10, 4, 12);
  const completo = { cafe: 'Arroz, Feijão.', almoco: 'Arroz, Feijão.', jantar: 'Arroz, Feijão.' };
  test('cardápio de ontem não vale hoje', () => {
    expect(cardapioPendente({ lidoEm: new Date(2026, 10, 3, 18).toISOString(), textos: completo }, hoje)).toBe(true);
  });
  test('refeição sem cardápio continua pendente', () => {
    expect(cardapioPendente({ lidoEm: hoje.toISOString(), textos: { ...completo, jantar: 'Não informado' } }, hoje)).toBe(true);
  });
  test('completo de hoje não pede nova leitura', () => {
    expect(cardapioPendente({ lidoEm: hoje.toISOString(), textos: completo }, hoje)).toBe(false);
  });
  test('itens', () => {
    expect(itensDoCardapio('Arroz, Feijão.')).toEqual(['Arroz', 'Feijão']);
    expect(itensDoCardapio('Não informado')).toEqual([]);
  });
  test('próxima refeição', () => {
    expect(proximaRefeicao(new Date(2026, 10, 4, 7)).id).toBe('cafe');
    expect(proximaRefeicao(new Date(2026, 10, 4, 8, 1)).id).toBe('almoco');
    expect(proximaRefeicao(new Date(2026, 10, 4, 14)).id).toBe('jantar');
    expect(proximaRefeicao(new Date(2026, 10, 4, 21)).id).toBe('cafe');
  });
});

describe('Portal', () => {
  test('id interno', () => {
    expect(lerIdInterno(fixture('portal_inicio.html'))).toBe('11111');
    expect(lerIdInterno(fixture('public/portal_login.html'))).toBeNull();
  });
  test('identificação', () => {
    const d = lerIdentificacao(fixture('portal_relatorios.html'));
    expect(d.identificacao.nome).toBe('Pessoa Teste de Exemplo');
    expect(primeiroNome(d.identificacao.nome)).toBe('Pessoa');
    expect(iniciais(d.identificacao.nome)).toBe('PE');
    expect(d.identificacao.curso).toBe('Curso Exemplo');
    expect(d.identificacao.periodo).toBe('3');
    expect(semestreCurto(d.identificacao.semestre)).toBe('2º / 2026');
    expect(d.matricula).toBe('12345678901');
    expect(lerIdentificacao(fixture('public/portal_login.html'))).toBeNull();
  });
  test('nome em maiúsculas fica apresentável', () => {
    expect(nomeApresentavel('MARIA DE SOUZA')).toBe('Maria de Souza');
    expect(nomeApresentavel('Maria de Souza')).toBe('Maria de Souza');
  });
  test('horários pela coluna', () => {
    const a = lerHorarios(fixture('portal_horarios_ajax.html'));
    expect(a).toHaveLength(3);
    const sabado = a.find((x) => x.diaSemana === 6);
    expect(sabado).toMatchObject({ disciplina: 'Disciplina Sabado', inicioMin: 480, fimMin: 720, valeDe: '2026-08-03', valeAte: '2026-12-12' });
    expect(a.find((x) => x.diaSemana === 1).disciplina).toBe('Disciplina Segunda');
    expect(a.find((x) => x.diaSemana === 2).disciplina).toBe('Disciplina Terca');
    expect(lerHorarios(fixture('public/portal_login.html'))).toBeNull();
    expect(lerHorarios(fixture('portal_horarios_ajax.html').replace('Período: 03/08/26', 'Outro'))).toBeNull();
  });
  test('lista de notas: só o semestre mais recente', () => {
    const l = lerListaDeNotas(fixture('portal_notas.html'));
    expect(l.semestre).toBe('2° Semestre / 2026');
    expect(l.disciplinas.map((d) => d.disciplina)).toEqual(['Disciplina Atual', 'Outra Disciplina']);
    expect(l.disciplinas[0].situacao).toBe('Matrícula');
    expect(l.disciplinas[0].urlNotas.startsWith('https://portal.ufac.br/aluno/ajax/aluno/nota/notaturma.action?idCurricAluno=900010001')).toBe(true);
    expect(l.disciplinas[0].urlNotas).toContain('&ano=2026');
    expect(l.disciplinas[0].urlTurma).toBe('https://portal.ufac.br/aluno/aluno/turma.action?turma=10001');
    expect(lerListaDeNotas(fixture('public/portal_login.html'))).toBeNull();
  });
  test('notas da disciplina', () => {
    const d = { disciplina: 'Disciplina Atual', situacao: 'Matrícula' };
    const n = lerNotasDaDisciplina(fixture('portal_notaturma_ajax.html'), d);
    expect(n.notas.map((a) => a.rotulo)).toEqual(['Nota 1', 'Nota 2']);
    expect(n.notas.map(totalDaNota)).toEqual(['7,50', '8,50']);
    expect(n.notas[0].peso).toBe('50.00%');
    expect(n.notas[0].itens.map((i) => `${i.rotulo}|${i.peso}|${i.valor}`)).toEqual(['Aval. 1|100.00%|7,50', 'Total|100%|7,50']);
    expect(n.resumo.map((i) => `${i.rotulo}|${i.valor}`)).toEqual(['Média|8,00', 'Exame|', 'Média Final|8,0']);
    expect(n).toMatchObject({ media: '8,0', faltas: '4', situacao: 'Aprovado' });
    const vazio = lerNotasDaDisciplina('<html></html>', d);
    expect(vazio.notas).toEqual([]);
    expect(situacaoApresentavel(vazio.situacao)).toBe('Cursando');
  });
  test('carga horária e comunicações', () => {
    expect(lerCargaHoraria(fixture('portal_turma.html'))).toBe(60);
    expect(lerCargaHoraria(fixture('public/portal_login.html'))).toBeNull();
    expect(lerEnderecoComunicacoes(fixture('portal_inicio.html')).startsWith('https://portal.ufac.br/comunicacoes/noticia/list.action?')).toBe(true);
    expect(lerEnderecoComunicacoes('<html></html>')).toBeNull();
  });
});

describe('próxima aula', () => {
  const seg = { disciplina: 'Seg', diaSemana: 1, inicioMin: 19 * 60, fimMin: 22 * 60 + 40 };
  const sab = { disciplina: 'Sab', diaSemana: 6, inicioMin: 8 * 60, fimMin: 12 * 60 };
  // 2026-11-02 é segunda.
  test('hoje, perto', () => {
    const p = proximaAula([seg, sab], new Date(2026, 10, 2, 18, 40));
    expect(p.aula.disciplina).toBe('Seg');
    expect(p.rotulo).toBe('começa em 20 min');
  });
  test('rótulos', () => {
    expect(proximaAula([seg], new Date(2026, 10, 2, 10)).rotulo).toBe('hoje às 19h');
    expect(proximaAula([seg], new Date(2026, 10, 2, 20)).rotulo).toBe('em andamento');
    expect(proximaAula([seg, sab], new Date(2026, 10, 2, 23)).rotulo).toBe('sábado às 8h');
    expect(proximaAula([sab], new Date(2026, 10, 6, 12)).rotulo).toBe('amanhã às 8h');
  });
  test('fora do período da turma não conta', () => {
    expect(proximaAula([{ ...seg, valeAte: '2026-10-01' }], new Date(2026, 10, 2, 10))).toBeNull();
    expect(aulaValeNoDia({ ...seg, valeDe: '2026-11-02' }, new Date(2026, 10, 2, 23))).toBe(true);
    expect(proximaAula([], new Date(2026, 10, 2))).toBeNull();
  });
});

describe('faltas', () => {
  const s = (f, carga = null) => situacaoFaltas(f, { cargaHoraria: carga, percentual: 0.25, permitidasSemCarga: 15 });
  test('25% da carga horária', () => {
    expect(s('15', 60).permitidas).toBe(15);
    expect(s('15', 60).nivel).toBe('atencao');
    expect(s('16', 60).nivel).toBe('limite');
    expect(s('5', 30).nivel).toBe('tranquilo');
    expect(s('8', 30).nivel).toBe('limite');
    expect(s('8').estimado).toBe(true);
    expect(s('')).toBeNull();
    expect(s('–')).toBeNull();
  });
  test('limite do app: 16 ainda passa, 17 reprova', () => {
    const l = (f) => situacaoFaltas(f);
    expect(l('11').nivel).toBe('tranquilo');
    expect(l('12').nivel).toBe('atencao');
    expect(l('16').nivel).toBe('atencao');
    expect(l('16').permitidas).toBe(16);
    expect(l('17').nivel).toBe('limite');
  });
  test('liga horário e notas pelo nome', () => {
    const notas = [{ disciplina: 'Direito Civil VII', faltas: '6' }, { disciplina: 'Outra', faltas: '1' }];
    expect(notasDaDisciplina(notas, 'Direito  Civil VII ( CCJSA100 )').faltas).toBe('6');
    expect(notasDaDisciplina(notas, 'direito civil vii').faltas).toBe('6');
    expect(notasDaDisciplina(notas, 'Direito Civil VI')).toBeNull();
    expect(notasDaDisciplina(null, 'Outra')).toBeNull();
  });
});

describe('Portal do Professor', () => {
  test('nome e turmas', () => {
    expect(lerNomeProfessor(fixture('professor_turmas_frequencia.html'))).toBe('Maria de Teste Souza');
    expect(lerNomeProfessor('<html></html>')).toBeNull();
    const t = lerTurmasProfessor(fixture('professor_turmas_frequencia.html'));
    expect(t).toHaveLength(2);
    expect(t[0]).toMatchObject({
      id: '1001', disciplina: 'Direito Civil II', codigo: 'CCJ123', nome: 'T. DIR01 - 1A',
      curso: 'Bacharelado em Direito', periodo: '2° Semestre / 2026', situacaoFrequencia: 'Frequência Parcialmente Lançada',
    });
    expect(t[1].situacaoFrequencia).toBe('Frequência Não Lançada');
    expect(lerTurmasProfessor(fixture('professor_turmas_notas.html')).map((x) => x.situacaoFrequencia)[0]).toBe('Lançamento Aberto');
    expect(lerTurmasProfessor('<html><body>Sessão expirada</body></html>')).toBeNull();
  });
  test('detalhe da turma', () => {
    const d = lerDetalheTurma(fixture('professor_turma.html'));
    expect(d).toMatchObject({ curso: 'Bacharelado em Direito', disciplina: 'Direito Civil II', tipo: 'Turma Regular', periodo: '2° Semestre', cargaHorariaRealizada: 28, vagas: 40, matriculas: 35 });
    expect(d.docentes).toEqual([['Maria de Teste Souza', 'Responsável'], ['João Exemplo Lima', 'Colaborador']]);
    expect(d.horarios).toHaveLength(2);
    expect(d.horarios[0]).toMatchObject({ diaSemana: 1, inicioMin: 480, fimMin: 600, tipo: 'Teórica', valeDe: '2026-08-03' });
    expect(d.horarios[1].diaSemana).toBe(3);
    expect(d.modeloNotas.map((g) => `${g.rotulo} ${g.peso}`)).toEqual(['Nota 1 50.00%', 'Nota 2 50.00%']);
    expect(d.modeloNotas[1].avaliacoes.map((a) => `${a.codigo}|${a.peso}|${a.nome}`)).toEqual(['Aval. 1|60.00%|Prova', 'Aval. 2|40.00%|Seminário']);
    expect(lerDetalheTurma('<html></html>')).toBeNull();
    expect(aulasDoProfessor([{ turma: { disciplina: 'Direito Civil II', nome: 'T. DIR01 - 1A' }, detalhe: d }]).map((x) => `${x.disciplina}/${x.diaSemana}`))
      .toEqual(['Direito Civil II · T. DIR01 - 1A/1', 'Direito Civil II · T. DIR01 - 1A/3']);
  });
  test('agenda e chamadas pendentes', () => {
    const m = lerMesesAgenda(fixture('professor_agenda.html'));
    expect(m.map((x) => `${x.indice}:${x.anoMes}`)).toEqual(['0:2026_10', '1:2026_11']);
    expect(m[1].mes).toBe(11);
    const a = lerAulasDoMes(fixture('professor_aulas_mes_ajax.html'), { ano: 2026, mes: 11 });
    expect(a).toHaveLength(3);
    expect(a[0]).toMatchObject({ data: '2026-11-02', chamadaLancada: true, conteudo: 'Contratos: formação', periodos: 2 });
    expect(a[1]).toMatchObject({ chamadaLancada: false, conteudo: null, idAgenda: '5002', inicioMin: 600 });
    expect(semChamada({ aulasDoMes: a }, new Date(2026, 10, 11, 9)).map((x) => x.data)).toEqual(['2026-11-04']);
    expect(lerAulasDoMes('<p>erro</p>', { ano: 2026, mes: 11 })).toBeNull();
  });
});

test('formatos', () => {
  expect(mascararNumero('12345678901')).toBe('•••••••8901');
  expect(mascararNumero('123')).toBe('123');
  expect(formatarMoeda(1234.5)).toBe('R$ 1.234,50');
  const agora = new Date(2026, 10, 10, 12);
  expect(formatarPrazoCurto(new Date(2026, 10, 10, 23, 59), agora)).toBe('hoje 23h59');
  expect(formatarPrazoCurto(new Date(2026, 10, 11, 10), agora)).toBe('amanhã 10h');
  expect(formatarPrazoCurto(new Date(2026, 10, 13, 18), agora)).toBe('sex 18h');
});
