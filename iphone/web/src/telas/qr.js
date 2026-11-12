// QR do RU: gerado aqui mesmo, a partir do número salvo. Funciona offline.
import qrcode from 'qrcode-generator';
import { ler } from '../lib/armazenamento.js';
import { formatarMoeda, mascararNumero } from '../lib/dominio/formatos.js';
import { html, ic, montar, cru } from '../ui/componentes.js';

export function svgDoQr(numero) {
  const qr = qrcode(0, 'M');
  qr.addData(numero);
  qr.make();
  return qr.createSvgTag({ cellSize: 8, margin: 2, scalable: true });
}

export async function abrirQr() {
  const ru = await ler('ru');
  const tela = document.createElement('div');
  tela.className = 'qr-tela entra';
  tela.setAttribute('role', 'dialog');
  tela.setAttribute('aria-label', 'QR do RU');
  let mostrar = false;
  let trava;

  const desenhar = () =>
    montar(tela, html`
      <div class="linha" style="width:100%;justify-content:space-between">
        <span class="selo">${ic('info')} Aumente o brilho da tela</span>
        <button class="botao-redondo vidro tocavel" data-q="fechar" aria-label="Fechar">${ic('fechar')}</button>
      </div>
      <h1 style="margin:18px 0 2px;font-size:28px;font-weight:800">QR do RU</h1>
      <div class="apoio" style="margin-bottom:18px">Aponte para o leitor na entrada</div>
      ${ru?.numeroQr
        ? html`<div class="qr-cartao">${cru(svgDoQr(ru.numeroQr))}<div class="numero">${mostrar ? ru.numeroQr : mascararNumero(ru.numeroQr)}</div></div>`
        : html`<div class="cartao vidro vazio"><div class="titulo">Ainda não li seu QR</div><div>Abra a aba RU com internet uma vez para salvar o QR neste iPhone.</div></div>`}
      <div class="linha" style="margin-top:18px;flex-wrap:wrap;justify-content:center">
        ${ru ? html`<span class="selo neutro">${ic('dinheiro')} Saldo ${formatarMoeda(ru.saldo)}</span>` : ''}
        <span class="selo verde">${ic('check')} Funciona offline</span>
      </div>
      ${ru?.numeroQr ? html`<button class="botao claro tocavel" style="margin-top:16px" data-q="mostrar">${ic('olho')} ${mostrar ? 'Esconder número' : 'Mostrar número'}</button>` : ''}
      <div class="apoio" style="margin-top:14px;text-align:center">Não compartilhe prints desta tela: o número vale como dinheiro.</div>`);

  desenhar();
  tela.addEventListener('click', (e) => {
    const q = e.target.closest('[data-q]')?.dataset.q;
    if (q === 'fechar') {
      trava?.release().catch(() => {});
      tela.remove();
    }
    if (q === 'mostrar') {
      mostrar = !mostrar;
      desenhar();
    }
  });
  document.body.append(tela);
  // A web não controla o brilho; ao menos mantém a tela acesa enquanto o QR está aberto.
  try {
    trava = await navigator.wakeLock?.request('screen');
  } catch {
    /* sem trava de tela */
  }
}
