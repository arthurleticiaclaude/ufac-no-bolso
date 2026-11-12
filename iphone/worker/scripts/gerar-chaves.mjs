// Gera as chaves do Worker. Uso: node scripts/gerar-chaves.mjs [--dev]
// Sem --dev, só mostra os valores para colar em "npx wrangler secret put".
// Com --dev, grava .dev.vars (fora do git) para o "wrangler dev".
import { writeFileSync } from 'node:fs';

const b64url = (b) => Buffer.from(b).toString('base64url');
const sessao = b64url(crypto.getRandomValues(new Uint8Array(32)));
const par = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign']);
const publica = b64url(await crypto.subtle.exportKey('raw', par.publicKey));
const privada = (await crypto.subtle.exportKey('jwk', par.privateKey)).d;

const linhas = `SESSAO_CHAVE=${sessao}\nVAPID_PUBLICA=${publica}\nVAPID_PRIVADA=${privada}\n`;
if (process.argv.includes('--dev')) {
  writeFileSync(new URL('../.dev.vars', import.meta.url), linhas);
  console.log('Gravado worker/.dev.vars (só para desenvolvimento).');
} else {
  console.log(linhas);
  console.log('Cole cada valor com: npx wrangler secret put NOME (a pública também vai no PWA).');
}
