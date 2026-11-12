// Perfil professor: leitura das turmas, horários e chamadas pendentes.
// Chamada e notas abrem a página oficial no Safari (o app nunca lança nada).
import { ler } from '../lib/armazenamento.js';
import { atualizarProfessor } from '../lib/dados.js';
import { oficial } from '../lib/config.js';
import { primeiroNome, proximaAula } from '../lib/dominio/academico.js';
import { avisoFeriado } from '../lib/dominio/feriados.js';
import { DIAS, deDataISO, formatarData, formatarHoraMin, rotuloAtualizado } from '../lib/dominio/formatos.js';
import { aulasDoProfessor, lancamentoNotasAberto, semChamada } from '../lib/dominio/professor.js';
import { atualizarSelo, lerPrefs, sincronizarAgenda } from '../lib/push.js';
import { barraCompacta, botaoRedondo, cabecalho, esqueleto, faixa, html, ic, montar, remontar, puxarParaAtualizar, vazio } from '../ui/componentes.js';
import { expirado, faixaExpirada, faixaFalha, fraseDeFalha } from './comum.js';

const diaCurto = (iso) => {
  const d = deDataISO(iso);
  return `${DIAS[(d.getDay() || 7) - 1].slice(0, 3).toLowerCase()}, ${d.getDate()}/${d.getMonth() + 1}`;
};

async function carregar(tela, desenhar) {
  let falha = '';
  const tem = await ler('professor');
  const atualizar = async () => {
    falha = '';
    try {
      await atualizarProfessor();
      sincronizarAgenda().catch(() => {});
      atualizarSelo();
    } catch (e) {
      falha = fraseDeFalha(e, 'o Portal do Professor', (await ler('professor'))?.lidoEm);
    }
    await desenhar(falha);
  };
  await desenhar('', !tem);
  puxarParaAtualizar(tela, atualizar);
  if (!tem || Date.now() - new Date(tem.lidoEm).getTime() > 15 * 60 * 1000) await atualizar();
}

export async function inicio(tela, { ir, acoes }) {
  montar(tela, html`<div class="pilha entra"></div>`);
  barraCompacta(tela, 'Início');
  acoes.menu = () => ir('menu');
  acoes.avisos = () => ir('configuracoes');
  acoes['entrar-portal'] = () => ir('login/portal');
  acoes.turma = (el) => ir(`turma/${el.dataset.valor}`);

  await carregar(tela, async (falha, carregando) => {
    const agora = new Date();
    const p = await ler('professor');
    const prefs = await lerPrefs();
    const feriado = prefs.feriados ? avisoFeriado(agora) : null;
    const aula = p ? proximaAula(aulasDoProfessor(p.turmas), agora) : null;
    const pendentes = (p?.turmas ?? []).flatMap((t) => semChamada(t, agora).map((a) => ({ t, a })));
    const notasAbertas = (p?.turmas ?? []).filter((t) => lancamentoNotasAberto(t.turma));
    remontar(tela.querySelector('.pilha'), html`
      ${cabecalho({ sobre: formatarData(agora), titulo: p?.nome ? `Olá, ${primeiroNome(p.nome)}` : 'Olá', acoes: html`${botaoRedondo('sino', 'Avisos', 'avisos')}${botaoRedondo('menu', 'Menu', 'menu')}` })}
      ${feriado ? faixa({ icone: 'calendario', titulo: feriado.titulo, texto: feriado.texto }) : ''}
      ${(await expirado('professor')) ? faixaExpirada('portal') : ''}
      ${falha ? faixaFalha(falha) : ''}
      <section class="cartao vidro">
        <div class="rotulo" style="margin-bottom:6px">Próxima aula</div>
        ${aula ? html`<span class="selo">${aula.rotulo}</span><div class="forte" style="font-size:17px;margin-top:8px">${aula.aula.disciplina}</div><div class="apoio">${formatarHoraMin(aula.aula.inicioMin)} – ${formatarHoraMin(aula.aula.fimMin)}</div>`
          : carregando ? esqueleto(2) : vazio('horarios', 'Sem aula nos próximos dias')}
      </section>
      <section class="cartao vidro">
        <h2>Chamadas pendentes</h2>
        ${pendentes.length
          ? html`<div class="lista" style="margin:0 -16px">${pendentes.map(({ t, a }) => html`
              <a class="item tocavel" href="${a.idAgenda ? oficial.professorChamada(a.idAgenda) : oficial.professorAgenda(t.turma.id)}" target="_blank" rel="noopener">
                <span class="icone perigo">${ic('alerta')}</span>
                <span class="cresce"><span class="titulo">${t.turma.disciplina}</span><span class="apoio" style="display:block">${diaCurto(a.data)} · ${formatarHoraMin(a.inicioMin)} · abrir chamada no portal</span></span>
                <span class="seta">${ic('abrir')}</span>
              </a>`)}</div>`
          : carregando ? esqueleto(2) : vazio('check', 'Nenhuma chamada atrasada neste mês')}
      </section>
      ${notasAbertas.map((t) => html`<a class="cartao vidro item tocavel" href="${oficial.professorQuadroNotas(t.turma.id)}" target="_blank" rel="noopener"><span class="icone">${ic('notas')}</span><span class="cresce titulo">${t.turma.disciplina}: lançamento de notas aberto</span><span class="seta">${ic('abrir')}</span></a>`)}
      ${p ? html`<div class="apoio" style="text-align:center">${rotuloAtualizado(p.lidoEm, agora)} · Chamada e notas abrem no site oficial.</div>` : ''}
    `);
  });
}

export async function turmas(tela, { ir, acoes }) {
  montar(tela, html`<div class="pilha entra"></div>`);
  barraCompacta(tela, 'Turmas');
  acoes.menu = () => ir('menu');
  acoes.turma = (el) => ir(`turma/${el.dataset.valor}`);
  await carregar(tela, async (falha, carregando) => {
    const p = await ler('professor');
    remontar(tela.querySelector('.pilha'), html`
      ${cabecalho({ titulo: 'Turmas', sub: p?.semestre ?? '', acoes: botaoRedondo('menu', 'Menu', 'menu') })}
      ${falha ? faixaFalha(falha) : ''}
      ${!p ? html`<div class="cartao vidro">${carregando ? esqueleto(4) : vazio('grupo', 'Ainda não li suas turmas')}</div>`
        : !p.turmas.length ? html`<div class="cartao vidro">${vazio('grupo', 'Nenhuma turma neste semestre')}</div>`
        : p.turmas.map((t) => html`
          <button class="cartao vidro tocavel" style="text-align:left;width:100%" data-acao="turma" data-valor="${t.turma.id}">
            <div class="linha"><div class="cresce forte" style="font-size:16px">${t.turma.disciplina}</div><span class="seta">${ic('seta')}</span></div>
            <div class="apoio">${t.turma.nome}${t.turma.codigo ? ` · ${t.turma.codigo}` : ''}</div>
            <div class="linha" style="margin-top:8px;flex-wrap:wrap;gap:6px">
              ${t.turma.situacaoFrequencia ? html`<span class="selo neutro">${t.turma.situacaoFrequencia}</span>` : ''}
              ${lancamentoNotasAberto(t.turma) ? html`<span class="selo">Notas abertas</span>` : ''}
            </div>
          </button>`)}`);
  });
}

export async function turma(tela, { parametro, voltar, acoes }) {
  const p = await ler('professor');
  const t = p?.turmas.find((x) => x.turma.id === parametro);
  acoes.voltar = voltar;
  if (!t) {
    montar(tela, html`<div class="pilha">${cabecalho({ titulo: 'Turma', acoes: botaoRedondo('voltar', 'Voltar', 'voltar') })}<div class="cartao vidro">${vazio('grupo', 'Turma não encontrada')}</div></div>`);
    return;
  }
  const d = t.detalhe;
  const agora = new Date();
  montar(tela, html`<div class="pilha entra">
    ${cabecalho({ titulo: t.turma.disciplina, sub: `${t.turma.nome}${d?.curso ? ` · ${d.curso}` : ''}`, acoes: botaoRedondo('voltar', 'Voltar', 'voltar') })}
    <div class="par-botoes" style="margin:0">
      <a class="botao tocavel" href="${oficial.professorAgenda(t.turma.id)}" target="_blank" rel="noopener">${ic('calendario')} Agenda</a>
      <a class="botao claro tocavel" href="${oficial.professorQuadroNotas(t.turma.id)}" target="_blank" rel="noopener">${ic('notas')} Notas</a>
    </div>
    ${d ? html`<section class="cartao vidro"><div class="grade3" style="margin:0">
      <div><div class="rotulo">Matrículas</div><div class="valor">${d.matriculas ?? '—'}</div></div>
      <div><div class="rotulo">Vagas</div><div class="valor">${d.vagas ?? '—'}</div></div>
      <div><div class="rotulo">CH feita</div><div class="valor">${d.cargaHorariaRealizada != null ? `${d.cargaHorariaRealizada}h` : '—'}</div></div>
    </div></section>` : ''}
    <section class="cartao vidro"><h2>Horários</h2>
      ${d?.horarios.length ? d.horarios.map((h) => html`<div class="aula"><div class="hora">${formatarHoraMin(h.inicioMin)}<small>${formatarHoraMin(h.fimMin)}</small></div><div class="cresce"><div class="forte">${DIAS[h.diaSemana - 1]}</div><div class="apoio">${h.tipo ?? ''}</div></div></div>`) : vazio('horarios', 'Sem horários informados')}
    </section>
    <section class="cartao vidro"><h2>Aulas deste mês</h2>
      ${t.aulasDoMes?.length ? html`<div class="lista" style="margin:0 -16px">${t.aulasDoMes.map((a) => html`
        <a class="item tocavel" href="${a.idAgenda ? oficial.professorChamada(a.idAgenda) : oficial.professorAgenda(t.turma.id)}" target="_blank" rel="noopener">
          <span class="icone ${a.chamadaLancada ? 'verde' : deDataISO(a.data) <= agora ? 'perigo' : ''}">${ic(a.chamadaLancada ? 'check' : 'calendario')}</span>
          <span class="cresce"><span class="titulo">${diaCurto(a.data)} · ${formatarHoraMin(a.inicioMin)}</span><span class="apoio" style="display:block">${a.chamadaLancada ? 'Chamada feita' : 'Chamada não lançada'}${a.conteudo ? ` · ${a.conteudo}` : ''}</span></span>
          <span class="seta">${ic('abrir')}</span>
        </a>`)}</div>` : vazio('calendario', 'Sem aulas na agenda deste mês')}
    </section>
    ${d?.modeloNotas.length ? html`<section class="cartao vidro"><h2>Avaliações</h2>${d.modeloNotas.map((g) => html`<div style="margin-bottom:8px"><div class="forte">${g.rotulo} · peso ${g.peso}</div>${g.avaliacoes.map((a) => html`<div class="apoio">${a.nome} (${a.codigo}) · ${a.peso}</div>`)}</div>`)}</section>` : ''}
    ${d?.docentes.length ? html`<section class="cartao vidro"><h2>Docentes</h2>${d.docentes.map(([nome, papel]) => html`<div class="linha" style="padding:4px 0"><span class="cresce">${nome}</span><span class="apoio">${papel}</span></div>`)}</section>` : ''}
    <div class="apoio" style="text-align:center">Agenda, chamada e notas abrem no site oficial (Safari), onde o portal pede login.</div>
  </div>`);
}
