// Gera as telas de abertura do iOS (apple-touch-startup-image) e os <link> do index.html.
// Uso: node tools/gerar-splash.mjs  (precisa do WebKit do Playwright instalado)
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { webkit } from '@playwright/test';

const WEB = resolve(import.meta.dirname, '../web');
// [largura CSS, altura CSS, escala]: iPhones de tela cheia em retrato.
const TELAS = [
  [440, 956, 3], [420, 912, 3], [402, 874, 3], [430, 932, 3], [393, 852, 3],
  [390, 844, 3], [428, 926, 3], [375, 812, 3], [414, 896, 3], [414, 896, 2], [375, 667, 2],
];
const icone = readFileSync(resolve(WEB, 'public/icones/icone-512.png')).toString('base64');
const pagina = `<html><body style="margin:0;height:100vh;display:grid;place-items:center;background:#0B4FA8">
  <img src="data:image/png;base64,${icone}" style="width:132px;height:132px;border-radius:30px">
</body></html>`;

const navegador = await webkit.launch();
const links = [];
for (const [w, h, s] of TELAS) {
  const contexto = await navegador.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: s });
  const p = await contexto.newPage();
  await p.setContent(pagina);
  const nome = `splash-${w * s}x${h * s}.png`;
  await p.screenshot({ path: resolve(WEB, 'public/splash', nome) });
  links.push(`<link rel="apple-touch-startup-image" media="(device-width: ${w}px) and (device-height: ${h}px) and (-webkit-device-pixel-ratio: ${s}) and (orientation: portrait)" href="/splash/${nome}">`);
  await contexto.close();
}
await navegador.close();
const indice = resolve(WEB, 'index.html');
const html = readFileSync(indice, 'utf8').replace(/<!--SPLASH-->[\s\S]*?<!--\/SPLASH-->|<!--SPLASH-->/, `<!--SPLASH-->\n    ${links.join('\n    ')}\n    <!--/SPLASH-->`);
writeFileSync(indice, html);
console.log(`${links.length} telas de abertura geradas.`);
