// Pote de cookies mínimo (RFC 6265 no essencial): domínio, caminho e validade.
// O portal tem dois JSESSIONID com caminhos diferentes (/aluno/ e /professor/), por isso o caminho conta.

/** Cookie = { n: nome, v: valor, d: domínio, h: só este host?, p: caminho, e: expira (ms) ou null } */

function caminhoPadrao(url) {
  const p = url.pathname;
  const i = p.lastIndexOf('/');
  return i <= 0 ? '/' : p.slice(0, i);
}

export function lerSetCookie(linha, url, agora = Date.now()) {
  const [par, ...atributos] = linha.split(';');
  const igual = par.indexOf('=');
  if (igual <= 0) return null;
  const c = { n: par.slice(0, igual).trim(), v: par.slice(igual + 1).trim(), d: url.hostname, h: true, p: caminhoPadrao(url), e: null };
  for (const a of atributos) {
    const [k, ...resto] = a.split('=');
    const chave = k.trim().toLowerCase();
    const valor = resto.join('=').trim();
    if (chave === 'domain' && valor) {
      const d = valor.replace(/^\./, '').toLowerCase();
      // Só aceita domínio que contenha o host atual (nunca outro site).
      if (url.hostname !== d && !url.hostname.endsWith(`.${d}`)) return null;
      c.d = d;
      c.h = false;
    } else if (chave === 'path' && valor.startsWith('/')) {
      c.p = valor;
    } else if (chave === 'max-age') {
      const s = Number(valor);
      if (Number.isFinite(s)) c.e = agora + s * 1000;
    } else if (chave === 'expires' && c.e === null) {
      const t = Date.parse(valor);
      if (Number.isFinite(t)) c.e = t;
    }
  }
  return c;
}

/** Guarda (ou apaga, se já expirou) os cookies de uma resposta. Devolve o pote novo. */
export function guardar(pote, linhas, url, agora = Date.now()) {
  let novo = [...pote];
  for (const linha of linhas) {
    const c = lerSetCookie(linha, url, agora);
    if (!c) continue;
    novo = novo.filter((x) => !(x.n === c.n && x.d === c.d && x.p === c.p));
    if (c.e === null || c.e > agora) novo.push(c);
  }
  return novo;
}

const dominioCasa = (c, host) => (c.h ? host === c.d : host === c.d || host.endsWith(`.${c.d}`));

function caminhoCasa(c, caminho) {
  if (caminho === c.p) return true;
  if (!caminho.startsWith(c.p)) return false;
  return c.p.endsWith('/') || caminho[c.p.length] === '/';
}

/** O cabeçalho Cookie para um endereço. Caminho mais longo primeiro, como os navegadores. */
export function cabecalhoCookie(pote, url, agora = Date.now()) {
  return pote
    .filter((c) => (c.e === null || c.e > agora) && dominioCasa(c, url.hostname) && caminhoCasa(c, url.pathname))
    .sort((a, b) => b.p.length - a.p.length)
    .map((c) => `${c.n}=${c.v}`)
    .join('; ');
}

/** Tira os vencidos antes de cifrar, para o pote não crescer à toa. */
export const limpar = (pote, agora = Date.now()) => pote.filter((c) => c.e === null || c.e > agora);
