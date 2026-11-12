import { ler } from '../lib/armazenamento.js';
import { baixarRelatorio } from '../lib/dados.js';
import { RELATORIOS } from '../lib/config.js';
import { semestreCurto } from '../lib/dominio/academico.js';
import { avisar, barraCompacta, botaoRedondo, cabecalho, html, ic, montar } from '../ui/componentes.js';
import { fraseDeFalha } from './comum.js';

/** Visualizador em tela cheia, com o botão de compartilhar/salvar do iPhone. */
function mostrarPdf(blob, arquivo, nome) {
  const url = URL.createObjectURL(blob);
  const tela = document.createElement('div');
  tela.className = 'qr-tela';
  tela.style.padding = 'calc(env(safe-area-inset-top) + 8px) 0 0';
  montar(tela, html`
    <div class="linha" style="width:100%;padding:0 16px 8px">
      <button class="botao-redondo vidro tocavel" data-p="fechar" aria-label="Fechar">${ic('fechar')}</button>
      <div class="cresce forte" style="text-align:center">${nome}</div>
      <button class="botao-redondo vidro tocavel" data-p="compartilhar" aria-label="Compartilhar ou salvar">${ic('compartilhar')}</button>
    </div>
    <iframe src="${url}" title="${nome}" style="flex:1;width:100%;border:0;background:#fff"></iframe>`);
  tela.addEventListener('click', (e) => {
    const p = e.target.closest('[data-p]')?.dataset.p;
    if (p === 'fechar') {
      tela.remove();
      URL.revokeObjectURL(url);
    }
    if (p === 'compartilhar') compartilhar(blob, arquivo);
  });
  document.body.append(tela);
}

async function compartilhar(blob, arquivo) {
  const file = new File([blob], arquivo, { type: 'application/pdf' });
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file] });
    } catch {
      /* a pessoa fechou a folha */
    }
    return;
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = arquivo;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
}

export default async function relatorios(tela, { ir, acoes }) {
  const ident = await ler('identificacao');
  const mais = await ler('urlMaisRelatorios');
  montar(tela, html`<div class="pilha entra">
    ${cabecalho({ titulo: 'Relatórios', sub: ident ? `${ident.curso} · ${ident.periodo}º período · ${semestreCurto(ident.semestre)}` : 'Portal do Aluno', acoes: botaoRedondo('menu', 'Menu', 'menu') })}
    <section class="cartao vidro lista" style="padding:4px 0">
      ${RELATORIOS.map((r) => html`
        <div class="item">
          <span class="icone perigo" style="font-size:10px;font-weight:800">PDF</span>
          <span class="cresce titulo">${r.nome}</span>
          <button class="botao-redondo tocavel" style="background:var(--nav-active-bg);color:var(--nav-active);width:40px;height:40px" data-acao="ver" data-valor="${r.acao}" aria-label="Visualizar ${r.nome}">${ic('olho')}</button>
          <button class="botao-redondo tocavel" style="background:var(--primary);color:#fff;width:40px;height:40px" data-acao="baixar" data-valor="${r.acao}" aria-label="Salvar ou compartilhar ${r.nome}">${ic('baixar')}</button>
        </div>`)}
    </section>
    ${mais ? html`<a class="cartao vidro item tocavel" href="${mais}" target="_blank" rel="noopener"><span class="icone">${ic('relatorios')}</span><span class="cresce titulo">Mais relatórios<span class="apoio" style="display:block">Abre no Safari; entre com o ID Ufac lá.</span></span><span class="seta">${ic('abrir')}</span></a>` : ''}
    <div class="apoio" style="text-align:center">Os PDFs são gerados pelo Portal do Aluno na hora do pedido.</div>
  </div>`);
  barraCompacta(tela, 'Relatórios');
  acoes.menu = () => ir('menu');

  const ocupados = new Set();
  async function pegar(el, fn) {
    const r = RELATORIOS.find((x) => x.acao === el.dataset.valor);
    if (ocupados.has(r.acao)) return;
    ocupados.add(r.acao);
    el.style.opacity = 0.5;
    try {
      const blob = await baixarRelatorio(r.acao);
      if (!blob) return ir('login/portal');
      await fn(blob, r);
    } catch (e) {
      avisar(fraseDeFalha(e, 'o Portal'));
    } finally {
      ocupados.delete(r.acao);
      el.style.opacity = '';
    }
  }
  acoes.ver = (el) => pegar(el, (blob, r) => mostrarPdf(blob, r.arquivo, r.nome));
  acoes.baixar = (el) => pegar(el, (blob, r) => compartilhar(blob, r.arquivo));
}
