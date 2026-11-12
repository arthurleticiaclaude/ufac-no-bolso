// Extratores do Portal do Professor. Porte de lib/extractors/professor.dart.
import { dataISO } from '../dominio/formatos.js';
import { limpo, nomeApresentavel, parse } from './comum.js';

const DIAS = { segunda: 1, terça: 2, terca: 2, quarta: 3, quinta: 4, sexta: 5, sábado: 6, sabado: 6, domingo: 7 };

export const diaDaSemanaPorNome = (texto) => DIAS[limpo(texto).toLowerCase().split(/[-,\s]/)[0]] ?? null;

/** "08:00" vira 480. */
export function minutos(texto) {
  const m = /(\d{1,2}):(\d{2})/.exec(texto ?? '');
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

function data(texto) {
  const m = /(\d{2})\/(\d{2})\/(\d{4})/.exec(texto ?? '');
  return m ? dataISO(new Date(Number(m[3]), Number(m[2]) - 1, Number(m[1]))) : null;
}

const inteiro = (t) => {
  const m = /\d+/.exec(t ?? '');
  return m ? Number(m[0]) : null;
};
const ouNull = (t) => (t ? t : null);

/** O nome no botão do topo, presente em todas as páginas do portal. */
export function lerNomeProfessor(pagina) {
  const nome = limpo(parse(pagina).querySelector('.menu-botao button, #menu button')?.textContent);
  return nome ? nomeApresentavel(nome) : null;
}

/** "Minhas turmas" (de Frequência ou de Notas). A coluna Situação muda de sentido conforme a página. */
export function lerTurmasProfessor(pagina) {
  const tabela = parse(pagina).querySelector('table#turmasLiberadas');
  if (!tabela) return null;
  const cabecalho = [...tabela.querySelectorAll('thead th')].map((th) => limpo(th.textContent));
  const iDisciplina = cabecalho.indexOf('Disciplina');
  const iSituacao = cabecalho.indexOf('Situação');
  const iPeriodo = cabecalho.indexOf('Período');
  if (iDisciplina < 0 || iSituacao < 0) return null;
  const turmas = [];
  for (const tr of tabela.querySelectorAll('tbody tr')) {
    const tds = tr.querySelectorAll('td');
    if (tds.length <= iSituacao || tds.length <= iDisciplina) continue;
    const link = [...tr.querySelectorAll('a[href]')].find((a) => a.getAttribute('href').includes('turma.action'));
    const id = /turma=(\d+)/.exec(link?.getAttribute('href') ?? '')?.[1];
    if (!link || !id) continue;
    const celula = tds[iDisciplina];
    const bruto = limpo(celula.querySelector('strong')?.textContent ?? celula.textContent);
    const m = /^(.*?)\s*\(\s*([^)]+?)\s*\)\s*$/.exec(bruto);
    turmas.push({
      id,
      disciplina: m?.[1] ?? bruto,
      codigo: m?.[2] ?? null,
      nome: limpo(link.textContent),
      curso: ouNull(limpo(celula.querySelector('.curso')?.textContent)),
      periodo: iPeriodo < 0 ? null : ouNull(limpo(tds[iPeriodo].textContent)),
      situacaoFrequencia: ouNull(limpo(tds[iSituacao].textContent)),
      situacaoNotas: null,
    });
  }
  return turmas;
}

/** "Detalhes da Turma": dados gerais, totais, docentes, horários e modelo de notas. */
export function lerDetalheTurma(pagina) {
  const doc = parse(pagina);
  const campos = {};
  for (const rotulo of doc.querySelectorAll('span.label')) {
    const chave = limpo(rotulo.textContent).replace(/:/g, '');
    const td = rotulo.parentElement;
    if (!td) continue;
    let valor = limpo(td.textContent.replace(rotulo.textContent, ''));
    if (!valor && td.nextElementSibling) valor = limpo(td.nextElementSibling.textContent);
    if (valor && !(chave in campos)) campos[chave] = valor;
  }
  const tabelaCom = (th) =>
    [...doc.querySelectorAll('table')].find((t) => [...t.querySelectorAll('th')].some((e) => limpo(e.textContent) === th));

  const horarios = [];
  for (const tr of tabelaCom('Hora Início')?.querySelectorAll('tbody tr') ?? []) {
    const tds = [...tr.querySelectorAll('td')].map((e) => limpo(e.textContent));
    if (tds.length < 3) continue;
    const dia = diaDaSemanaPorNome(tds[0]), ini = minutos(tds[1]), fim = minutos(tds[2]);
    if (dia == null || ini == null || fim == null) continue;
    horarios.push({
      diaSemana: dia,
      inicioMin: ini,
      fimMin: fim,
      tipo: tds.length > 3 ? ouNull(tds[3]) : null,
      valeDe: tds.length > 4 ? data(tds[4]) : null,
      valeAte: tds.length > 5 ? data(tds[5]) : null,
    });
  }

  const docentes = [];
  for (const tr of tabelaCom('Nome do Docente')?.querySelectorAll('tbody tr') ?? []) {
    const tds = [...tr.querySelectorAll('td')].map((e) => limpo(e.textContent));
    if (tds.length >= 2 && tds[0]) docentes.push([nomeApresentavel(tds[0]), tds[1]]);
  }

  const modeloNotas = [];
  for (const link of doc.querySelectorAll('table.tableNotas a.linkNota')) {
    const celula = link.parentElement;
    const peso = /\(([\d.,]+%)\)/.exec(celula.textContent)?.[1] ?? '';
    const conteudo = celula.parentElement.nextElementSibling;
    const avaliacoes = [];
    for (const tr of conteudo?.querySelectorAll('table.tableavaliacao tr') ?? []) {
      const tds = [...tr.querySelectorAll('td')].map((e) => limpo(e.textContent));
      if (tds.length >= 3) avaliacoes.push({ codigo: tds[0], peso: tds[1], nome: tds[2] });
    }
    modeloNotas.push({ rotulo: limpo(link.textContent), peso, avaliacoes });
  }

  if (campos['Disciplina'] == null && !horarios.length) return null;
  return {
    curso: campos['Curso'] ?? null,
    disciplina: campos['Disciplina'] ?? null,
    tipo: campos['Tipo de Turma'] ?? null,
    periodo: campos['Período'] ?? null,
    cargaHorariaRealizada: inteiro(campos['Carga Horária Realizada']),
    vagas: inteiro(campos['Vagas Totais']),
    matriculas: inteiro(campos['Total de Matrículas']),
    docentes,
    horarios,
    modeloNotas,
  };
}

/** Os meses da Agenda da Turma, com o índice que o portal usa para carregar cada um. */
export const lerMesesAgenda = (pagina) =>
  [...parse(pagina).querySelectorAll('a.mesesAccordion')]
    .map((a) => ({
      indice: Number.parseInt(a.getAttribute('index'), 10),
      ano: Number.parseInt(a.getAttribute('ano'), 10),
      mes: Number.parseInt(a.getAttribute('mes'), 10),
      anoMes: a.getAttribute('anomes') ?? '',
    }))
    .filter((m) => Number.isInteger(m.indice) && Number.isInteger(m.ano) && Number.isInteger(m.mes));

/** As aulas de um mês (trecho de HTML). Null se não for a tabela esperada. */
export function lerAulasDoMes(pagina, { ano, mes }) {
  const doc = parse(pagina);
  const temCabecalho = [...doc.querySelectorAll('th')].some((th) => limpo(th.textContent) === 'Situação');
  const linhas = [...doc.querySelectorAll('tr.row')];
  if (!temCabecalho && !linhas.length) return null;
  const aulas = [];
  for (const tr of linhas) {
    const tds = tr.querySelectorAll('td');
    if (tds.length < 4) continue;
    const dia = inteiro(/dia\s+(\d+)/.exec(tds[0].textContent)?.[1]);
    const horas = /(\d{1,2}:\d{2})\D+(\d{1,2}:\d{2})/.exec(tds[2].textContent);
    const situacao = limpo(tds[3].textContent).toLowerCase();
    if (dia == null || !horas || !situacao.includes('lançada')) continue;
    const conteudo = limpo(tr.querySelector('a.add-cont-min')?.textContent);
    const chamada = [...tr.querySelectorAll('a[href]')].find((a) => a.getAttribute('href').includes('horaaula.action'));
    aulas.push({
      data: dataISO(new Date(ano, mes - 1, dia)),
      inicioMin: minutos(horas[1]),
      fimMin: minutos(horas[2]),
      chamadaLancada: !situacao.includes('não lançada'),
      periodos: tds.length > 4 ? inteiro(tds[4].textContent) : null,
      conteudo: !conteudo || conteudo.toLowerCase() === 'sem conteúdo' ? null : conteudo,
      idAgenda: /agenda=(\d+)/.exec(chamada?.getAttribute('href') ?? '')?.[1] ?? null,
    });
  }
  return aulas;
}
