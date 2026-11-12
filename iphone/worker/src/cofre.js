// Os cookies de sessão da Ufac viajam cifrados (AES-GCM) e ficam só no iPhone.
// O Worker não guarda nada: decifra a cada pedido com a chave SESSAO_CHAVE e esquece.
import { deBase64Url, juntar, paraBase64Url, utf8 } from './base64.js';

async function chave(segredo) {
  const bruto = deBase64Url(segredo);
  if (bruto.length !== 32) throw new Error('SESSAO_CHAVE precisa ter 32 bytes em base64url');
  return crypto.subtle.importKey('raw', bruto, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

export async function cifrar(objeto, segredo) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const dados = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await chave(segredo), utf8(JSON.stringify(objeto)));
  return paraBase64Url(juntar(iv, new Uint8Array(dados)));
}

/** Devolve null se o texto não foi cifrado por este Worker (ou foi alterado). */
export async function decifrar(texto, segredo) {
  if (!texto) return null;
  try {
    const bytes = deBase64Url(texto);
    const dados = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: bytes.slice(0, 12) }, await chave(segredo), bytes.slice(12));
    return JSON.parse(new TextDecoder().decode(dados));
  } catch {
    return null;
  }
}
