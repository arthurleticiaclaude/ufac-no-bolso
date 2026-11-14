import { ler } from '../lib/armazenamento.js';
import { atualizarHorarios, atualizarProfessor } from '../lib/dados.js';
import { aulaValeNoDia } from '../lib/dominio/academico.js';
import { DIAS, diaDaSemana, formatarHoraMin, rotuloAtualizado } from '../lib/dominio/formatos.js';
import { aulasDoProfessor } from '../lib/dominio/professor.js';
import { sincronizarAgenda } from '../lib/push.js';
import { barraCompacta, botaoRedondo, cabecalho, esqueleto, html, montar, remontar, puxarParaAtualizar, vazio } from '../ui/componentes.js';
import { avisoSemEticket, faixaExpirada, faixaFalha, fraseDeFalha, expirado } from './comum.js';

export default async function horarios(tela, { ir, perfil, acoes }) {
  let falha = '';
  const professor = perfil === 'professor';

  async function desenhar(carregando = false) {
    const agora = new Date();
    const hoje = diaDaSemana(agora);
    const dados = professor ? await ler('professor') : await ler('horarios');
    const aulas = professor ? aulasDoProfessor(dados?.turmas ?? []) : dados?.aulas;
    // Cada dia da semana a partir de hoje, com a data real (para respeitar o período da turma).
    const dias = Array.from({ length: 7 }, (_, i) => {
      const data = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + i);
      const lista = (aulas ?? []).filter((a) => a.diaSemana === diaDaSemana(data) && aulaValeNoDia(a, data)).sort((a, b) => a.inicioMin - b.inicioMin);
      return { data, lista };
    }).filter((d, i) => i === 0 || d.lista.length);

    remontar(tela.querySelector('.pilha'), html`
      ${cabecalho({ titulo: 'Horários', sub: dados ? rotuloAtualizado(dados.lidoEm, agora) : 'Semana', acoes: botaoRedondo('menu', 'Menu', 'menu') })}
      ${professor ? '' : await avisoSemEticket()}
      ${(await expirado(professor ? 'professor' : 'portal')) && !dados ? faixaExpirada('portal') : ''}
      ${falha ? faixaFalha(falha) : ''}
      ${!aulas
        ? html`<div class="cartao vidro">${carregando ? esqueleto(4) : vazio('horarios', 'Ainda não li seus horários', 'Puxe para baixo para tentar de novo.')}</div>`
        : dias.map(({ data, lista }) => html`
          <section class="cartao vidro dia ${diaDaSemana(data) === hoje && data.getDate() === agora.getDate() ? 'hoje' : ''}">
            <div class="nome"><span>${DIAS[diaDaSemana(data) - 1]}${data.getDate() === agora.getDate() ? ' · hoje' : `, ${data.getDate()}/${data.getMonth() + 1}`}</span></div>
            ${lista.length
              ? lista.map((a) => html`<div class="aula"><div class="hora">${formatarHoraMin(a.inicioMin)}<small>${formatarHoraMin(a.fimMin)}</small></div><div class="cresce forte">${a.disciplina}</div></div>`)
              : html`<div class="apoio">Sem aula hoje</div>`}
          </section>`)}
      ${aulas ? html`<div class="apoio" style="text-align:center">O portal não informa a sala das aulas.</div>` : ''}
    `);
  }

  montar(tela, html`<div class="pilha entra"></div>`);
  barraCompacta(tela, 'Horários');
  acoes.menu = () => ir('menu');
  acoes['entrar-portal'] = () => ir('login/portal');
  const tem = professor ? await ler('professor') : await ler('horarios');
  await desenhar(!tem);

  async function atualizar() {
    falha = '';
    try {
      await (professor ? atualizarProfessor() : atualizarHorarios());
      sincronizarAgenda().catch(() => {});
    } catch (e) {
      falha = fraseDeFalha(e, 'o Portal', (await ler(professor ? 'professor' : 'horarios'))?.lidoEm);
    }
    await desenhar();
  }
  puxarParaAtualizar(tela, atualizar);
  if (!tem) await atualizar();
}
