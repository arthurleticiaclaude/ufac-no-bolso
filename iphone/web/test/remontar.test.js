import { describe, expect, it } from 'vitest';
import { html, montar, remontar } from '../src/ui/componentes.js';

describe('remontar', () => {
  it('mantém os elementos que não mudaram e troca só o texto', () => {
    const alvo = document.createElement('div');
    montar(alvo, html`<section aria-label="A"><b>1</b></section><section aria-label="B"><img src="x"></section>`);
    const [a, b] = alvo.children;
    const img = b.querySelector('img');
    remontar(alvo, html`<section aria-label="A"><b>2</b></section><section aria-label="B"><img src="x"></section>`);
    expect(alvo.children[0]).toBe(a);
    expect(alvo.children[1]).toBe(b);
    expect(b.querySelector('img')).toBe(img);
    expect(a.textContent).toBe('2');
  });

  it('insere e remove uma faixa antes dos cartões sem recriá-los', () => {
    const alvo = document.createElement('div');
    montar(alvo, html`<header>Olá</header><section aria-label="A">a</section><section aria-label="B">b</section>`);
    const [, a, b] = alvo.children;
    remontar(alvo, html`<header>Olá</header><div class="faixa">aviso</div><section aria-label="A">a</section><section aria-label="B">b</section>`);
    expect(alvo.children.length).toBe(4);
    expect(alvo.children[2]).toBe(a);
    remontar(alvo, html`<header>Olá</header><section aria-label="A">a</section><section aria-label="B">b</section>`);
    expect([...alvo.children].map((e) => e.tagName)).toEqual(['HEADER', 'SECTION', 'SECTION']);
    expect(alvo.children[1]).toBe(a);
    expect(alvo.children[2]).toBe(b);
  });

  it('atualiza e remove atributos', () => {
    const alvo = document.createElement('div');
    montar(alvo, html`<div class="segmentos" style="--i:0"><button aria-selected="true">x</button></div>`);
    remontar(alvo, html`<div class="segmentos" style="--i:2"><button>x</button></div>`);
    expect(alvo.firstElementChild.getAttribute('style')).toBe('--i:2');
    expect(alvo.querySelector('button').hasAttribute('aria-selected')).toBe(false);
  });
});
