import { createECDH } from 'node:crypto';
import ece from 'http_ece';
import { describe, expect, test, vi } from 'vitest';
import { cifrar, decifrar } from '../src/cofre.js';
import { cabecalhoCookie, guardar } from '../src/cookies.js';
import { destinoDe, proximoSalto, repassar } from '../src/repasse.js';
import { assinaturaVapid, cifrarMensagem } from '../src/webpush.js';
import { eventosNaJanela, minutoDaSemana, validarAgenda, dispararAgendados, inscrever, chaveDe } from '../src/agenda.js';
import worker, { origemPermitida } from '../src/index.js';
import { deBase64Url, paraBase64Url } from '../src/base64.js';
import { desconectar, redirecionamentoPermitido, renovar, trocar } from '../src/google.js';

const CHAVE = paraBase64Url(crypto.getRandomValues(new Uint8Array(32)));

describe('cofre', () => {
  test('ida e volta; texto alterado vira null', async () => {
    const t = await cifrar([{ n: 'a', v: '1' }], CHAVE);
    expect(await decifrar(t, CHAVE)).toEqual([{ n: 'a', v: '1' }]);
    expect(await decifrar(t.slice(0, -2) + 'AA', CHAVE)).toBeNull();
    expect(await decifrar(t, paraBase64Url(crypto.getRandomValues(new Uint8Array(32))))).toBeNull();
    expect(await decifrar('', CHAVE)).toBeNull();
  });
});

describe('cookies', () => {
  const portal = new URL('https://portal.ufac.br/aluno/login.action');
  test('caminho separa o JSESSIONID do aluno e do professor', () => {
    let pote = guardar([], ['JSESSIONID=ALUNO; Path=/aluno/; HttpOnly', 'JSESSIONIDSSO=SSO; Path=/'], portal);
    pote = guardar(pote, ['JSESSIONID=PROF; Path=/professor/'], new URL('https://portal.ufac.br/professor/index.action'));
    expect(cabecalhoCookie(pote, new URL('https://portal.ufac.br/aluno/index.action'))).toBe('JSESSIONID=ALUNO; JSESSIONIDSSO=SSO');
    expect(cabecalhoCookie(pote, new URL('https://portal.ufac.br/professor/x.action'))).toBe('JSESSIONID=PROF; JSESSIONIDSSO=SSO');
    expect(cabecalhoCookie(pote, new URL('https://sistemas.ufac.br/eticket/'))).toBe('');
  });
  test('Max-Age=0 apaga; domínio de outro site é recusado', () => {
    let pote = guardar([], ['sessionid=1; Path=/'], new URL('https://sistemas.ufac.br/eticket/'));
    pote = guardar(pote, ['sessionid=; Max-Age=0; Path=/'], new URL('https://sistemas.ufac.br/eticket/logout/'));
    expect(pote).toEqual([]);
    expect(guardar([], ['x=1; Domain=evil.com'], portal)).toEqual([]);
  });
});

describe('repasse', () => {
  test('só destinos da Ufac', () => {
    expect(destinoDe(new URL('https://w.dev/portal/aluno/index.action?a=1')).toString()).toBe('https://portal.ufac.br/aluno/index.action?a=1');
    expect(destinoDe(new URL('https://w.dev/eticket/menu/')).toString()).toBe('https://sistemas.ufac.br/eticket/menu/');
    expect(destinoDe(new URL('https://w.dev/outra'))).toBeNull();
    expect(proximoSalto(new URL('https://portal.ufac.br/aluno/'), 'http://portal.ufac.br/aluno/index.action').toString()).toBe('https://portal.ufac.br/aluno/index.action');
    expect(proximoSalto(new URL('https://portal.ufac.br/aluno/'), 'https://evil.com/')).toBeNull();
    expect(proximoSalto(new URL('https://sistemas.ufac.br/eticket/'), '/admin/')).toBeNull();
  });

  test('login do portal: segue os saltos por http, guarda cookies e devolve a sessão cifrada', async () => {
    const vistos = [];
    const fetcher = vi.fn(async (url, init) => {
      vistos.push({ url, metodo: init.method, cookie: init.headers.get('Cookie'), corpo: init.body ? new TextDecoder().decode(init.body) : null });
      if (url.endsWith('/j_security_check')) {
        return new Response('', { status: 302, headers: [['Location', 'http://portal.ufac.br/aluno/index.action'], ['Set-Cookie', 'JSESSIONIDSSO=SSO1; Path=/']] });
      }
      return new Response('<input id="matricula" value="11111">', { status: 200, headers: { 'Content-Type': 'text/html' } });
    });
    const env = { SESSAO_CHAVE: CHAVE };
    const sessaoInicial = await cifrar([{ n: 'JSESSIONID', v: 'A1', d: 'portal.ufac.br', h: true, p: '/aluno/', e: null }], CHAVE);
    const r = await repassar(
      new Request('https://w.dev/portal/aluno/j_security_check', {
        method: 'POST',
        headers: { 'X-Sessao': sessaoInicial, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'j_username=00000000000&j_password=teste',
      }),
      env,
      fetcher,
    );
    expect(r.status).toBe(200);
    expect(r.headers.get('X-Url-Final')).toBe('https://portal.ufac.br/aluno/index.action');
    expect(vistos[0]).toMatchObject({ metodo: 'POST', cookie: 'JSESSIONID=A1', corpo: 'j_username=00000000000&j_password=teste' });
    expect(vistos[1]).toMatchObject({ url: 'https://portal.ufac.br/aluno/index.action', metodo: 'GET', cookie: 'JSESSIONID=A1; JSESSIONIDSSO=SSO1', corpo: null });
    const pote = await decifrar(r.headers.get('X-Sessao'), CHAVE);
    expect(pote.map((c) => c.n).sort()).toEqual(['JSESSIONID', 'JSESSIONIDSSO']);
    expect(await r.text()).toContain('11111');
  });

  test('POST do eTICKET leva Origin e Referer da própria Ufac (CSRF do Django)', async () => {
    let cabecalhos;
    const fetcher = async (url, init) => {
      cabecalhos = init.headers;
      return new Response('ok');
    };
    await repassar(new Request('https://w.dev/eticket/login/', { method: 'POST', body: 'cpf=1' }), { SESSAO_CHAVE: CHAVE }, fetcher);
    expect(cabecalhos.get('Origin')).toBe('https://sistemas.ufac.br');
    expect(cabecalhos.get('Referer')).toBe('https://sistemas.ufac.br/eticket/login/');
  });

  test('CORS só para as origens do PWA', async () => {
    const env = { ORIGENS: 'https://ufac-plus-ios.pages.dev,*.ufac-plus-ios.pages.dev,http://localhost:5173' };
    expect(origemPermitida('https://ufac-plus-ios.pages.dev', env)).toBe(true);
    expect(origemPermitida('https://ios-pwa.ufac-plus-ios.pages.dev', env)).toBe(true);
    expect(origemPermitida('http://localhost:5173', env)).toBe(true);
    expect(origemPermitida('https://evil.dev', env)).toBe(false);
    expect(origemPermitida(null, env)).toBe(false);
    const r = await worker.fetch(new Request('https://w.dev/portal/aluno/', { headers: { Origin: 'https://evil.dev' } }), env);
    expect(r.status).toBe(403);
  });
});

describe('web push', () => {
  test('a mensagem cifrada abre com as chaves do iPhone (RFC 8291)', async () => {
    const iphone = createECDH('prime256v1');
    iphone.generateKeys();
    const auth = crypto.getRandomValues(new Uint8Array(16));
    const inscricao = { endpoint: 'https://web.push.apple.com/abc', keys: { p256dh: paraBase64Url(iphone.getPublicKey()), auth: paraBase64Url(auth) } };
    const corpo = await cifrarMensagem(inscricao, '{"t":"aula","r":"x"}');
    const claro = ece.decrypt(Buffer.from(corpo), { version: 'aes128gcm', privateKey: iphone, authSecret: paraBase64Url(auth) });
    expect(claro.toString()).toBe('{"t":"aula","r":"x"}');
  });

  test('VAPID: JWT ES256 válido para a origem do serviço de push', async () => {
    const par = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
    const publica = paraBase64Url(await crypto.subtle.exportKey('raw', par.publicKey));
    const privada = (await crypto.subtle.exportKey('jwk', par.privateKey)).d;
    const h = await assinaturaVapid('https://web.push.apple.com/abc', { publica, privada, assunto: 'https://ufac-plus-ios.pages.dev' }, 0);
    const [, jwt, k] = /^vapid t=([^,]+), k=(.+)$/.exec(h);
    expect(k).toBe(publica);
    const [c, p, s] = jwt.split('.');
    expect(JSON.parse(new TextDecoder().decode(deBase64Url(p)))).toMatchObject({ aud: 'https://web.push.apple.com', exp: 12 * 3600 });
    const ok = await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, par.publicKey, deBase64Url(s), new TextEncoder().encode(`${c}.${p}`));
    expect(ok).toBe(true);
  });
});

describe('agenda', () => {
  test('minuto da semana em UTC (domingo 00:00 = 0)', () => {
    expect(minutoDaSemana(Date.UTC(2026, 10, 8, 0, 0))).toBe(0); // domingo
    expect(minutoDaSemana(Date.UTC(2026, 10, 9, 23, 45))).toBe(24 * 60 + 23 * 60 + 45);
  });
  test('janela de 5 minutos, inclusive o fim', () => {
    const fim = Date.UTC(2026, 10, 9, 23, 45);
    const m = minutoDaSemana(fim);
    const agenda = {
      semanais: [{ m, t: 'aula', r: 'a' }, { m: m - 4, t: 'aula', r: 'b' }, { m: m - 5, t: 'aula', r: 'c' }, { m: m + 1, t: 'aula', r: 'd' }],
      unicos: [{ em: fim / 60000, t: 'classroom', r: '2026-11-09' }, { em: fim / 60000 - 10, t: 'classroom', r: 'velho' }],
    };
    expect(eventosNaJanela(agenda, fim).map((e) => e.r).sort()).toEqual(['2026-11-09', 'a', 'b']);
  });
  test('domingo 00:01 pega o sábado 23:58', () => {
    const fim = Date.UTC(2026, 10, 8, 0, 1);
    expect(eventosNaJanela({ semanais: [{ m: 7 * 1440 - 2, t: 'refeicao', r: 'cafe' }], unicos: [] }, fim)).toHaveLength(1);
  });
  test('validar descarta texto livre e tipos estranhos', () => {
    const a = validarAgenda({ semanais: [{ m: 10, t: 'aula', r: 'Direito Civil VII' }, { m: 10, t: 'hack', r: 'x' }, { m: 20, t: 'aula', r: 'a1', extra: 'nome' }], unicos: 'x' });
    expect(a).toEqual({ semanais: [{ m: 20, t: 'aula', r: 'a1' }], unicos: [] });
  });
  test('cron envia o push e apaga inscrição morta', async () => {
    const kv = new Map();
    const env = {
      INSCRICOES: {
        put: async (k, v) => kv.set(k, v),
        get: async (k) => JSON.parse(kv.get(k) ?? 'null'),
        delete: async (k) => kv.delete(k),
        list: async () => ({ keys: [...kv.keys()].map((name) => ({ name })), list_complete: true }),
      },
    };
    const iphone = createECDH('prime256v1');
    iphone.generateKeys();
    const inscricao = { endpoint: 'https://web.push.apple.com/abc', keys: { p256dh: paraBase64Url(iphone.getPublicKey()), auth: paraBase64Url(new Uint8Array(16)) } };
    const fim = Date.UTC(2026, 10, 9, 23, 45);
    await inscrever(env, { inscricao, agenda: { semanais: [{ m: minutoDaSemana(fim), t: 'aula', r: 'a' }] } });
    const par = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign']);
    env.VAPID_PUBLICA = paraBase64Url(await crypto.subtle.exportKey('raw', par.publicKey));
    env.VAPID_PRIVADA = (await crypto.subtle.exportKey('jwk', par.privateKey)).d;
    env.VAPID_ASSUNTO = 'https://x.dev';
    const envios = [];
    expect(await dispararAgendados(env, fim, async (url, init) => (envios.push(init), new Response('', { status: 201 })))).toBe(1);
    expect(envios[0].headers['Content-Encoding']).toBe('aes128gcm');
    expect(await dispararAgendados(env, fim, async () => new Response('', { status: 410 }))).toBe(0);
    expect(kv.has(await chaveDe(inscricao.endpoint))).toBe(false);
  });
});

describe('google (Classroom)', () => {
  const env = { ORIGENS: 'https://ufac-plus-ios.pages.dev,*.ufac-plus-ios.pages.dev', SESSAO_CHAVE: CHAVE, GOOGLE_CLIENT_ID: 'id', GOOGLE_CLIENT_SECRET: 'segredo' };
  const googleFalso = (resposta, ok = true) => vi.fn(async () => new Response(JSON.stringify(resposta), { status: ok ? 200 : 400 }));

  test('só volta para a raiz exata do PWA', () => {
    expect(redirecionamentoPermitido('https://ufac-plus-ios.pages.dev/', env)).toBe(true);
    expect(redirecionamentoPermitido('https://x.ufac-plus-ios.pages.dev/', env)).toBe(false);
    expect(redirecionamentoPermitido('https://malicioso.com/', env)).toBe(false);
    const comLocal = { ...env, ORIGENS: `${env.ORIGENS},http://localhost:5173` };
    expect(redirecionamentoPermitido('http://localhost:5173/', comLocal)).toBe(false);
    expect(redirecionamentoPermitido('http://localhost:5173/', { ...comLocal, GOOGLE_DEV: '1' })).toBe(true);
  });

  test('troca o código, cifra o refresh token e renova', async () => {
    const f = googleFalso({ access_token: 'A1', expires_in: 3599, refresh_token: 'R1' });
    const r = await trocar(env, { code: 'c', verifier: 'v', redirect: 'https://ufac-plus-ios.pages.dev/' }, f);
    const j = await r.json();
    expect(j.access_token).toBe('A1');
    expect(j.cofre).not.toContain('R1');
    const corpo = new URLSearchParams(f.mock.calls[0][1].body);
    expect(corpo.get('client_secret')).toBe('segredo');
    expect(corpo.get('code_verifier')).toBe('v');
    const g = googleFalso({ access_token: 'A2', expires_in: 3599 });
    const r2 = await (await renovar(env, { cofre: j.cofre }, g)).json();
    expect(r2.access_token).toBe('A2');
    expect(new URLSearchParams(g.mock.calls[0][1].body).get('refresh_token')).toBe('R1');
    const rev = vi.fn(async () => new Response('{}'));
    await desconectar(env, { cofre: j.cofre }, rev);
    expect(new URLSearchParams(rev.mock.calls[0][1].body).get('token')).toBe('R1');
  });

  test('cofre alterado ou sem configuração não chega ao Google', async () => {
    const f = googleFalso({});
    expect((await renovar(env, { cofre: 'lixo' }, f)).status).toBe(401);
    expect((await trocar({ ...env, GOOGLE_CLIENT_SECRET: '' }, {}, f)).status).toBe(503);
    expect((await trocar(env, { code: 'c', verifier: 'v', redirect: 'https://malicioso.com/' }, f)).status).toBe(400);
    expect(f).not.toHaveBeenCalled();
  });
});

describe('repetição no eTICKET (servidor que às vezes não responde)', () => {
  const env = { SESSAO_CHAVE: CHAVE };
  // Fica pendurado até o Worker abortar, como as conexões ruins do eTICKET.
  const pendurado = (init) => new Promise((_, falha) => init.signal.addEventListener('abort', () => falha(new Error('abortado'))));

  test('falha de conexão (certificado errado) é repetida e a resposta boa chega', async () => {
    let n = 0;
    const fetcher = async () => {
      n++;
      if (n < 3) throw new Error('TLS');
      return new Response('saldo', { headers: { 'Set-Cookie': 'sessionid=boa; Path=/' } });
    };
    const r = await repassar(new Request('https://w.dev/eticket/'), env, fetcher);
    expect(r.status).toBe(200);
    expect(await r.text()).toBe('saldo');
    expect(n).toBe(3);
  });

  test('conexão pendurada é abortada em pouco mais de 1 s e repetida', async () => {
    let n = 0;
    const fetcher = (url, init) => (++n === 1 ? pendurado(init) : Promise.resolve(new Response('ok')));
    const comeco = Date.now();
    const r = await repassar(new Request('https://w.dev/eticket/menu/'), env, fetcher);
    expect(r.status).toBe(200);
    expect(n).toBe(2);
    expect(Date.now() - comeco).toBeLessThan(2000);
  }, 10000);

  test('login (POST) tenta no máximo 2 vezes e devolve 504', async () => {
    let n = 0;
    const fetcher = async () => {
      n++;
      throw new Error('TLS');
    };
    const r = await repassar(new Request('https://w.dev/eticket/login/', { method: 'POST', body: 'cpf=1' }), env, fetcher);
    expect(r.status).toBe(504);
    expect(n).toBe(2);
  });

  test('o Portal não é repetido', async () => {
    let n = 0;
    const fetcher = async () => {
      n++;
      throw new Error('rede');
    };
    const r = await repassar(new Request('https://w.dev/portal/aluno/index.action'), env, fetcher);
    expect(r.status).toBe(504);
    expect(n).toBe(1);
  });
});
