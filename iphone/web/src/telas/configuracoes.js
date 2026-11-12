import { apagar, gravar, ler } from '../lib/armazenamento.js';
import { CONTATO_EMAIL, VERSAO } from '../lib/config.js';
import { classroomDisponivel, conectado as classroomConectado, desconectarClassroom } from '../lib/classroom.js';
import { ANTECEDENCIA_MIN, ativarPush, instalado, lerPrefs, sincronizarAgenda, suportaPush } from '../lib/push.js';
import { REFEICOES } from '../lib/dominio/refeicoes.js';
import { formatarHoraMin } from '../lib/dominio/formatos.js';
import { sair } from '../lib/sessao.js';
import { aplicarAparencia } from '../main.js';
import { avisar, botaoRedondo, cabecalho, confirmar, faixa, html, ic, item, montar, segmentos } from '../ui/componentes.js';
import { escolherFoto, fotoOuIniciais } from './comum.js';
import { iniciais } from '../lib/dominio/academico.js';

const interruptor = (id, ligado, rotulo, sub = '') => html`
  <label class="item" style="cursor:pointer">
    <span class="cresce"><span class="titulo">${rotulo}</span>${sub ? html`<span class="apoio" style="display:block">${sub}</span>` : ''}</span>
    <input type="checkbox" class="interruptor" data-chave="${id}" ${ligado ? html`checked` : ''}>
  </label>`;

/** Texto do relato: só versão, aparelho e tela. Nunca CPF, matrícula, QR, notas ou cookies. */
export function textoRelato(tela = 'Configurações') {
  const ios = /OS (\d+[._]\d+)/.exec(navigator.userAgent)?.[1]?.replace('_', '.') ?? 'desconhecido';
  return `UFAC+ ${VERSAO} (iPhone/PWA)\niOS ${ios}\nTela: ${tela}\n\nO que aconteceu?\n`;
}

export default async function configuracoes(tela, { voltar, ir, perfil, acoes }) {
  async function desenhar() {
    const prefs = await lerPrefs();
    const temFoto = !!(await ler('foto'));
    const ident = await ler('identificacao');
    const pushOk = suportaPush() && instalado();
    const permitido = pushOk && Notification.permission === 'granted';
    montar(tela.querySelector('.pilha'), html`
      ${cabecalho({ titulo: 'Configurações', acoes: botaoRedondo('voltar', 'Voltar', 'voltar') })}

      ${perfil !== 'professor' ? html`<section class="cartao vidro"><div class="linha">
        <div class="avatar">${await fotoOuIniciais(ident ? iniciais(ident.nome) : '')}</div>
        <div class="cresce"><div class="forte">Foto de perfil</div><div class="apoio">Fica só neste iPhone</div></div>
        <button class="botao claro tocavel" data-acao="foto">Trocar</button>
      </div>${temFoto ? html`<button class="botao perigo largo tocavel" style="margin-top:12px;min-height:40px" data-acao="remover-foto">Remover foto</button>` : ''}</section>` : ''}

      <section class="cartao vidro"><h2>Aparência</h2>
        ${segmentos([{ id: 'sistema', nome: 'Sistema' }, { id: 'claro', nome: 'Claro' }, { id: 'escuro', nome: 'Escuro' }], prefs.tema, 'tema')}
      </section>

      <section class="cartao vidro lista" style="padding:4px 0">
        <div style="padding:10px 16px 0"><h2 style="margin:0">Avisos</h2></div>
        ${interruptor('feriados', prefs.feriados, 'Avisar sobre feriados', 'Na véspera, na tela Início')}
      </section>

      <section class="cartao vidro lista" style="padding:4px 0">
        <div style="padding:10px 16px 0"><h2 style="margin:0">Notificações</h2><div class="apoio">No lugar das Live Activities, que não existem para apps da web.</div></div>
        ${!pushOk
          ? html`<div style="padding:12px 16px">${faixa({ icone: 'celular', titulo: 'Instale o app na Tela de Início', texto: 'O iPhone só manda notificações para apps instalados (iOS 16.4 ou mais novo).' })}<a class="botao claro largo tocavel" style="margin-top:10px" href="/instalar/">Como instalar</a></div>`
          : html`
            ${!permitido ? html`<div style="padding:12px 16px"><button class="botao largo tocavel" data-acao="permitir">${ic('sino')} Permitir notificações</button></div>` : ''}
            ${interruptor('aulas', prefs.avisos.aulas, 'Próxima aula', `${ANTECEDENCIA_MIN} min antes de cada aula`)}
            ${perfil !== 'professor' ? REFEICOES.map((r) => interruptor(`refeicao:${r.id}`, prefs.avisos.refeicoes.includes(r.id), r.nome, `${ANTECEDENCIA_MIN} min antes das ${formatarHoraMin(r.inicioMin)}, de segunda a sexta`)) : ''}
            ${classroomDisponivel() ? interruptor('classroom', prefs.avisos.classroom, 'Atividades do Classroom', 'Às 19h, com o que vence até o dia seguinte') : ''}`}
      </section>

      <section class="cartao vidro lista" style="padding:4px 0">
        ${classroomConectado() ? item({ icone: 'quadro', titulo: 'Desconectar o Classroom', sub: 'Tira o acesso do app à sua conta do Google', acao: 'desconectar-classroom' }) : ''}
        ${item({ icone: 'info', titulo: 'Relatar um problema', sub: CONTATO_EMAIL ? 'Por e-mail, você revisa antes de enviar' : 'Contato ainda não configurado', acao: CONTATO_EMAIL ? 'relatar' : '' })}
        ${item({ icone: 'atualizar', titulo: 'Limpar dados salvos', sub: 'Lê tudo de novo da Ufac; não sai da conta', acao: 'limpar' })}
        ${item({ icone: 'cadeado', titulo: 'Privacidade', href: '/privacidade/' })}
        ${item({ icone: 'celular', titulo: 'Como instalar no iPhone', href: '/instalar/' })}
        ${item({ icone: 'escola', titulo: 'Sobre o UFAC+', sub: `Versão ${VERSAO} · App independente, feito por um aluno. Não é um aplicativo oficial da Ufac.` })}
      </section>
      <button class="botao perigo largo tocavel" data-acao="sair">${ic('sair')} Sair da conta</button>
    `);
  }

  montar(tela, html`<div class="pilha entra"></div>`);
  await desenhar();

  async function mudarPrefs(fn) {
    const p = await lerPrefs();
    fn(p);
    await gravar('prefs', p);
    return p;
  }

  tela.addEventListener('change', async (e) => {
    const chave = e.target.dataset?.chave;
    if (!chave) return;
    const ligado = e.target.checked;
    await mudarPrefs((p) => {
      if (chave === 'feriados') p.feriados = ligado;
      else if (chave === 'aulas') p.avisos.aulas = ligado;
      else if (chave === 'classroom') p.avisos.classroom = ligado;
      else if (chave.startsWith('refeicao:')) {
        const id = chave.split(':')[1];
        p.avisos.refeicoes = ligado ? [...new Set([...p.avisos.refeicoes, id])] : p.avisos.refeicoes.filter((x) => x !== id);
      }
    });
    if (chave === 'feriados') return;
    try {
      if (ligado && Notification.permission !== 'granted') await ativarPush();
      else await sincronizarAgenda();
      if (ligado) avisar('Aviso ligado.');
    } catch (falha) {
      avisar(falha.message);
      e.target.checked = false;
      await mudarPrefs((p) => {
        if (chave === 'aulas') p.avisos.aulas = false;
        else if (chave === 'classroom') p.avisos.classroom = false;
        else p.avisos.refeicoes = p.avisos.refeicoes.filter((x) => `refeicao:${x}` !== chave);
      });
    }
  });

  acoes.voltar = voltar;
  acoes.permitir = async () => {
    try {
      await ativarPush();
      avisar('Notificações liberadas. Escolha os avisos abaixo.');
    } catch (falha) {
      avisar(falha.message);
    }
    desenhar();
  };
  acoes.tema = async (el) => {
    await mudarPrefs((p) => (p.tema = el.dataset.valor));
    await aplicarAparencia();
    desenhar();
  };
  acoes.foto = async () => (await escolherFoto()) && desenhar();
  acoes['remover-foto'] = async () => {
    await apagar('foto');
    desenhar();
  };
  acoes.relatar = () => {
    location.href = `mailto:${CONTATO_EMAIL}?subject=${encodeURIComponent('UFAC+ iPhone: problema')}&body=${encodeURIComponent(textoRelato())}`;
  };
  acoes.limpar = async () => {
    const ok = await confirmar({ titulo: 'Limpar dados salvos?', texto: 'Apaga notas, horários, saldo e cardápio deste iPhone. Você continua na conta e tudo é lido de novo da Ufac.', sim: 'Limpar' });
    if (!ok) return;
    for (const k of ['ru', 'cardapio', 'identificacao', 'horarios', 'notas', 'historico', 'classroom', 'professor', 'idInterno', 'urlMaisRelatorios', 'urlComunicacoes']) await apagar(k);
    avisar('Dados apagados. Tudo será lido de novo.');
  };
  acoes['desconectar-classroom'] = async () => {
    const ok = await confirmar({ titulo: 'Desconectar o Classroom?', texto: 'O app perde o acesso à sua conta do Google e apaga as atividades deste iPhone.', sim: 'Desconectar', perigo: true });
    if (!ok) return;
    const revogado = await desconectarClassroom();
    avisar(revogado ? 'Classroom desconectado.' : 'Apaguei o acesso deste iPhone, mas o Google não respondeu. Para garantir: myaccount.google.com › Segurança › Apps de terceiros.');
    desenhar();
  };
  acoes.sair = async () => {
    const ok = await confirmar({ titulo: 'Sair da conta?', texto: 'Apaga a sessão, os dados salvos, o QR do RU e a foto deste iPhone.', sim: 'Sair', perigo: true });
    if (!ok) return;
    await sair();
    ir('boas-vindas', { substituir: true });
  };
}
