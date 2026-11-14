// UFAC+ para iPhone: Worker sem armazenamento de dados pessoais e sem logs.
// Rotas: /portal/* e /eticket/* (repasse), /push/* (inscrição de notificações).
// Classroom: /google/* só troca e renova a autorização (ver src/google.js); o conteúdo vai do Google direto ao iPhone.
import { cancelar, dispararAgendados, inscrever } from './agenda.js';
import { desconectar, renovar, trocar } from './google.js';
import { repassar } from './repasse.js';

/** ORIGENS="https://ufac-plus.pages.dev,*.ufac-plus.pages.dev,http://localhost:5173" */
export function origemPermitida(origem, env) {
  if (!origem) return false;
  let host;
  try {
    host = new URL(origem);
  } catch {
    return false;
  }
  return (env.ORIGENS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean)
    .some((o) => (o.startsWith('*.') ? host.protocol === 'https:' && host.hostname.endsWith(o.slice(1)) : o === origem));
}

function comCors(resposta, origem) {
  const r = new Response(resposta.body, resposta);
  r.headers.set('Access-Control-Allow-Origin', origem);
  r.headers.set('Access-Control-Expose-Headers', 'X-Sessao, X-Url-Final, Content-Disposition, X-Tentativas');
  r.headers.set('Vary', 'Origin');
  return r;
}

async function lerJson(pedido) {
  try {
    return await pedido.json();
  } catch {
    return null;
  }
}

export default {
  async fetch(pedido, env) {
    const url = new URL(pedido.url);
    const origem = pedido.headers.get('Origin');
    if (!origemPermitida(origem, env)) return new Response('Origem não permitida', { status: 403 });

    if (pedido.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': origem,
          'Access-Control-Allow-Methods': 'GET, POST',
          'Access-Control-Allow-Headers': 'Content-Type, X-Sessao, X-Requested-With',
          'Access-Control-Max-Age': '86400',
          Vary: 'Origin',
        },
      });
    }

    let resposta;
    if (url.pathname === '/push/chave') {
      resposta = Response.json({ chave: env.VAPID_PUBLICA });
    } else if (url.pathname === '/push/inscrever' && pedido.method === 'POST') {
      resposta = await inscrever(env, await lerJson(pedido));
    } else if (url.pathname === '/push/cancelar' && pedido.method === 'POST') {
      resposta = await cancelar(env, await lerJson(pedido));
    } else if (url.pathname === '/google/trocar' && pedido.method === 'POST') {
      resposta = await trocar(env, await lerJson(pedido));
    } else if (url.pathname === '/google/renovar' && pedido.method === 'POST') {
      resposta = await renovar(env, await lerJson(pedido));
    } else if (url.pathname === '/google/desconectar' && pedido.method === 'POST') {
      resposta = await desconectar(env, await lerJson(pedido));
    } else {
      resposta = await repassar(pedido, env);
    }
    return comCors(resposta, origem);
  },

  async scheduled(evento, env, ctx) {
    ctx.waitUntil(dispararAgendados(env, evento.scheduledTime));
  },
};
