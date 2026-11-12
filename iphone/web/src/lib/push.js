// Notificações (no lugar das Live Activities). O Worker recebe só a inscrição e os horários;
// o texto de cada aviso é montado no próprio iPhone pelo service worker.
import { ler } from './armazenamento.js';
import { WORKER_URL } from './config.js';
import { aulaValeNoDia } from './dominio/academico.js';
import { atividadesDaSemana, planejarAvisos } from './dominio/classroom.js';
import { dataISO } from './dominio/formatos.js';
import { REFEICOES } from './dominio/refeicoes.js';
import { aulasDoProfessor, semChamada } from './dominio/professor.js';

const SEMANA = 7 * 1440;
export const ANTECEDENCIA_MIN = 15;

export const suportaPush = () => typeof window !== 'undefined' && 'PushManager' in window && 'serviceWorker' in navigator && 'Notification' in window;
export const instalado = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

export const PREFS_PADRAO = { tema: 'sistema', feriados: true, avisos: { aulas: false, refeicoes: [], classroom: false } };
export const lerPrefs = async () => ({ ...PREFS_PADRAO, ...((await ler('prefs')) ?? {}) });

/** Minuto local da semana (domingo 00:00 = 0) para minuto UTC, arredondado para baixo de 5 em 5 (o Cron). */
export function paraMinutoUtc(diaSemana, minutoDoDia, fusoMin = new Date().getTimezoneOffset()) {
  const local = (diaSemana % 7) * 1440 + minutoDoDia;
  const utc = (((local + fusoMin) % SEMANA) + SEMANA) % SEMANA;
  return utc - (utc % 5);
}

/** A agenda que vai para o Worker: só horários, tipo e uma referência curta. */
export function montarAgenda({ prefs, aulas = [], atividades = [], agora = new Date(), fusoMin } = {}) {
  const semanais = [];
  if (prefs.avisos.aulas) {
    for (const a of aulas) {
      // Só aulas do período atual ou futuro (o fim do semestre para os avisos).
      if (a.valeAte && !aulaValeNoDia({ ...a, valeDe: null }, agora)) continue;
      const m = paraMinutoUtc(a.diaSemana, a.inicioMin - ANTECEDENCIA_MIN, fusoMin);
      semanais.push({ m, t: 'aula', r: `${a.diaSemana}-${a.inicioMin}` });
    }
  }
  for (const id of prefs.avisos.refeicoes) {
    const r = REFEICOES.find((x) => x.id === id);
    if (!r) continue;
    for (let dia = 1; dia <= 5; dia++) semanais.push({ m: paraMinutoUtc(dia, r.inicioMin - ANTECEDENCIA_MIN, fusoMin), t: 'refeicao', r: r.id });
  }
  const unicos = prefs.avisos.classroom
    ? planejarAvisos(atividades, agora).map((a) => ({ em: Math.floor(a.quando.getTime() / 60000), t: 'classroom', r: dataISO(a.quando) }))
    : [];
  return { semanais, unicos };
}

function chaveParaBytes(b64url) {
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((b64url.length + 3) % 4);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

async function inscricaoAtual(criar) {
  const reg = await navigator.serviceWorker.ready;
  let sub = await reg.pushManager.getSubscription();
  if (!sub && criar) {
    const { chave } = await (await fetch(`${WORKER_URL}/push/chave`)).json();
    sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: chaveParaBytes(chave) });
  }
  return sub;
}

/** Pede a permissão (precisa de um toque da pessoa) e inscreve. */
export async function ativarPush() {
  if (!suportaPush()) throw new Error('Este navegador não recebe notificações. No iPhone, instale o app na Tela de Início.');
  const permissao = await Notification.requestPermission();
  if (permissao !== 'granted') throw new Error('As notificações estão bloqueadas. Libere em Ajustes › Notificações › UFAC+.');
  await inscricaoAtual(true);
  await sincronizarAgenda();
}

/** Manda a agenda atual ao Worker. Roda ao abrir o app e sempre que horários ou Classroom mudam. */
export async function sincronizarAgenda() {
  if (!suportaPush() || Notification.permission !== 'granted') return false;
  const sub = await inscricaoAtual(false);
  if (!sub) return false;
  const prefs = await lerPrefs();
  const perfil = await ler('perfil');
  const aulas = perfil === 'professor'
    ? aulasDoProfessor((await ler('professor'))?.turmas ?? [])
    : (await ler('horarios'))?.aulas ?? [];
  const atividades = (await ler('classroom'))?.atividades ?? [];
  const agenda = montarAgenda({ prefs, aulas, atividades });
  // Sem nenhum aviso ligado, a inscrição sai do Worker (a política de privacidade promete isso).
  if (!agenda.semanais.length && !agenda.unicos.length && !prefs.avisos.classroom) {
    await fetch(`${WORKER_URL}/push/cancelar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ endpoint: sub.endpoint }),
    }).catch(() => {});
    return true;
  }
  await fetch(`${WORKER_URL}/push/inscrever`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ inscricao: sub.toJSON(), agenda }),
  });
  return true;
}

export async function cancelarPush(sub) {
  await fetch(`${WORKER_URL}/push/cancelar`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ endpoint: sub.endpoint }),
  }).catch(() => {});
  await sub.unsubscribe().catch(() => {});
}

/** Selo com número no ícone: atividades do Classroom pendentes e chamadas atrasadas. */
export async function atualizarSelo() {
  if (!('setAppBadge' in navigator)) return;
  const agora = new Date();
  const atividades = atividadesDaSemana((await ler('classroom'))?.atividades ?? [], agora).length;
  const chamadas = ((await ler('professor'))?.turmas ?? []).reduce((n, t) => n + semChamada(t, agora).length, 0);
  const total = atividades + chamadas;
  try {
    if (total > 0) await navigator.setAppBadge(total);
    else await navigator.clearAppBadge();
  } catch {
    /* sem permissão de notificação, o iPhone ignora o selo */
  }
}
