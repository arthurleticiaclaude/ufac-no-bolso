// Web Push com WebCrypto puro: cifra aes128gcm (RFC 8291) e assinatura VAPID (RFC 8292).
import { deBase64Url, juntar, paraBase64Url, utf8 } from './base64.js';

async function hmac(chave, dados) {
  const k = await crypto.subtle.importKey('raw', chave, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, dados));
}

/** HKDF de um bloco só (até 32 bytes), como a RFC 8291 usa. */
async function hkdf(sal, ikm, info, tamanho) {
  const prk = await hmac(sal, ikm);
  return (await hmac(prk, juntar(info, new Uint8Array([1])))).slice(0, tamanho);
}

/** Cifra a mensagem para uma inscrição { keys: { p256dh, auth } }. */
export async function cifrarMensagem(inscricao, texto, { sal, parLocal } = {}) {
  const uaPublica = deBase64Url(inscricao.keys.p256dh);
  const segredoAuth = deBase64Url(inscricao.keys.auth);
  const par = parLocal ?? (await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']));
  const asPublica = new Uint8Array(await crypto.subtle.exportKey('raw', par.publicKey));
  const chaveUa = await crypto.subtle.importKey('raw', uaPublica, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const compartilhado = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: chaveUa }, par.privateKey, 256));

  const ikm = await hkdf(segredoAuth, compartilhado, juntar(utf8('WebPush: info\0'), uaPublica, asPublica), 32);
  const salt = sal ?? crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, utf8('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdf(salt, ikm, utf8('Content-Encoding: nonce\0'), 12);

  const chaveAes = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const claro = juntar(utf8(texto), new Uint8Array([2])); // 2 = último (e único) registro
  const cifrado = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, chaveAes, claro));

  const rs = new Uint8Array([0, 0, 16, 0]); // 4096
  return juntar(salt, rs, new Uint8Array([asPublica.length]), asPublica, cifrado);
}

/** JWT ES256 do VAPID, assinado com a chave privada do Worker. */
export async function assinaturaVapid(endpoint, { publica, privada, assunto }, agora = Date.now()) {
  const pub = deBase64Url(publica);
  const jwk = { kty: 'EC', crv: 'P-256', d: privada, x: paraBase64Url(pub.slice(1, 33)), y: paraBase64Url(pub.slice(33, 65)), ext: true };
  const chave = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const cabecalho = paraBase64Url(utf8(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const corpo = paraBase64Url(utf8(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(agora / 1000) + 12 * 3600, sub: assunto })));
  const assinatura = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, chave, utf8(`${cabecalho}.${corpo}`));
  return `vapid t=${cabecalho}.${corpo}.${paraBase64Url(assinatura)}, k=${publica}`;
}

/** Envia um push. Devolve o status do serviço da Apple/Google (404/410 = inscrição morta). */
export async function enviarPush(inscricao, mensagem, vapid, fetcher = fetch) {
  const corpo = await cifrarMensagem(inscricao, JSON.stringify(mensagem));
  const resposta = await fetcher(inscricao.endpoint, {
    method: 'POST',
    headers: {
      Authorization: await assinaturaVapid(inscricao.endpoint, vapid),
      'Content-Encoding': 'aes128gcm',
      'Content-Type': 'application/octet-stream',
      TTL: '900',
      Urgency: 'high',
    },
    body: corpo,
  });
  return resposta.status;
}
