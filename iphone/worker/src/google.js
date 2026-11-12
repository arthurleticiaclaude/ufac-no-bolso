// Classroom: o Worker só faz a parte do OAuth que precisa do client secret (trocar o código e renovar).
// Nada é guardado. O refresh token volta cifrado (AES-GCM, SESSAO_CHAVE) e fica só no iPhone, como os
// cookies da Ufac. As leituras do Classroom vão do iPhone direto para o Google, sem passar por aqui.
import { cifrar, decifrar } from './cofre.js';

const TOKEN = 'https://oauth2.googleapis.com/token';
const REVOGAR = 'https://oauth2.googleapis.com/revoke';

/**
 * Só aceita voltar para a raiz de um endereço exato do PWA, em https (sem curingas de prévia).
 * localhost só com GOOGLE_DEV=1 (.dev.vars): em produção, um servidor local qualquer não troca códigos.
 */
export function redirecionamentoPermitido(redirect, env) {
  if (typeof redirect !== 'string') return false;
  return (env.ORIGENS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o && !o.startsWith('*.') && (o.startsWith('https://') || env.GOOGLE_DEV === '1'))
    .some((o) => redirect === `${o}/`);
}

const configurado = (env) => !!env.GOOGLE_CLIENT_ID && !!env.GOOGLE_CLIENT_SECRET;
const naoConfigurado = () => Response.json({ erro: 'nao_configurado' }, { status: 503 });

async function pedirToken(env, campos, fetcher) {
  const r = await fetcher(TOKEN, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: env.GOOGLE_CLIENT_ID, client_secret: env.GOOGLE_CLIENT_SECRET, ...campos }),
  });
  return { ok: r.ok, j: await r.json().catch(() => ({})) };
}

/** POST /google/trocar {code, verifier, redirect} → {access_token, expires_in, cofre} */
export async function trocar(env, c, fetcher = fetch) {
  if (!configurado(env)) return naoConfigurado();
  const textoValido = (v) => typeof v === 'string' && v.length > 0 && v.length < 2048;
  if (!textoValido(c?.code) || !textoValido(c?.verifier) || !redirecionamentoPermitido(c?.redirect, env)) {
    return Response.json({ erro: 'pedido_invalido' }, { status: 400 });
  }
  const { ok, j } = await pedirToken(env, { grant_type: 'authorization_code', code: c.code, code_verifier: c.verifier, redirect_uri: c.redirect }, fetcher);
  if (!ok || !j.access_token || !j.refresh_token) return Response.json({ erro: j.error ?? 'sem_refresh', detalhe: j.error_description ?? null }, { status: 401 });
  return Response.json({ access_token: j.access_token, expires_in: j.expires_in ?? 3600, cofre: await cifrar({ g: j.refresh_token }, env.SESSAO_CHAVE) });
}

/** POST /google/renovar {cofre} → {access_token, expires_in} */
export async function renovar(env, c, fetcher = fetch) {
  if (!configurado(env)) return naoConfigurado();
  const d = await decifrar(c?.cofre, env.SESSAO_CHAVE);
  if (typeof d?.g !== 'string') return Response.json({ erro: 'cofre_invalido' }, { status: 401 });
  const { ok, j } = await pedirToken(env, { grant_type: 'refresh_token', refresh_token: d.g }, fetcher);
  if (!ok || !j.access_token) return Response.json({ erro: j.error ?? 'falhou' }, { status: 401 });
  return Response.json({ access_token: j.access_token, expires_in: j.expires_in ?? 3600 });
}

/** POST /google/desconectar {cofre}: revoga o acesso no Google. ok:false quando o Google não confirmou (o iPhone avisa). */
export async function desconectar(env, c, fetcher = fetch) {
  const d = await decifrar(c?.cofre, env.SESSAO_CHAVE);
  if (typeof d?.g !== 'string') return Response.json({ erro: 'cofre_invalido' }, { status: 400 });
  const r = await fetcher(REVOGAR, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ token: d.g }) }).catch(() => null);
  // 400 do Google = já estava revogado.
  return r && (r.ok || r.status === 400) ? Response.json({ ok: true }) : Response.json({ erro: 'falhou' }, { status: 502 });
}
