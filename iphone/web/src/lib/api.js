// Cliente do Worker. A sessão da Ufac é um texto cifrado que só o Worker abre; aqui ela só é guardada.
import { apagar, gravar, ler } from './armazenamento.js';
import { caminhos, WORKER_URL } from './config.js';
import { classificar } from './regras.js';
import { registrar, semParametros } from './registro.js';

export class SemConexao extends Error {}

/**
 * Sinal que desiste depois de `ms`. Sem isso, um servidor que não responde (o eTICKET às vezes não atende a
 * Cloudflare) deixa a roda de "atualizar" girando para sempre. Vale também para a leitura do corpo.
 */
export function comLimite(ms) {
  const controle = new AbortController();
  setTimeout(() => controle.abort(new DOMException('Tempo esgotado', 'TimeoutError')), ms);
  return controle.signal;
}

export const LIMITE_PADRAO = 25000;

/**
 * Pede uma página da Ufac. sistema: 'portal' | 'professor' | 'eticket'.
 * Devolve { status, estado: 'logado'|'naLogin'|'outra', urlFinal, resposta }.
 */
export async function pedir(sistema, caminho, { metodo = 'GET', formulario, xhr = false, accept, limite = LIMITE_PADRAO } = {}) {
  const raiz = sistema === 'eticket' ? 'eticket' : 'portal';
  const cabecalhos = {};
  const sessao = await ler('sessao');
  if (sessao) cabecalhos['X-Sessao'] = sessao;
  if (xhr) cabecalhos['X-Requested-With'] = 'XMLHttpRequest';
  if (accept) cabecalhos.Accept = accept;
  let corpo;
  if (formulario) {
    cabecalhos['Content-Type'] = 'application/x-www-form-urlencoded';
    corpo = new URLSearchParams(formulario).toString();
  }
  let resposta;
  const t0 = Date.now();
  try {
    resposta = await fetch(`${WORKER_URL}/${raiz}${caminho}`, { method: metodo, headers: cabecalhos, body: corpo, cache: 'no-store', signal: comLimite(limite) });
  } catch (e) {
    registrar('rede', { sistema, metodo, caminho: semParametros(caminho), erro: e?.name === 'TimeoutError' || e?.name === 'AbortError' ? 'tempo esgotado no app' : 'sem conexão com o Worker', online: navigator.onLine, ms: Date.now() - t0 });
    throw new SemConexao('Sem conexão');
  }
  // 504: o Worker desistiu de esperar a Ufac.
  if (resposta.status === 504 || resposta.status === 502) {
    registrar('rede', { sistema, metodo, caminho: semParametros(caminho), status: resposta.status, tentativas: resposta.headers.get('X-Tentativas') ?? '', ms: Date.now() - t0 });
    throw new SemConexao(`A Ufac não respondeu (${resposta.status})`);
  }
  const nova = resposta.headers.get('X-Sessao');
  if (nova) await gravar('sessao', nova);
  const urlFinal = resposta.headers.get('X-Url-Final') ?? '';
  return { status: resposta.status, estado: classificar(sistema, urlFinal), urlFinal, resposta };
}

/** Lê o HTML de uma página logada. Null quando a sessão caiu (e marca o sistema como expirado). */
/** Endereço final (depois dos redirecionamentos) da última página lida: usado só no diagnóstico. */
let ultimoEndereco = '';
export const enderecoDaUltimaPagina = () => ultimoEndereco;

// Login automático (sessao.js registra). Fica aqui como gancho para não criar import circular.
let reentrada = null;
export const definirReentrada = (fn) => (reentrada = fn);
/** true se a sessão foi refeita sozinha (chave "Entrar sozinho" e senha guardada). */
export const tentarReentrar = async (sistema) => (reentrada ? reentrada(sistema) : false);

export async function lerPagina(sistema, caminho, opcoes, jaReentrou = false) {
  const r = await pedir(sistema, caminho, opcoes);
  ultimoEndereco = r.urlFinal;
  // Sessão caída: tenta entrar sozinho uma vez e pede a página de novo; senão, marca como encerrada.
  const caiu = async () => {
    if (!jaReentrou && (await tentarReentrar(sistema))) return lerPagina(sistema, caminho, opcoes, true);
    await marcarExpirado(sistema, true);
    return null;
  };
  if (r.estado === 'trocarSenha') {
    // Sem senha nova o Portal não abre nada: trata como sessão encerrada, com a faixa de trocar a senha.
    registrar('sessao', { sistema, caminho: semParametros(caminho), foiPara: semParametros(r.urlFinal), detalhe: 'Portal pede senha nova' });
    await gravar('portalPedeSenha', true);
    await apagar('diagnosticoPortal');
    await marcarExpirado(sistema, true);
    return null;
  }
  if (r.estado === 'naLogin') {
    registrar('sessao', { sistema, caminho: semParametros(caminho), foiPara: semParametros(r.urlFinal) });
    return caiu();
  }
  if (r.status >= 400) {
    registrar('rede', { sistema, caminho: semParametros(caminho), status: r.status, foiPara: semParametros(r.urlFinal) });
    // O Tomcat do Portal costuma responder 4xx (não o login) a pedidos de sessão vencida: confere antes de dizer "sem conexão".
    if (sistema !== 'eticket' && r.status < 500 && (await sessaoCaiu(sistema))) return caiu();
    throw new SemConexao(`A Ufac respondeu ${r.status}`);
  }
  let texto;
  try {
    texto = await r.resposta.text();
  } catch {
    registrar('rede', { sistema, caminho: semParametros(caminho), erro: 'a página parou no meio' });
    throw new SemConexao('A página parou no meio');
  }
  // Às vezes o Portal entrega o formulário de login com 200 no próprio endereço pedido.
  if (sistema !== 'eticket' && /j_security_check|name="j_password"/.test(texto)) {
    registrar('sessao', { sistema, caminho: semParametros(caminho), detalhe: 'formulário de login com 200' });
    return caiu();
  }
  if (sistema !== 'eticket') await apagar('portalPedeSenha');
  await marcarExpirado(sistema, false);
  return texto;
}

/** Uma sonda só (compartilhada por pedidos simultâneos, válida por 1 min): a página inicial cai no login? */
let sonda;
function sessaoCaiu(sistema) {
  sonda ??= pedir(sistema, sistema === 'professor' ? caminhos.professorInicio : caminhos.portalInicio)
    .then((r) => r.estado === 'naLogin', () => false)
    .finally(() => setTimeout(() => (sonda = null), 60000));
  return sonda;
}

const ouvintes = new Set();
export const aoMudarSessao = (fn) => (ouvintes.add(fn), () => ouvintes.delete(fn));

export async function marcarExpirado(sistema, expirado) {
  const atual = new Set((await ler('expirados')) ?? []);
  const antes = atual.has(sistema);
  if (expirado) atual.add(sistema);
  else atual.delete(sistema);
  if (antes !== expirado) {
    await gravar('expirados', [...atual]);
    ouvintes.forEach((fn) => fn([...atual]));
  }
}
