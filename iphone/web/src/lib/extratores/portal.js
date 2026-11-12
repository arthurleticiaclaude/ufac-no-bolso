// Extratores do Portal do Aluno. Porte de lib/extractors/portal.dart.
import { dataISO } from '../dominio/formatos.js';
import { filhos, limpo, nomeApresentavel, parse } from './comum.js';

const BASE = 'https://portal.ufac.br';

/** O número interno que o portal usa nos endereços (não é a matrícula de 11 dígitos). */
export function lerIdInterno(pagina) {
  const v = parse(pagina).querySelector('input#matricula')?.getAttribute('value')?.trim();
  return v && /^\d+$/.test(v) ? v : null;
}

/** O link "Mais Relatórios" da página de Relatórios, como endereço completo. */
export function lerEnderecoMaisRelatorios(pagina) {
  const link = [...parse(pagina).querySelectorAll('a')].find((a) => a.querySelector('.linkmaisrelatorios'));
  const destino = link?.getAttribute('href');
  return destino ? new URL(destino, BASE).toString() : null;
}

/** O endereço de Comunicações muda por sistema, então vem do botão da página inicial. */
export function lerEnderecoComunicacoes(pagina) {
  const m = /\/comunicacoes\/noticia\/list\.action[^'"]*/.exec(pagina);
  return m ? BASE + m[0].replace(/&amp;/g, '&') : null;
}

/** Página de Relatórios: nome, matrícula, curso, período e semestre. */
export function lerIdentificacao(pagina) {
  const doc = parse(pagina);
  const nome = limpo(doc.querySelector('#menu .ui-button-text, #menu button')?.textContent);
  const campos = {};
  for (const td of doc.querySelectorAll('table.table-topo td')) {
    const rotulo = td.querySelector('span.label')?.textContent ?? '';
    campos[limpo(rotulo)] = limpo(td.textContent.replace(rotulo, ''));
  }
  const matricula = campos['Matrícula:'];
  const curso = campos['Curso:'];
  const periodo = campos['Período Atual:'];
  const semestre = campos['Período de Matrícula:'];
  if (!nome || matricula == null || curso == null || periodo == null || semestre == null) return null;
  if (!/^\d{6,}$/.test(matricula)) return null;
  return { identificacao: { nome: nomeApresentavel(nome), curso, periodo, semestre }, matricula };
}

/** A carga horária fica na página da turma ("Carga Horária ...: 60"). */
export function lerCargaHoraria(pagina) {
  for (const rotulo of parse(pagina).querySelectorAll('span.label')) {
    if (!limpo(rotulo.textContent).startsWith('Carga Horária')) continue;
    const valor = rotulo.parentElement?.textContent.replace(rotulo.textContent, '') ?? '';
    const n = Number(/\d+/.exec(valor)?.[0]);
    if (n > 0) return n;
  }
  return null;
}

/** Página de Notas. Só o semestre mais recente, para não fazer dezenas de pedidos à Ufac. */
export function lerListaDeNotas(pagina) {
  const titulo = parse(pagina).querySelector('a.accordionTurma');
  const tabela = titulo?.parentElement?.nextElementSibling?.querySelector('table.table-turmas');
  if (!titulo || !tabela) return null;
  const disciplinas = [];
  for (const linha of tabela.querySelectorAll('tbody tr')) {
    const celulas = linha.children;
    if (celulas.length < 2) continue;
    const link = [...linha.querySelectorAll('a')]
      .map((a) => /\/aluno\/ajax\/aluno\/nota\/notaturma\.action\?[^']+/.exec(a.getAttribute('href') ?? ''))
      .find(Boolean);
    const turma = linha.querySelector('a[href*="turma.action?turma="]')?.getAttribute('href');
    disciplinas.push({
      disciplina: limpo(celulas[0].textContent).replace(/\s*\([^()]*\)$/, ''),
      situacao: limpo(celulas[1].textContent),
      urlNotas: link ? BASE + link[0] : null,
      urlTurma: turma ? new URL(turma, BASE).toString() : null,
    });
  }
  return { semestre: limpo(titulo.textContent), disciplinas };
}

/** Quadro de notas de uma disciplina. Sem quadro, volta só com o que já veio da lista. */
export function lerNotasDaDisciplina(pagina, d) {
  const doc = parse(pagina);
  const notas = [];
  const resumo = [];
  const quadro = doc.querySelector('table.nota');
  // O quadro tem tabelas dentro de tabelas: só vale a linha direta de cada parte.
  const colunasDe = (parte) => {
    const secao = filhos(quadro, parte)[0];
    return secao?.children.length ? [...secao.children[0].children] : [];
  };
  const titulos = colunasDe('thead');
  const valores = colunasDe('tbody');
  for (let i = 0; i < titulos.length && i < valores.length; i++) {
    const cabecalhos = [...titulos[i].querySelectorAll('td')];
    const dados = [...valores[i].querySelectorAll('td')];
    const itens = cabecalhos.map((c, j) => ({
      rotulo: limpo(c.querySelector('.labelAvaliacao')?.textContent ?? c.textContent),
      peso: limpo(c.querySelector('.labelPercentagem')?.textContent ?? ''),
      valor: j < dados.length ? limpo(dados[j].textContent) : '',
    }));
    const titulo = limpo(titulos[i].querySelector('.labelNota')?.textContent ?? '');
    if (!titulo) {
      resumo.push(...itens);
      continue;
    }
    const m = /^(.*?)\s*\(([^)]*)\)$/.exec(titulo);
    notas.push({ rotulo: m?.[1] ?? titulo, peso: m?.[2] ?? '', itens });
  }
  const info = {};
  const colunas = doc.querySelector('.divInfo')?.children ?? [];
  if (colunas.length >= 2) {
    const rotulos = colunas[0].children;
    const dados = colunas[1].children;
    for (let i = 0; i < rotulos.length && i < dados.length; i++) {
      info[limpo(rotulos[i].textContent)] = limpo(dados[i].textContent);
    }
  }
  const campo = (inicio) => Object.entries(info).find(([k]) => k.startsWith(inicio))?.[1] ?? '';
  const situacao = campo('Situação');
  return {
    disciplina: d.disciplina,
    situacao: situacao || d.situacao,
    notas,
    resumo,
    media: campo('Média'),
    faltas: campo('Total de Faltas'),
    cargaHoraria: null,
  };
}

const dataCurta = (d, m, a) => dataISO(new Date(2000 + Number(a), Number(m) - 1, Number(d)));

function nomeDaAula(link) {
  const texto = [...link.childNodes].filter((n) => n.nodeType === 3).map((n) => limpo(n.textContent)).find(Boolean);
  return texto ?? '';
}

/** Quadro de horários. Colunas de domingo a sábado. Null se o quadro não existir. */
export function lerHorarios(pagina) {
  const quadro = parse(pagina).querySelector('#quadrohorario');
  if (!quadro) return null;
  const vistas = new Set();
  const aulas = [];
  const padrao = /(\d{2})\/(\d{2})\/(\d{2})\s*-\s*(\d{2})\/(\d{2})\/(\d{2}).*?(\d{2}):(\d{2})\s*às\s*(\d{2}):(\d{2})/;
  for (const linha of quadro.querySelectorAll('tbody tr')) {
    const celulas = linha.children;
    for (let coluna = 1; coluna < celulas.length && coluna <= 7; coluna++) {
      for (const link of celulas[coluna].querySelectorAll('.turmaqh a')) {
        const m = padrao.exec(link.getAttribute('title') ?? '');
        const nome = nomeDaAula(link);
        if (!m || !nome) return null;
        const aula = {
          disciplina: nome,
          diaSemana: coluna === 1 ? 7 : coluna - 1,
          inicioMin: Number(m[7]) * 60 + Number(m[8]),
          fimMin: Number(m[9]) * 60 + Number(m[10]),
          valeDe: dataCurta(m[1], m[2], m[3]),
          valeAte: dataCurta(m[4], m[5], m[6]),
        };
        // A mesma aula pode aparecer em mais de uma faixa do quadro.
        const chave = `${aula.disciplina}|${aula.diaSemana}|${aula.inicioMin}`;
        if (!vistas.has(chave)) {
          vistas.add(chave);
          aulas.push(aula);
        }
      }
    }
  }
  return aulas;
}
