import { cpSync, existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { defineConfig } from 'vite';

const DOCS = resolve(__dirname, '../docs');
const PAGINAS = ['instalar', 'privacidade'];
let saida = resolve(__dirname, 'dist'); // build.outDir (dist, ou dist-e2e nos testes)
const lerSaida = { name: 'ler-saida', configResolved(c) { saida = resolve(c.root, c.build.outDir); } };

/** Serve /instalar/ e /privacidade/ (de ios-pwa/docs) no dev e copia para o build. */
function paginasDocs() {
  return {
    name: 'paginas-docs',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const pagina = PAGINAS.find((p) => req.url === `/${p}/` || req.url === `/${p}`);
        const arquivo = req.url?.match(/^\/(instalar|privacidade)\/(.+)$/);
        if (pagina) {
          res.setHeader('Content-Type', 'text/html; charset=utf-8');
          return res.end(readFileSync(join(DOCS, pagina, 'index.html')));
        }
        if (arquivo && existsSync(join(DOCS, arquivo[1], arquivo[2]))) {
          return res.end(readFileSync(join(DOCS, arquivo[1], arquivo[2])));
        }
        next();
      });
    },
    closeBundle() {
      for (const p of PAGINAS) cpSync(join(DOCS, p), join(saida, p), { recursive: true });
    },
  };
}

/** Lista o que o service worker guarda para o app abrir offline (com o QR do RU). */
function listaOffline() {
  return {
    name: 'lista-offline',
    apply: 'build',
    closeBundle() {
      const dist = saida;
      const arquivos = [];
      const andar = (pasta) => {
        for (const nome of readdirSync(pasta)) {
          const caminho = join(pasta, nome);
          if (statSync(caminho).isDirectory()) andar(caminho);
          else arquivos.push(`/${caminho.slice(dist.length + 1).split('\\').join('/')}`);
        }
      };
      andar(dist);
      const lista = arquivos.filter((a) => !a.endsWith('sw.js') && !a.endsWith('arquivos.json') && !a.includes('/splash/'));
      const versao = Date.now().toString(36);
      writeFileSync(join(dist, 'arquivos.json'), JSON.stringify({ versao, arquivos: ['/', ...lista] }));
    },
  };
}

export default defineConfig({
  plugins: [lerSaida, paginasDocs(), listaOffline()],
  build: { target: 'safari16', sourcemap: false },
  server: { port: 5173 },
  preview: { port: 4173 },
});
