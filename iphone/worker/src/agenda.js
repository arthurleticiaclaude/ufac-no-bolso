// Notificações no lugar das Live Activities. O KV guarda só a inscrição de push e os horários:
// nenhum nome de disciplina, cardápio ou atividade. O push leva só o tipo e uma referência,
// e o próprio iPhone monta o texto com os dados que já tem.
import { enviarPush } from './webpush.js';

const MINUTOS_SEMANA = 7 * 24 * 60;
const JANELA_MIN = 5; // o Cron roda a cada 5 minutos
const VALIDADE_S = 60 * 24 * 3600; // inscrição abandonada some em 60 dias
const TIPOS = new Set(['aula', 'refeicao', 'classroom']);
const MAX_EVENTOS = 200;

export async function chaveDe(endpoint) {
  const h = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(endpoint)));
  return `i:${[...h].map((b) => b.toString(16).padStart(2, '0')).join('')}`;
}

const referenciaValida = (r) => typeof r === 'string' && r.length <= 64 && /^[\w:.-]*$/.test(r);

/** Aceita só o formato esperado: nada de texto livre vindo do iPhone. */
export function validarAgenda(a) {
  const semanais = (Array.isArray(a?.semanais) ? a.semanais : [])
    .filter((e) => Number.isInteger(e?.m) && e.m >= 0 && e.m < MINUTOS_SEMANA && TIPOS.has(e.t) && referenciaValida(e.r))
    .map(({ m, t, r }) => ({ m, t, r }));
  const unicos = (Array.isArray(a?.unicos) ? a.unicos : [])
    .filter((e) => Number.isInteger(e?.em) && TIPOS.has(e.t) && referenciaValida(e.r))
    .map(({ em, t, r }) => ({ em, t, r }));
  return { semanais: semanais.slice(0, MAX_EVENTOS), unicos: unicos.slice(0, MAX_EVENTOS) };
}

export function validarInscricao(i) {
  const ok =
    typeof i?.endpoint === 'string' &&
    i.endpoint.startsWith('https://') &&
    i.endpoint.length < 1024 &&
    typeof i.keys?.p256dh === 'string' &&
    typeof i.keys?.auth === 'string';
  return ok ? { endpoint: i.endpoint, keys: { p256dh: i.keys.p256dh, auth: i.keys.auth } } : null;
}

/** Minuto da semana em UTC, com domingo 00:00 = 0. */
export const minutoDaSemana = (ms) => Math.floor(ms / 60000 + 4 * 24 * 60) % MINUTOS_SEMANA; // 1/1/1970 foi quinta

/** Eventos que caem na janela (fim - 5 min, fim]. */
export function eventosNaJanela(agenda, fimMs) {
  const fimMin = Math.floor(fimMs / 60000);
  const achados = [];
  for (const e of agenda.unicos) if (e.em > fimMin - JANELA_MIN && e.em <= fimMin) achados.push(e);
  const semanaFim = minutoDaSemana(fimMs);
  for (const e of agenda.semanais) {
    const distancia = (semanaFim - e.m + MINUTOS_SEMANA) % MINUTOS_SEMANA;
    if (distancia < JANELA_MIN) achados.push(e);
  }
  return achados;
}

export async function inscrever(env, corpo) {
  const inscricao = validarInscricao(corpo?.inscricao);
  if (!inscricao) return new Response('Inscrição inválida', { status: 400 });
  const agenda = validarAgenda(corpo?.agenda);
  await env.INSCRICOES.put(await chaveDe(inscricao.endpoint), JSON.stringify({ inscricao, agenda }), { expirationTtl: VALIDADE_S });
  return Response.json({ ok: true, eventos: agenda.semanais.length + agenda.unicos.length });
}

export async function cancelar(env, corpo) {
  if (typeof corpo?.endpoint !== 'string') return new Response('Inscrição inválida', { status: 400 });
  await env.INSCRICOES.delete(await chaveDe(corpo.endpoint));
  return Response.json({ ok: true });
}

/** Roda no Cron Trigger. */
export async function dispararAgendados(env, fimMs, fetcher = fetch) {
  const vapid = { publica: env.VAPID_PUBLICA, privada: env.VAPID_PRIVADA, assunto: env.VAPID_ASSUNTO };
  let cursor;
  let enviados = 0;
  do {
    const lista = await env.INSCRICOES.list({ prefix: 'i:', cursor });
    for (const { name } of lista.keys) {
      const registro = await env.INSCRICOES.get(name, 'json');
      if (!registro) continue;
      for (const e of eventosNaJanela(registro.agenda, fimMs)) {
        const status = await enviarPush(registro.inscricao, { t: e.t, r: e.r }, vapid, fetcher);
        if (status === 404 || status === 410) {
          await env.INSCRICOES.delete(name);
          break;
        }
        if (status < 300) enviados++;
      }
    }
    cursor = lista.list_complete ? undefined : lista.cursor;
  } while (cursor);
  return enviados;
}
