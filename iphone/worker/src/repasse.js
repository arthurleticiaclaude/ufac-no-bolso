// Repassa /portal/* e /eticket/* para a Ufac. O Safari não pode ler essas páginas direto (CORS).
// Nada é guardado: a sessão chega cifrada no cabeçalho X-Sessao e volta cifrada no mesmo cabeçalho.
// A senha só aparece no corpo do POST de login e é repassada à Ufac na hora, sem log nem cópia.
import { decifrar, cifrar } from './cofre.js';
import { cabecalhoCookie, guardar, limpar } from './cookies.js';

const DESTINOS = {
  portal: { origem: 'https://portal.ufac.br', prefixo: '' },
  eticket: { origem: 'https://sistemas.ufac.br', prefixo: '/eticket' },
};

const HOSTS_PERMITIDOS = new Set(['portal.ufac.br', 'sistemas.ufac.br']);
const MAX_SALTOS = 10;
const MAX_CORPO = 64 * 1024;
const AGENTE = 'Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1 UFACPlus/1.0';

/** "/portal/aluno/index.action?x=1" vira o endereço real. Null se não for um destino aceito. */
export function destinoDe(url) {
  const m = /^\/(portal|eticket)(\/.*)?$/.exec(url.pathname);
  if (!m) return null;
  const d = DESTINOS[m[1]];
  const caminho = m[2] ?? '/';
  return new URL(d.prefixo + caminho + url.search, d.origem);
}

/** O portal redireciona passando por http://. Volta para https antes de seguir. */
export function proximoSalto(atual, location) {
  if (!location) return null;
  const u = new URL(location, atual);
  if (u.protocol === 'http:' && HOSTS_PERMITIDOS.has(u.hostname)) u.protocol = 'https:';
  if (u.protocol !== 'https:' || !HOSTS_PERMITIDOS.has(u.hostname)) return null;
  if (u.hostname === 'sistemas.ufac.br' && !u.pathname.startsWith('/eticket')) return null;
  return u;
}

/** Tempo total para a Ufac responder (todos os saltos). O app desiste em 25 s. */
const PRAZO_MS = 20000;

/**
 * O eTICKET (12/11/2026): um dos dois IPs do DNS entrega o certificado do portal (falha na hora) e, no outro,
 * cerca de metade das conexões novas nunca recebe resposta, enquanto as boas respondem em ~0,35 s. Por isso cada
 * salto do eTICKET tem prazos curtos até os cabeçalhos e é repetido com conexão nova. A tentativa travada é
 * abortada antes da próxima, então nenhum Set-Cookie de resposta descartada entra no pote.
 * GET: até 9 tentativas, começando curtas (a resposta boa chega em menos de 0,6 s). POST do login: 2 de 6 s (o token CSRF do Django vale para as duas).
 * Outros POSTs não se repetem. Portal: uma tentativa com o prazo inteiro (os PDFs podem demorar).
 */
const TENTATIVAS_GET = [1200, 1200, 1200, 1500, 1500, 2000, 2000, 2500, 3000];
const TENTATIVAS_LOGIN = [6000, 6000];
const MAX_TENTATIVAS = 12; // por pedido do app, somando todos os saltos

function planoDeTentativas(alvo, metodo) {
  if (alvo.hostname !== 'sistemas.ufac.br') return [Infinity];
  if (metodo === 'GET') return TENTATIVAS_GET;
  if (alvo.pathname === '/eticket/login/') return TENTATIVAS_LOGIN;
  return [Infinity];
}

class Esgotado extends Error {}

/** Um salto, com repetição. O prazo vale até chegarem os cabeçalhos; o corpo segue sem ele. */
async function buscarComRepeticao(fetcher, url, init, plano, prazoFinal, contador) {
  for (let i = 0; i < plano.length; i++) {
    const resta = prazoFinal - Date.now();
    if (resta <= 0 || contador.n >= MAX_TENTATIVAS) break;
    contador.n++;
    const t0 = Date.now();
    const controle = new AbortController();
    const relogio = setTimeout(() => controle.abort(), Math.min(plano[i], resta));
    try {
      return await fetcher(url, { ...init, signal: controle.signal });
    } catch (e) {
      contador.log.push(`${controle.signal.aborted ? 'prazo' : String(e?.message ?? e).slice(0, 60)}@${Date.now() - t0}ms`);
      // Sem resposta (travou, TLS errado, conexão recusada): tenta de novo, com uma pausa curta.
      if (i < plano.length - 1) await new Promise((ok) => setTimeout(ok, 150));
    } finally {
      clearTimeout(relogio);
    }
  }
  throw new Esgotado();
}

export async function repassar(pedido, env, fetcher = fetch) {
  const urlPedido = new URL(pedido.url);
  let alvo = destinoDe(urlPedido);
  if (!alvo) return new Response('Destino não permitido', { status: 404 });
  if (!['GET', 'POST'].includes(pedido.method)) return new Response('Método não permitido', { status: 405 });

  let corpo = null;
  if (pedido.method === 'POST') {
    corpo = await pedido.arrayBuffer();
    if (corpo.byteLength > MAX_CORPO) return new Response('Pedido grande demais', { status: 413 });
  }

  let pote = (await decifrar(pedido.headers.get('X-Sessao'), env.SESSAO_CHAVE)) ?? [];
  let metodo = pedido.method;
  let resposta;
  const prazoFinal = Date.now() + PRAZO_MS;
  const contador = { n: 0, log: [] };
  for (let salto = 0; ; salto++) {
    const cabecalhos = new Headers({
      'User-Agent': AGENTE,
      Accept: pedido.headers.get('Accept') ?? 'text/html,application/xhtml+xml,application/pdf;q=0.9,*/*;q=0.8',
      'Accept-Language': 'pt-BR,pt;q=0.9',
    });
    const cookie = cabecalhoCookie(pote, alvo);
    if (cookie) cabecalhos.set('Cookie', cookie);
    if (metodo === 'POST') {
      cabecalhos.set('Content-Type', pedido.headers.get('Content-Type') ?? 'application/x-www-form-urlencoded');
      // O Django do eTICKET confere a origem do formulário (CSRF).
      cabecalhos.set('Origin', alvo.origin);
      cabecalhos.set('Referer', alvo.toString());
    }
    if (pedido.headers.get('X-Requested-With')) cabecalhos.set('X-Requested-With', 'XMLHttpRequest');

    try {
      resposta = await buscarComRepeticao(
        fetcher,
        alvo.toString(),
        { method: metodo, headers: cabecalhos, body: metodo === 'POST' ? corpo : undefined, redirect: 'manual' },
        planoDeTentativas(alvo, metodo),
        prazoFinal,
        contador,
      );
    } catch {
      return new Response('A Ufac não respondeu a tempo', { status: 504, headers: { 'Cache-Control': 'no-store', 'X-Tentativas': contador.log.join(' | ') } });
    }
    pote = guardar(pote, resposta.headers.getSetCookie?.() ?? [], alvo);

    const proximo = resposta.status >= 300 && resposta.status < 400 ? proximoSalto(alvo, resposta.headers.get('Location')) : null;
    if (!proximo || salto >= MAX_SALTOS) break;
    if (resposta.status !== 307 && resposta.status !== 308) {
      metodo = 'GET';
      corpo = null;
    }
    alvo = proximo;
  }

  const saida = new Headers({
    'Content-Type': resposta.headers.get('Content-Type') ?? 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Sessao': await cifrar(limpar(pote), env.SESSAO_CHAVE),
    'X-Url-Final': alvo.toString(),
    'X-Tentativas': [...contador.log, 'ok'].join(' | '),
  });
  const disposicao = resposta.headers.get('Content-Disposition');
  if (disposicao) saida.set('Content-Disposition', disposicao);
  return new Response(resposta.body, { status: resposta.status, headers: saida });
}
