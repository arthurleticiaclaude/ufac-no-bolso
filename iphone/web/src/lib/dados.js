// Repositórios: leem da Ufac (pelo Worker), guardam no IndexedDB e devolvem.
// Regra da Ufac: poucos pedidos, só ao abrir, ao voltar (no máximo a cada 15 min) ou ao puxar para atualizar.
import { enderecoDaUltimaPagina, lerPagina, marcarExpirado, pedir, tentarReentrar } from './api.js';
import { apagar, gravar, ler } from './armazenamento.js';
import { caminhos } from './config.js';
import { lerEticketCardapio, lerEticketInicio, lerHistoricoRecargas, lerHistoricoRefeicoes } from './extratores/eticket.js';
import { diagnosticoPagina, lerCargaHoraria, lerEnderecoComunicacoes, lerEnderecoMaisRelatorios, lerHorarios, lerIdentificacao, lerIdInterno, lerListaDeNotas, lerNotasDaDisciplina } from './extratores/portal.js';
import { lerAulasDoMes, lerDetalheTurma, lerMesesAgenda, lerNomeProfessor, lerTurmasProfessor } from './extratores/professor.js';
import { registrar, semParametros } from './registro.js';
import { cardapioPendente, cardapioValeEm, itensDoCardapio } from './dominio/refeicoes.js';

const agoraISO = () => new Date().toISOString();
const INTERVALO_MIN = 15 * 60 * 1000;

/** Erro com a frase que a pessoa vai ler. */
export class ErroLeitura extends Error {}

/** Erro de leitura que também vai para o registro, com a forma da página (sem o conteúdo) para o relato. */
function falhaDeLeitura(mensagem, o, pagina) {
  registrar('leitura', { o, ...(pagina != null ? diagnosticoPagina(pagina, enderecoDaUltimaPagina()) : {}) });
  return new ErroLeitura(mensagem);
}

export async function recente(chave, intervalo = INTERVALO_MIN) {
  const v = await ler(chave);
  return v?.lidoEm && Date.now() - new Date(v.lidoEm).getTime() < intervalo;
}

// ---------- RU ----------

export async function atualizarRu() {
  const html = await lerPagina('eticket', caminhos.eticketInicio);
  if (html === null) return null;
  const dados = lerEticketInicio(html);
  if (!dados) throw falhaDeLeitura('Não consegui ler o saldo no eTICKET.', 'saldo', html);
  const ru = { ...dados, lidoEm: agoraISO() };
  await gravar('ru', ru);
  return ru;
}

export async function atualizarCardapio({ forcar = false } = {}) {
  const atual = await ler('cardapio');
  if (!forcar && !cardapioPendente(atual, new Date())) return atual;
  const html = await lerPagina('eticket', caminhos.eticketCardapio);
  let textos = html === null ? null : lerEticketCardapio(html);
  let fonte = 'logada';
  if (!textos) {
    // Sessão do eTICKET caída ou página em outro formato: tenta a página pública (às vezes ela já tem o cardápio).
    const publica = await pedir('eticket', caminhos.eticketCardapioPublico).catch(() => null);
    textos = publica && publica.status < 400 ? lerEticketCardapio(await publica.resposta.text()) : null;
    fonte = 'publica';
  }
  if (!textos) {
    if (html === null) return atual;
    throw falhaDeLeitura('Não consegui ler o cardápio no eTICKET.', 'cardápio', html);
  }
  // A página pública diz "Indisponível" mesmo com cardápio publicado: ela não apaga o que a logada já trouxe hoje.
  if (fonte === 'publica' && cardapioValeEm(atual, new Date())) {
    for (const [id, t] of Object.entries(atual.textos ?? {})) {
      if (itensDoCardapio(t).length && !itensDoCardapio(textos[id]).length) textos[id] = t;
    }
  }
  const c = { lidoEm: agoraISO(), textos, fonte };
  await gravar('cardapio', c);
  return c;
}

export async function atualizarHistorico() {
  const [credito, refeicoes] = await Promise.all([
    lerPagina('eticket', caminhos.eticketHistorico),
    lerPagina('eticket', caminhos.eticketHistoricoRefeicoes),
  ]);
  if (credito === null || refeicoes === null) return null;
  const h = { lidoEm: agoraISO(), recargas: lerHistoricoRecargas(credito) ?? [], refeicoes: lerHistoricoRefeicoes(refeicoes) ?? [] };
  await gravar('historico', h);
  return h;
}

// ---------- Portal do Aluno ----------

async function idInterno() {
  const salvo = await ler('idInterno');
  if (salvo) return salvo;
  const html = await lerPagina('portal', caminhos.portalInicio);
  if (html === null) return null;
  const id = lerIdInterno(html);
  if (!id) {
    // Guarda só a forma da página (sem dados pessoais) para o "Relatar um problema".
    await gravar('diagnosticoPortal', { ...diagnosticoPagina(html, enderecoDaUltimaPagina()), em: agoraISO() });
    throw falhaDeLeitura('Não consegui ler seus dados no Portal.', 'número interno', html);
  }
  await gravar('idInterno', id);
  await apagar('diagnosticoPortal');
  const comunicacoes = lerEnderecoComunicacoes(html);
  if (comunicacoes) await gravar('urlComunicacoes', comunicacoes);
  return id;
}

export async function atualizarIdentificacao() {
  const id = await idInterno();
  if (!id) return null;
  const html = await lerPagina('portal', caminhos.relatorios(id));
  if (html === null) return null;
  const d = lerIdentificacao(html);
  if (!d) throw falhaDeLeitura('Não consegui ler sua identificação no Portal.', 'identificação', html);
  const ident = { ...d.identificacao, matricula: d.matricula, lidoEm: agoraISO() };
  await gravar('identificacao', ident);
  const mais = lerEnderecoMaisRelatorios(html);
  if (mais) await gravar('urlMaisRelatorios', mais);
  return ident;
}

export async function atualizarHorarios() {
  const id = await idInterno();
  if (!id) return null;
  const html = await lerPagina('portal', caminhos.horarios(id), { xhr: true });
  if (html === null) return null;
  const aulas = lerHorarios(html);
  if (!aulas) throw falhaDeLeitura('Não consegui ler seus horários no Portal.', 'horários', html);
  const h = { aulas, lidoEm: agoraISO() };
  await gravar('horarios', h);
  return h;
}

const caminhoNoWorker = (url) => {
  const u = new URL(url);
  return u.pathname + u.search;
};

export async function atualizarNotas() {
  const id = await idInterno();
  if (!id) return null;
  const html = await lerPagina('portal', caminhos.notas(id));
  if (html === null) return null;
  const lista = lerListaDeNotas(html);
  if (!lista) throw falhaDeLeitura('Não consegui ler suas notas no Portal.', 'notas', html);
  const anteriores = (await ler('notas'))?.disciplinas ?? [];
  const disciplinas = [];
  // Uma por vez, para não sobrecarregar o portal.
  for (const d of lista.disciplinas) {
    let n = { disciplina: d.disciplina, situacao: d.situacao, notas: [], resumo: [], media: '', faltas: '', cargaHoraria: null };
    if (d.urlNotas) {
      const pagina = await lerPagina('portal', caminhoNoWorker(d.urlNotas), { xhr: true });
      if (pagina === null) return null;
      n = lerNotasDaDisciplina(pagina, d);
    }
    const anterior = anteriores.find((a) => a.disciplina === d.disciplina);
    n.cargaHoraria = anterior?.cargaHoraria ?? null;
    if (n.cargaHoraria == null && d.urlTurma) {
      const turma = await lerPagina('portal', caminhoNoWorker(d.urlTurma));
      if (turma) n.cargaHoraria = lerCargaHoraria(turma);
    }
    disciplinas.push(n);
  }
  const notas = { semestre: lista.semestre, disciplinas, lidoEm: agoraISO() };
  await gravar('notas', notas);
  return notas;
}

/** PDF de um relatório, como Blob. Null se a sessão do portal caiu. */
export async function baixarRelatorio(acao) {
  const id = await idInterno();
  if (!id) return null;
  let r = await pedir('portal', caminhos.relatorio(acao, id), { accept: 'application/pdf' });
  // Sessão caída: entra sozinho (se a pessoa deixou) e pede o PDF uma vez mais.
  if (r.estado === 'naLogin' && (await tentarReentrar('portal'))) r = await pedir('portal', caminhos.relatorio(acao, id), { accept: 'application/pdf' });
  if (r.estado === 'naLogin' || r.estado === 'trocarSenha') {
    await marcarExpirado('portal', true);
    return null;
  }
  const tipo = r.resposta.headers.get('Content-Type') ?? '';
  if (!tipo.includes('pdf')) {
    registrar('leitura', { o: 'PDF', relatorio: acao, status: r.status, tipo, foiPara: semParametros(r.urlFinal) });
    throw new ErroLeitura('O Portal não gerou o PDF agora. Tente de novo.');
  }
  return r.resposta.blob();
}

// ---------- Portal do Professor ----------

export async function atualizarProfessor() {
  const htmlFreq = await lerPagina('professor', caminhos.professorTurmasFrequencia);
  if (htmlFreq === null) return null;
  const turmas = lerTurmasProfessor(htmlFreq);
  if (!turmas) throw falhaDeLeitura('Não consegui ler suas turmas no Portal do Professor.', 'turmas do professor', htmlFreq);
  const htmlNotas = await lerPagina('professor', caminhos.professorTurmasNotas);
  const notas = htmlNotas ? lerTurmasProfessor(htmlNotas) ?? [] : [];
  const agora = new Date();
  const completas = [];
  for (const t of turmas) {
    t.situacaoNotas = notas.find((n) => n.id === t.id)?.situacaoFrequencia ?? null;
    const detalheHtml = await lerPagina('professor', caminhos.professorTurma(t.id));
    const detalhe = detalheHtml ? lerDetalheTurma(detalheHtml) : null;
    let aulasDoMes = null;
    const agendaHtml = await lerPagina('professor', caminhos.professorAgenda(t.id));
    const mes = agendaHtml ? lerMesesAgenda(agendaHtml).find((m) => m.ano === agora.getFullYear() && m.mes === agora.getMonth() + 1) : null;
    if (mes) {
      const aulasHtml = await lerPagina('professor', caminhos.professorAulasDoMes(t.id, mes.anoMes, mes.indice), { xhr: true });
      aulasDoMes = aulasHtml ? lerAulasDoMes(aulasHtml, mes) : null;
    }
    completas.push({ turma: t, detalhe, aulasDoMes });
  }
  const p = { nome: lerNomeProfessor(htmlFreq), semestre: turmas[0]?.periodo ?? '', turmas: completas, lidoEm: agoraISO() };
  await gravar('professor', p);
  return p;
}
