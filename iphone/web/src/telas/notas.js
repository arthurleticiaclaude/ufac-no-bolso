import { ler } from '../lib/armazenamento.js';
import { atualizarNotas } from '../lib/dados.js';
import { LIMITE_FALTAS, situacaoApresentavel, situacaoFaltas, totalDaNota } from '../lib/dominio/academico.js';
import { rotuloAtualizado } from '../lib/dominio/formatos.js';
import { barraCompacta, botaoRedondo, cabecalho, esqueleto, html, montar, remontar, puxarParaAtualizar, vazio } from '../ui/componentes.js';
import { expirado, faixaExpirada, faixaFalha, fraseDeFalha } from './comum.js';

function blocoFaltas(d) {
  const s = situacaoFaltas(d.faltas, { cargaHoraria: null, permitidasSemCarga: LIMITE_FALTAS });
  if (!s) return '';
  const largura = Math.min(100, (s.faltas / (s.permitidas + 1)) * 100);
  const texto = s.nivel === 'limite' ? `${s.faltas} faltas: passou do limite de ${s.permitidas}` : `${s.faltas} de ${s.permitidas} faltas permitidas`;
  return html`<div style="margin-top:10px"><div class="linha"><span class="apoio cresce">${texto}</span>${s.nivel !== 'tranquilo' ? html`<span class="selo ${s.nivel === 'limite' ? 'perigo' : ''}">${s.nivel === 'limite' ? 'Reprova por falta' : 'Atenção'}</span>` : ''}</div>
    <div class="barra-faltas ${s.nivel}" role="meter" aria-valuemin="0" aria-valuemax="${s.permitidas + 1}" aria-valuenow="${s.faltas}" aria-label="Faltas"><div style="width:${largura}%"></div></div></div>`;
}

export default async function notas(tela, { ir, acoes }) {
  let falha = '';
  let aberta = null;

  async function desenhar(carregando = false) {
    const n = await ler('notas');
    remontar(tela.querySelector('.pilha'), html`
      ${cabecalho({ titulo: 'Notas', sub: n ? `${n.semestre} · ${rotuloAtualizado(n.lidoEm)}` : 'Semestre atual', acoes: botaoRedondo('menu', 'Menu', 'menu') })}
      ${(await expirado('portal')) ? faixaExpirada('portal') : ''}
      ${falha ? faixaFalha(falha) : ''}
      ${!n
        ? html`<div class="cartao vidro">${carregando ? esqueleto(4) : vazio('notas', 'Ainda não li suas notas', 'Puxe para baixo para tentar de novo.')}</div>`
        : n.disciplinas.length === 0
          ? html`<div class="cartao vidro">${vazio('notas', 'Nenhuma disciplina neste semestre')}</div>`
          : n.disciplinas.map((d, i) => html`
            <section class="cartao vidro">
              <button class="linha tocavel" style="width:100%;text-align:left" data-acao="abrir" data-valor="${i}" aria-expanded="${aberta === i}">
                <div class="cresce"><div class="forte">${d.disciplina}</div><div class="apoio">${situacaoApresentavel(d.situacao)}</div></div>
                <div style="text-align:right"><div class="rotulo">Média</div><div class="forte" style="font-size:20px">${d.media || '—'}</div></div>
              </button>
              ${blocoFaltas(d)}
              ${aberta === i
                ? html`<table class="tabela-notas">${d.notas.map((nota) => html`<tr><td>${nota.rotulo}${nota.peso ? html` <span class="apoio">(${nota.peso})</span>` : ''}</td><td>${totalDaNota(nota) || '—'}</td></tr>`)}
                    ${d.resumo.map((r) => html`<tr><td>${r.rotulo}</td><td>${r.valor || '—'}</td></tr>`)}</table>
                    ${!d.notas.length && !d.resumo.length ? html`<div class="apoio" style="margin-top:8px">O portal ainda não publicou o quadro de notas.</div>` : ''}`
                : ''}
            </section>`)}
      ${n ? html`<div class="apoio" style="text-align:center">Até ${LIMITE_FALTAS} faltas são permitidas; a ${LIMITE_FALTAS + 1}ª reprova.</div>` : ''}
    `);
  }

  montar(tela, html`<div class="pilha entra"></div>`);
  barraCompacta(tela, 'Notas');
  acoes.menu = () => ir('menu');
  acoes['entrar-portal'] = () => ir('login/portal');
  acoes.abrir = (el) => {
    const i = Number(el.dataset.valor);
    aberta = aberta === i ? null : i;
    desenhar();
  };
  const tem = await ler('notas');
  await desenhar(!tem);

  async function atualizar() {
    falha = '';
    try {
      await atualizarNotas();
    } catch (e) {
      falha = fraseDeFalha(e, 'o Portal', (await ler('notas'))?.lidoEm);
    }
    await desenhar();
  }
  puxarParaAtualizar(tela, atualizar);
  if (!tem || Date.now() - new Date(tem.lidoEm).getTime() > 6 * 3600 * 1000) await atualizar();
}
