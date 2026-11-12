// Worker falso para os testes: responde como o Worker real, mas com as fixtures anonimizadas.
// Nenhum pedido vai para a Ufac. Uso: node e2e/worker-falso.mjs (porta 8787).
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { resolve } from 'node:path';

const FIXTURES = resolve(import.meta.dirname, '../fixtures');
const fixture = (nome) => readFileSync(resolve(FIXTURES, nome), 'utf8');
const PDF = '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF';

let estado = { portal: false, eticket: false, eticketMudo: false, pedidos: [] };

createServer((req, res) => {
  let corpo = '';
  req.on('data', (c) => (corpo += c));
  req.on('end', () => {
    const url = new URL(req.url, 'http://localhost:8787');
    const caminho = url.pathname + url.search;
    const cors = {
      'Access-Control-Allow-Origin': req.headers.origin ?? '*',
      'Access-Control-Expose-Headers': 'X-Sessao, X-Url-Final, Content-Disposition',
      'Access-Control-Allow-Headers': 'Content-Type, X-Sessao, X-Requested-With',
      'Access-Control-Allow-Methods': 'GET, POST',
    };
    const responder = (status, conteudo, final = '', tipo = 'text/html; charset=utf-8') => {
      res.writeHead(status, { ...cors, 'Content-Type': tipo, 'X-Sessao': 'sessao-cifrada-falsa', 'X-Url-Final': final });
      res.end(conteudo);
    };
    if (req.method === 'OPTIONS') return responder(204, '');
    if (url.pathname === '/__reset') {
      estado = { portal: false, eticket: false, eticketMudo: false, pedidos: [] };
      return responder(200, 'ok');
    }
    // Simula o eTICKET sem responder à Cloudflare (o pedido fica pendurado para sempre).
    if (url.pathname === '/__eticket-mudo') {
      estado.eticketMudo = true;
      return responder(200, 'ok');
    }
    if (estado.eticketMudo && url.pathname.startsWith('/eticket')) return;
    if (url.pathname === '/__pedidos') return responder(200, JSON.stringify(estado.pedidos), '', 'application/json');
    estado.pedidos.push(`${req.method} ${caminho}`);
    if (url.pathname === '/push/chave') return responder(200, JSON.stringify({ chave: 'x' }), '', 'application/json');
    if (url.pathname.startsWith('/push/')) return responder(200, '{"ok":true}', '', 'application/json');
    if (url.pathname === '/google/trocar') {
      const ok = corpo.includes('"code":"codigo-falso"') && corpo.includes('"verifier"');
      return responder(ok ? 200 : 401, JSON.stringify(ok ? { access_token: 'A', expires_in: 3600, cofre: 'cofre-cifrado-falso' } : { erro: 'invalid_grant' }), '', 'application/json');
    }
    if (url.pathname === '/google/renovar') return responder(200, JSON.stringify({ access_token: 'A2', expires_in: 3600 }), '', 'application/json');
    if (url.pathname === '/google/desconectar') return responder(200, '{"ok":true}', '', 'application/json');

    if (url.pathname.startsWith('/eticket')) {
      const e = url.pathname.slice('/eticket'.length);
      const base = 'https://sistemas.ufac.br/eticket';
      if (e === '/login/' && req.method === 'POST') {
        estado.eticket = corpo.includes('csrfmiddlewaretoken=TOKEN_FALSO') && corpo.includes('password=senha-eticket');
        return estado.eticket ? responder(200, fixture('eticket_home.html'), `${base}/`) : responder(200, fixture('public/eticket_login.html'), `${base}/login/`);
      }
      if (e === '/login/' || !estado.eticket) return responder(200, fixture('public/eticket_login.html'), `${base}/login/?next=/eticket/`);
      const mapa = { '/': 'eticket_home.html', '/menu/': 'eticket_menu.html', '/historico/': 'eticket_historico.html', '/historico/refeicoes/': 'eticket_refeicoes.html' };
      if (mapa[e]) return responder(200, fixture(mapa[e]), base + e);
    }
    if (url.pathname.startsWith('/portal')) {
      const q = caminho.slice('/portal'.length);
      if (q.startsWith('/aluno/j_security_check')) {
        estado.portal = corpo.includes('j_password=senha-de-teste');
        return estado.portal
          ? responder(200, fixture('portal_inicio.html'), 'https://portal.ufac.br/aluno/index.action')
          : responder(200, fixture('public/portal_login.html'), 'https://portal.ufac.br/aluno/login.action?error=');
      }
      if (!estado.portal) return responder(200, fixture('public/portal_login.html'), 'https://portal.ufac.br/aluno/login.action');
      const final = `https://portal.ufac.br${q}`;
      if (q.startsWith('/aluno/index.action')) return responder(200, fixture('portal_inicio.html'), final);
      if (q.includes('relatorio/relatorios.action')) return responder(200, fixture('portal_relatorios.html'), final);
      if (q.includes('relatorio/')) return responder(200, PDF, final, 'application/pdf');
      if (q.includes('quadrohorario')) return responder(200, fixture('portal_horarios_ajax.html'), final);
      if (q.includes('nota/nota.action')) return responder(200, fixture('portal_notas.html'), final);
      if (q.includes('notaturma.action')) return responder(200, fixture('portal_notaturma_ajax.html'), final);
      if (q.includes('turma.action')) return responder(200, fixture('portal_turma.html'), final);
    }
    responder(404, 'sem fixture');
  });
}).listen(8787, () => console.log('Worker falso em http://localhost:8787'));
