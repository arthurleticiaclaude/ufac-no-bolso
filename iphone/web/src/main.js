import './css/tokens.css';
import './css/vidro.css';
import './css/app.css';
import { aoMudarSessao } from './lib/api.js';
import { ler } from './lib/armazenamento.js';
import { atualizarSelo, lerPrefs, sincronizarAgenda } from './lib/push.js';
import { loginConcluido } from './lib/sessao.js';
import { avisar, html, ic, montar } from './ui/componentes.js';
import { concluirRetornoDoGoogle } from './lib/classroom.js';
import { registrar } from './lib/registro.js';
import { URL_PORTAL_ALUNO, URL_PORTAL_PROFESSOR } from './lib/config.js';

const ABAS = {
  aluno: [
    ['inicio', 'Início', 'inicio'],
    ['horarios', 'Horários', 'horarios'],
    ['notas', 'Notas', 'notas'],
    ['relatorios', 'Relatórios', 'relatorios'],
    ['ru', 'RU', 'ru'],
  ],
  professor: [
    ['inicio', 'Início', 'inicio'],
    ['turmas', 'Turmas', 'grupo'],
    ['horarios', 'Horários', 'horarios'],
  ],
};

const TELAS = {
  'boas-vindas': () => import('./telas/boasVindas.js'),
  login: () => import('./telas/login.js'),
  inicio: async () => ((await ler('perfil')) === 'professor' ? import('./telas/professor.js').then((m) => m.inicio) : import('./telas/inicio.js')),
  horarios: () => import('./telas/horarios.js'),
  notas: () => import('./telas/notas.js'),
  relatorios: () => import('./telas/relatorios.js'),
  ru: () => import('./telas/ru.js'),
  turmas: () => import('./telas/professor.js').then((m) => m.turmas),
  turma: () => import('./telas/professor.js').then((m) => m.turma),
  menu: () => import('./telas/menu.js'),
  configuracoes: () => import('./telas/configuracoes.js'),
  historico: () => import('./telas/historico.js'),
  relatar: () => import('./telas/relatar.js'),
};

const app = document.getElementById('app');
let ultimaAtualizacao = 0;
let telaAtual = null;

export async function aplicarAparencia() {
  const prefs = await lerPrefs();
  const perfil = (await ler('perfil')) ?? 'aluno';
  const raiz = document.documentElement;
  raiz.dataset.perfil = perfil;
  if (prefs.tema === 'claro' || prefs.tema === 'escuro') raiz.dataset.tema = prefs.tema;
  else delete raiz.dataset.tema;
  const escuro = prefs.tema === 'escuro' || (prefs.tema !== 'claro' && matchMedia('(prefers-color-scheme: dark)').matches);
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', escuro ? '#000000' : '#f3f5f9');
}

function rotaAtual() {
  const [nome, ...resto] = location.hash.replace(/^#\/?/, '').split('/');
  return { nome: nome || 'inicio', parametro: resto.join('/') };
}

export function ir(rota, { substituir = false } = {}) {
  const alvo = `#/${rota}`;
  if (location.hash === alvo) return renderizar();
  if (substituir) history.replaceState(null, '', alvo);
  else history.pushState(null, '', alvo);
  renderizar(); // pushState não dispara hashchange
}

export const voltar = () => (history.length > 1 ? history.back() : ir('inicio'));

async function barraDeAbas(perfil, nome) {
  const abas = ABAS[perfil];
  const i = abas.findIndex(([id]) => id === nome);
  let barra = document.querySelector('.abas');
  if (i < 0) {
    barra?.remove();
    return;
  }
  if (!barra || barra.dataset.perfil !== perfil) {
    barra?.remove();
    barra = document.createElement('nav');
    barra.className = 'abas vidro forte';
    barra.dataset.perfil = perfil;
    barra.setAttribute('aria-label', 'Seções');
    barra.style.setProperty('--n', abas.length);
    montar(barra, html`<span class="lente"></span>${abas.map(([id, rotulo, icone]) => html`<a class="aba tocavel" href="#/${id}" data-aba="${id}">${ic(icone)}<span>${rotulo}</span></a>`)}`);
    document.body.append(barra);
  }
  barra.style.setProperty('--i', i);
  barra.querySelectorAll('.aba').forEach((a) => (a.dataset.aba === nome ? a.setAttribute('aria-current', 'page') : a.removeAttribute('aria-current')));
}

let geracao = 0;

async function renderizar() {
  const minha = ++geracao;
  let { nome, parametro } = rotaAtual();
  const logado = await loginConcluido();
  const perfil = (await ler('perfil')) ?? 'aluno';
  if (!logado && nome !== 'login' && nome !== 'relatar') nome = 'boas-vindas';
  if (logado && (nome === 'boas-vindas' || !TELAS[nome])) nome = 'inicio';
  if (perfil === 'professor' && ['notas', 'relatorios', 'ru'].includes(nome)) nome = 'inicio';
  await aplicarAparencia();

  const modulo = await TELAS[nome]();
  if (minha !== geracao) return; // outra navegação começou enquanto esta carregava
  const tela = document.createElement('main');
  tela.className = 'tela';
  tela.dataset.tela = nome;
  const comAbas = ABAS[perfil].some(([id]) => id === nome) && logado;
  if (!comAbas) tela.classList.add('sem-abas');

  const ctx = { ir, voltar, parametro, perfil, renderizar };
  // Cada tela liga os próprios botões por data-acao.
  const acoes = {};
  // Valem em qualquer tela (faixas de erro, login), a menos que a tela tenha a sua.
  const globais = {
    relatar: () => ir(`relatar/${encodeURIComponent(nome)}`),
    // A troca de senha é no site oficial, no Safari: o app nunca recebe a senha nova antes do login.
    'trocar-senha-portal': () => window.open(perfil === 'professor' ? URL_PORTAL_PROFESSOR : URL_PORTAL_ALUNO, '_blank', 'noopener'),
  };
  tela.addEventListener('click', (e) => {
    const alvo = e.target.closest('[data-acao]');
    // "relatar" funciona em qualquer tela (faixas de erro, login): abre o relato dizendo de onde veio.
    const acao = alvo && (acoes[alvo.dataset.acao] ?? globais[alvo.dataset.acao]);
    if (acao) {
      e.preventDefault();
      acao(alvo, e);
    }
  });
  ctx.acoes = acoes;

  // Sem piscar: a tela nova monta escondida, por baixo da antiga, e só troca quando já tem conteúdo
  // (o primeiro cartão ou cabeçalho), ou depois de 300 ms. A animação de entrada é em CSS (.entra).
  tela.style.visibility = 'hidden';
  app.append(tela);
  const temConteudo = () => !!tela.querySelector('.cabecalho, .cartao, form, h1');
  const pronta = new Promise((ok) => {
    if (temConteudo()) return ok();
    const olhar = new MutationObserver(() => temConteudo() && (olhar.disconnect(), ok()));
    olhar.observe(tela, { childList: true, subtree: true });
    setTimeout(() => (olhar.disconnect(), ok()), 300);
  });
  const execucao = Promise.resolve((modulo.default ?? modulo)(tela, ctx));
  await pronta;
  if (minha !== geracao) {
    tela.remove(); // outra navegação já assumiu
    return;
  }
  telaAtual?.remove();
  tela.style.visibility = '';
  telaAtual = tela;
  barraDeAbas(perfil, comAbas ? nome : '');
  // A animação de entrada vale só para a chegada na tela: atualizações não fazem os cartões piscarem.
  setTimeout(() => tela.querySelectorAll('.entra').forEach((e) => e.classList.remove('entra')), 650);
  await execucao;
  ultimaAtualizacao = Date.now();
}

// Erros do próprio app vão para o registro do "Relatar um problema" (só a mensagem e onde, anonimizadas).
const ondeNoCodigo = (pilha) => String(pilha ?? '').split('\n').slice(0, 3).map((l) => l.replace(/https?:\/\/[^/]+/g, '').trim()).join(' < ');
window.addEventListener('error', (e) => registrar('app', { erro: e.message, onde: ondeNoCodigo(e.error?.stack) || `${e.filename?.replace(/https?:\/\/[^/]+/, '')}:${e.lineno}`, tela: rotaAtual().nome }));
window.addEventListener('unhandledrejection', (e) => registrar('app', { erro: e.reason?.message ?? String(e.reason), onde: ondeNoCodigo(e.reason?.stack), tela: rotaAtual().nome }));

// Ao voltar para o app: atualiza no máximo a cada 15 minutos (regra de respeito à Ufac).
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && Date.now() - ultimaAtualizacao > 15 * 60 * 1000) renderizar();
});
// Toque nas abas (<a href="#/...">) e o voltar do iPhone mudam o hash.
window.addEventListener('hashchange', renderizar);
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', aplicarAparencia);
aoMudarSessao(() => telaAtual?.dispatchEvent(new CustomEvent('sessao')));

/**
 * iOS 26: no app instalado, a área do app termina acima do fim da tela (medido no iPhone 15 Pro Max: tela 932,
 * área 873; faltam os 59 pt da Dynamic Island). Bug do WebKit: não dá para desenhar ali. Mede a diferença e passa
 * para o CSS (--falta), que deixa de reservar a barrinha de início (--inset-baixo em app.css).
 */
function medirFalta() {
  // navigator.standalone só existe no iOS: no Android e no computador a diferença é das barras do sistema.
  const instalado = navigator.standalone === true;
  const digitando = document.activeElement?.matches?.('input, textarea, select');
  if (digitando) return;
  const retrato = matchMedia('(orientation: portrait)').matches;
  const alturaTela = retrato ? Math.max(screen.width, screen.height) : Math.min(screen.width, screen.height);
  const larguraTela = retrato ? Math.min(screen.width, screen.height) : Math.max(screen.width, screen.height);
  const telaInteira = Math.abs(window.innerWidth - larguraTela) < 2; // iPad em janela (Stage Manager) não conta
  const falta = instalado && telaInteira ? alturaTela - window.innerHeight : 0;
  document.documentElement.style.setProperty('--falta', `${falta > 0 && falta <= 140 ? falta : 0}px`);
}
medirFalta();
// O iOS ajusta a área do app logo depois de abrir: mede de novo quando assenta.
setTimeout(medirFalta, 600);
setTimeout(medirFalta, 2000);
const remedir = () => setTimeout(medirFalta, 150);
window.addEventListener('resize', remedir);
window.visualViewport?.addEventListener('resize', remedir);
window.addEventListener('pageshow', remedir);
document.addEventListener('focusout', () => setTimeout(medirFalta, 400)); // teclado fechou
document.addEventListener('visibilitychange', () => document.visibilityState === 'visible' && remedir());

async function iniciar() {
  if (import.meta.env.PROD && 'serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').then((reg) => {
      // O iPhone deixa o app aberto em segundo plano por dias: confere versão nova ao voltar para ele.
      document.addEventListener('visibilitychange', () => document.visibilityState === 'visible' && reg.update().catch(() => {}));
    }).catch(() => {});
    // Versão nova ativada: recarrega para usá-la já (menos no meio do login, para não perder o que foi digitado).
    let tinhaVersao = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (tinhaVersao && !location.hash.startsWith('#/login')) location.reload();
      tinhaVersao = true;
    });
  }
  // Volta do Google (Classroom): termina a conexão antes de desenhar a Início.
  const retorno = await concluirRetornoDoGoogle().catch((e) => ({ erro: e }));
  await renderizar();
  if (retorno?.erro) avisar(retorno.erro.message);
  else if (retorno?.ok) avisar('Classroom conectado.');
  if (await loginConcluido()) {
    sincronizarAgenda().catch(() => {});
    atualizarSelo().catch(() => {});
  }
}

iniciar();
