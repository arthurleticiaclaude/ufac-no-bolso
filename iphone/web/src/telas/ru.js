import { SemConexao } from '../lib/api.js';
import { ler } from '../lib/armazenamento.js';
import { atualizarCardapio, atualizarRu } from '../lib/dados.js';
import { INSTAGRAM_RU, URL_RECARGA } from '../lib/config.js';
import { formatarData, formatarHoraMin, formatarMoeda, rotuloAtualizado } from '../lib/dominio/formatos.js';
import { REFEICOES, cardapioValeEm, itensDoCardapio, proximaRefeicao } from '../lib/dominio/refeicoes.js';
import { barraCompacta, botaoRedondo, cabecalho, esqueleto, html, ic, item, montar, puxarParaAtualizar, remontar, segmentos } from '../ui/componentes.js';
import { expirado, faixaExpirada, faixaFalha, fraseDeFalha } from './comum.js';
import { abrirQr } from './qr.js';

/** Diz se o eTICKET ainda não publicou (e quando conferimos) ou se a refeição já passou sem cardápio. */
function fraseSemCardapio(refeicao, cardapio, deHoje, agora) {
  const conferido = deHoje ? ` Conferido no eTICKET às ${formatarHoraMin(new Date(cardapio.lidoEm).getHours() * 60 + new Date(cardapio.lidoEm).getMinutes())}.` : '';
  const minutos = agora.getHours() * 60 + agora.getMinutes();
  if (minutos >= refeicao.fimMin) return `O eTICKET não publicou o cardápio do ${refeicao.minusculo} de hoje.${conferido}`;
  return `O cardápio do ${refeicao.minusculo} ainda não saiu. Costuma aparecer perto do horário.${conferido}`;
}

export default async function ru(tela, { ir, parametro, acoes }) {
  let escolhida = REFEICOES.some((r) => r.id === parametro) ? parametro : proximaRefeicao(new Date()).id;
  let falha = '';
  let carregando = true;

  async function desenhar() {
    const agora = new Date();
    const [saldo, cardapio] = await Promise.all([ler('ru'), ler('cardapio')]);
    const refeicao = REFEICOES.find((r) => r.id === escolhida);
    const deHoje = cardapioValeEm(cardapio, agora);
    const itens = deHoje ? itensDoCardapio(cardapio.textos[refeicao.id]) : [];
    remontar(tela.querySelector('.pilha'), html`
      ${cabecalho({ titulo: 'RU', sub: 'Restaurante Universitário · Ufac', acoes: botaoRedondo('menu', 'Menu', 'menu') })}
      ${(await expirado('eticket')) ? faixaExpirada('eticket') : ''}
      ${falha ? faixaFalha(falha) : ''}
      <section class="cartao vidro tingido">
        <div class="rotulo">Saldo</div>
        ${saldo ? html`<div class="saldo">${formatarMoeda(saldo.saldo)}</div><div class="apoio">${rotuloAtualizado(saldo.lidoEm, agora)}</div>` : carregando ? html`<div class="esqueleto" style="height:44px;width:55%;margin:8px 0;opacity:.4"></div>` : html`<div class="saldo">—</div>`}
        <button class="botao acento largo tocavel" style="margin-top:14px" data-acao="qr">${ic('qr')} Mostrar QR de entrada</button>
        <a class="botao contorno largo tocavel" style="margin-top:10px" href="${URL_RECARGA}" target="_blank" rel="noopener">${ic('mais')} Recarregar créditos</a>
        <div class="apoio" style="margin-top:8px;text-align:center">A recarga abre o site oficial do eTICKET no Safari.</div>
      </section>
      <section class="cartao vidro">
        <h2>Cardápio de hoje <span class="apoio" style="font-weight:500">· ${formatarData(agora)}</span></h2>
        ${segmentos(REFEICOES.map((r) => ({ id: r.id, nome: r.nome, sub: formatarHoraMin(r.inicioMin) })), escolhida, 'refeicao')}
        ${itens.length
          ? html`<ul style="margin:0;padding-left:20px;line-height:1.9">${itens.map((i) => html`<li>${i}</li>`)}</ul>`
          : carregando && !deHoje
            ? esqueleto(3)
            : html`<div class="apoio" style="font-size:15px">${fraseSemCardapio(refeicao, cardapio, deHoje, agora)}</div>
                <a class="botao claro largo tocavel" style="margin-top:12px" href="${INSTAGRAM_RU}" target="_blank" rel="noopener">${ic('camera')} Ver no Instagram do RU</a>`}
      </section>
      <section class="cartao vidro lista" style="padding:4px 0">
        ${item({ icone: 'historico', titulo: 'Histórico de uso', sub: 'Refeições e recargas', acao: 'historico' })}
      </section>
    `);
  }

  montar(tela, html`<div class="pilha entra"></div>`);
  barraCompacta(tela, 'RU');
  await desenhar();

  async function atualizar(forcar) {
    falha = '';
    for (const [chave, fn] of [['ru', atualizarRu], ['cardapio', () => atualizarCardapio({ forcar })]]) {
      try {
        await fn();
      } catch (e) {
        falha ||= fraseDeFalha(e, 'o eTICKET', (await ler(chave))?.lidoEm);
        if (e instanceof SemConexao) break; // eTICKET fora do ar: não espera de novo pelo cardápio
      }
    }
    carregando = false;
    await desenhar();
  }

  acoes.menu = () => ir('menu');
  acoes.qr = () => abrirQr();
  acoes.historico = () => ir('historico');
  acoes['entrar-eticket'] = () => ir('login/eticket');
  acoes.refeicao = (el) => {
    escolhida = el.dataset.valor;
    const seg = tela.querySelector('.segmentos');
    seg?.style.setProperty('--i', REFEICOES.findIndex((r) => r.id === escolhida));
    setTimeout(desenhar, 160);
  };
  tela.addEventListener('sessao', desenhar);
  puxarParaAtualizar(tela, () => atualizar(true));
  await atualizar(false);
}
