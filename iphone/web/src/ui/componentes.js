// Componentes reutilizáveis. O HTML é montado com `html` (escapa tudo por padrão).
import { icone } from './icones.js';

const ESCAPE = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
export const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ESCAPE[c]);

/** Marca um trecho como HTML já seguro (para compor componentes). */
export const cru = (s) => ({ __cru: String(s) });

/** Template que escapa os valores interpolados, menos os marcados com cru() e listas de cru(). */
export function html(partes, ...valores) {
  let s = partes[0];
  valores.forEach((v, i) => {
    if (Array.isArray(v)) s += v.map((x) => (x?.__cru !== undefined ? x.__cru : esc(x))).join('');
    else s += v?.__cru !== undefined ? v.__cru : v === false || v == null ? '' : esc(v);
    s += partes[i + 1];
  });
  return cru(s);
}

export const ic = (nome, rotulo) => cru(icone(nome, rotulo));

export function montar(alvo, conteudo) {
  alvo.innerHTML = conteudo.__cru ?? conteudo;
  return alvo;
}

/**
 * Como montar(), mas mexe só no que mudou. Trocar tudo com innerHTML recria os cartões de vidro (o iOS refaz o
 * desfoque), recarrega a foto e reinicia a animação de entrada: é isso que fazia a Início e o RU piscarem ao
 * abrir, quando os dados salvos eram desenhados e logo em seguida os novos. Use só em telas cujos botões
 * funcionam por data-acao (os elementos mantidos não ganham ouvintes de novo).
 */
export function remontar(alvo, conteudo) {
  if (!alvo.firstChild) return montar(alvo, conteudo);
  const modelo = document.createElement('template');
  modelo.innerHTML = conteudo.__cru ?? conteudo;
  morfarFilhos(alvo, modelo.content);
  return alvo;
}

const chave = (n) => (n.nodeType === 1 ? `${n.nodeName}|${n.getAttribute('aria-label') ?? ''}|${n.className}` : `#${n.nodeType}`);
const parecidos = (a, b) => a.nodeType === b.nodeType && a.nodeName === b.nodeName;

function morfarFilhos(pai, novoPai) {
  let atual = pai.firstChild;
  for (const novo of [...novoPai.childNodes]) {
    if (atual && !parecidos(atual, novo)) {
      // Procura adiante um irmão igual (ex.: uma faixa de aviso que sumiu antes deste cartão).
      let adiante = atual.nextSibling;
      while (adiante && chave(adiante) !== chave(novo)) adiante = adiante.nextSibling;
      if (adiante) {
        while (atual !== adiante) {
          const prox = atual.nextSibling;
          atual.remove();
          atual = prox;
        }
      }
    }
    if (atual && parecidos(atual, novo)) {
      if (novo.nodeType === 1) morfar(atual, novo);
      else if (atual.nodeValue !== novo.nodeValue) atual.nodeValue = novo.nodeValue;
      atual = atual.nextSibling;
    } else {
      pai.insertBefore(novo, atual);
    }
  }
  while (atual) {
    const prox = atual.nextSibling;
    atual.remove();
    atual = prox;
  }
}

function morfar(velho, novo) {
  for (const { name } of [...velho.attributes]) if (!novo.hasAttribute(name)) velho.removeAttribute(name);
  for (const { name, value } of novo.attributes) if (velho.getAttribute(name) !== value) velho.setAttribute(name, value);
  morfarFilhos(velho, novo);
}

export const cabecalho = ({ sobre, titulo, sub, acoes = '' }) => html`
  <header class="cabecalho">
    <div class="cresce">
      ${sobre ? html`<div class="sobre">${sobre}</div>` : ''}
      <h1>${titulo}</h1>
      ${sub ? html`<div class="sub">${sub}</div>` : ''}
    </div>
    ${acoes}
  </header>`;

export const botaoRedondo = (nome, rotulo, acao) =>
  html`<button class="botao-redondo vidro tocavel" data-acao="${acao}" aria-label="${rotulo}">${ic(nome)}</button>`;

export const vazio = (nome, titulo, texto = '') => html`
  <div class="vazio">${ic(nome)}<div class="titulo">${titulo}</div>${texto ? html`<div>${texto}</div>` : ''}</div>`;

export const esqueleto = (linhas = 3) => html`
  <div class="pilha" aria-busy="true" aria-label="Carregando">
    ${Array.from({ length: linhas }, (_, i) => cru(`<div class="esqueleto" style="height:${i === 0 ? 22 : 16}px;width:${[60, 90, 75, 40][i % 4]}%"></div>`))}
  </div>`;

export const faixa = ({ icone: nome = 'info', titulo, texto = '', tipo = '', acao = '', rotuloAcao = '' }) => html`
  <div class="faixa ${tipo}" role="status">
    ${ic(nome)}
    <div class="cresce"><div class="titulo">${titulo}</div>${texto ? html`<div>${texto}</div>` : ''}</div>
    ${acao ? html`<button class="acao" data-acao="${acao}">${rotuloAcao}</button>` : ''}
  </div>`;

export const item = ({ icone: nome, titulo, sub = '', acao = '', href = '', tipoIcone = '', direita = '' }) => {
  const dentro = html`
    ${nome ? html`<span class="icone ${tipoIcone}">${ic(nome)}</span>` : ''}
    <span class="cresce"><span class="titulo">${titulo}</span>${sub ? html`<span class="apoio" style="display:block">${sub}</span>` : ''}</span>
    ${direita || (acao || href ? html`<span class="seta">${ic('seta')}</span>` : '')}`;
  if (href) return html`<a class="item tocavel" href="${href}" target="_blank" rel="noopener">${dentro}</a>`;
  if (acao) return html`<button class="item tocavel" data-acao="${acao}">${dentro}</button>`;
  return html`<div class="item">${dentro}</div>`;
};

export function segmentos(opcoes, ativo, acao) {
  const i = Math.max(0, opcoes.findIndex((o) => o.id === ativo));
  return html`
    <div class="segmentos" role="tablist" style="--n:${opcoes.length};--i:${i}">
      <span class="polegar"></span>
      ${opcoes.map((o) => html`<button role="tab" aria-selected="${o.id === ativo}" data-acao="${acao}" data-valor="${o.id}">${o.nome}${o.sub ? html`<small>${o.sub}</small>` : ''}</button>`)}
    </div>`;
}

// ---------- Folha (sheet) e aviso ----------

export function abrirFolha(conteudo, { aoFechar } = {}) {
  const veu = document.createElement('div');
  veu.className = 'veu';
  const folha = document.createElement('div');
  folha.className = 'folha vidro forte';
  folha.setAttribute('role', 'dialog');
  folha.setAttribute('aria-modal', 'true');
  montar(folha, html`<div class="alca"></div>${conteudo}`);
  document.body.append(veu, folha);
  requestAnimationFrame(() => {
    veu.classList.add('aberto');
    folha.classList.add('aberta');
  });
  const fechar = () => {
    veu.classList.remove('aberto');
    folha.classList.remove('aberta');
    setTimeout(() => {
      veu.remove();
      folha.remove();
    }, 420);
    aoFechar?.();
  };
  veu.addEventListener('click', fechar);
  // Arrastar a folha para baixo fecha.
  let inicioY = null;
  folha.addEventListener('touchstart', (e) => (inicioY = folha.scrollTop === 0 ? e.touches[0].clientY : null), { passive: true });
  folha.addEventListener('touchmove', (e) => {
    if (inicioY === null) return;
    const d = Math.max(0, e.touches[0].clientY - inicioY);
    folha.style.transition = 'none';
    folha.style.transform = `translateY(${d}px)`;
  }, { passive: true });
  folha.addEventListener('touchend', (e) => {
    if (inicioY === null) return;
    const d = e.changedTouches[0].clientY - inicioY;
    folha.style.transition = '';
    folha.style.transform = '';
    inicioY = null;
    if (d > 110) fechar();
  });
  return { folha, fechar };
}

/** Pergunta de confirmação em folha. Resolve true/false. */
export function confirmar({ titulo, texto, sim, perigo = false }) {
  return new Promise((resolve) => {
    let respondido = false;
    const { folha, fechar } = abrirFolha(
      html`<div class="pilha" style="padding:6px 2px 4px">
        <h2 style="margin:0;font-size:20px">${titulo}</h2>
        <div class="apoio" style="font-size:15px">${texto}</div>
        <button class="botao largo ${perigo ? 'perigo' : ''}" data-r="sim">${sim}</button>
        <button class="botao largo claro" data-r="nao">Cancelar</button>
      </div>`,
      { aoFechar: () => !respondido && resolve(false) },
    );
    folha.addEventListener('click', (e) => {
      const r = e.target.closest('[data-r]')?.dataset.r;
      if (!r) return;
      respondido = true;
      resolve(r === 'sim');
      fechar();
    });
  });
}

let toastAtual;
export function avisar(texto) {
  toastAtual?.remove();
  const t = document.createElement('div');
  t.className = 'aviso-toast vidro forte';
  t.setAttribute('role', 'status');
  t.textContent = texto;
  document.body.append(t);
  toastAtual = t;
  requestAnimationFrame(() => t.classList.add('visivel'));
  setTimeout(() => {
    t.classList.remove('visivel');
    setTimeout(() => t.remove(), 450);
  }, 3200);
}

// ---------- Puxar para atualizar e barra compacta ----------

export function puxarParaAtualizar(tela, aoAtualizar) {
  const indicador = document.createElement('div');
  indicador.className = 'puxar';
  indicador.innerHTML = `<div class="roda vidro forte">${icone('atualizar')}</div>`;
  tela.prepend(indicador);
  let inicio = null;
  let distancia = 0;
  let ocupado = false;
  tela.addEventListener('touchstart', (e) => {
    inicio = tela.scrollTop <= 0 && !ocupado ? e.touches[0].clientY : null;
  }, { passive: true });
  tela.addEventListener('touchmove', (e) => {
    if (inicio === null) return;
    distancia = Math.max(0, e.touches[0].clientY - inicio);
    const p = Math.min(1, distancia / 80);
    indicador.style.opacity = p;
    indicador.style.transform = `translateY(${Math.min(distancia, 90) * 0.6}px) rotate(${p * 270}deg)`;
  }, { passive: true });
  tela.addEventListener('touchend', async () => {
    if (inicio === null) return;
    inicio = null;
    if (distancia > 80) {
      ocupado = true;
      indicador.classList.add('girando');
      indicador.style.transform = 'translateY(40px)';
      try {
        // Rede pendurada não pode deixar a roda girando para sempre (cada pedido já tem limite próprio).
        await Promise.race([aoAtualizar(), new Promise((ok) => setTimeout(ok, 60000))]);
      } catch {
        /* a tela mostra a falha na faixa */
      } finally {
        ocupado = false;
        indicador.classList.remove('girando');
      }
    }
    distancia = 0;
    indicador.style.transition = 'opacity 250ms, transform 300ms';
    indicador.style.opacity = 0;
    indicador.style.transform = '';
    setTimeout(() => (indicador.style.transition = ''), 320);
  });
}

export function barraCompacta(tela, titulo) {
  const barra = document.createElement('div');
  barra.className = 'barra-topo vidro forte';
  barra.setAttribute('aria-hidden', 'true');
  barra.textContent = titulo;
  tela.append(barra);
  tela.addEventListener('scroll', () => barra.classList.toggle('visivel', tela.scrollTop > 56), { passive: true });
}
