// Google Classroom só leitura. A pessoa autoriza uma vez (fluxo de código com PKCE, por redirecionamento,
// que funciona no app instalado melhor que janela pop-up). O Worker troca o código usando o client secret e
// devolve a autorização de longa duração CIFRADA: ela fica só neste iPhone e o Worker não guarda nada.
// As leituras do Classroom vão do iPhone direto para o Google.
import { apagar, gravar, ler } from './armazenamento.js';
import { comLimite, LIMITE_PADRAO } from './api.js';
import { GOOGLE_CLIENT_ID, WORKER_URL } from './config.js';
import { ESCOPOS, lerAtividade, lerTurma, ordenarPorPrazo } from './dominio/classroom.js';

const AUTORIZAR = 'https://accounts.google.com/o/oauth2/v2/auth';
let token = null;
let expira = 0;
let temCofre = false;

export const classroomDisponivel = () => !!GOOGLE_CLIENT_ID;
/** Já autorizou neste iPhone (não precisa tocar em "Conectar"). */
export const conectado = () => temCofre;

export class ErroClassroom extends Error {
  constructor(mensagem, { pedirLogin = false } = {}) {
    super(mensagem);
    this.pedirLogin = pedirLogin;
  }
}

const base64Url = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const aleatorio = () => base64Url(crypto.getRandomValues(new Uint8Array(32)));
const redirecionamento = () => `${location.origin}/`;

/** Leva ao Google. Volta para a raiz do app com ?code=…&state=… (tratado por concluirRetornoDoGoogle). */
export async function conectar() {
  if (!classroomDisponivel()) throw new ErroClassroom('O Classroom ainda não foi configurado neste app.');
  const verifier = aleatorio();
  const state = aleatorio();
  const desafio = base64Url(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))));
  await gravar('googlePendente', { state, verifier, em: Date.now() });
  const url = new URL(AUTORIZAR);
  Object.entries({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: redirecionamento(),
    response_type: 'code',
    scope: ESCOPOS.join(' '),
    access_type: 'offline',
    prompt: 'consent', // garante a autorização de longa duração
    include_granted_scopes: 'false',
    code_challenge: desafio,
    code_challenge_method: 'S256',
    state,
  }).forEach(([k, v]) => url.searchParams.set(k, v));
  location.assign(url.toString());
}

export function traduzirErroLogin(codigo) {
  const t = String(codigo).toLowerCase();
  if (t.includes('admin_policy') || t.includes('org_internal') || t.includes('policy')) {
    return new ErroClassroom('A Ufac bloqueou apps externos na conta do Google. Dá para abrir o Classroom pelo app oficial.');
  }
  if (t.includes('access_denied')) return new ErroClassroom('Você não autorizou o acesso ao Classroom.');
  if (t.includes('nao_configurado')) return new ErroClassroom('O Classroom ainda não foi configurado no servidor do app.');
  return new ErroClassroom('Não consegui entrar no Google agora. Tente de novo.');
}

async function postarNoWorker(caminho, corpo) {
  let r;
  try {
    r = await fetch(`${WORKER_URL}${caminho}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(corpo), cache: 'no-store', signal: comLimite(LIMITE_PADRAO) });
  } catch {
    throw new ErroClassroom('Sem conexão agora. Tente de novo.');
  }
  const j = await r.json().catch(() => ({}));
  return { ok: r.ok, j };
}

/**
 * Chamada uma vez na abertura do app. Se a URL veio do Google, termina a conexão e limpa a URL.
 * Devolve null (nada a fazer), { ok: true } ou { erro: ErroClassroom }.
 */
export async function concluirRetornoDoGoogle() {
  temCofre = !!(await ler('classroomCofre'));
  const p = new URLSearchParams(location.search);
  if (!p.has('state') || (!p.has('code') && !p.has('error'))) return null;
  history.replaceState(null, '', '/#/inicio');
  const pendente = await ler('googlePendente');
  await apagar('googlePendente');
  if (!pendente || pendente.state !== p.get('state') || Date.now() - pendente.em > 15 * 60 * 1000) {
    return { erro: new ErroClassroom('A conexão com o Google não bateu. Tente conectar de novo.') };
  }
  if (p.has('error')) return { erro: traduzirErroLogin(p.get('error')) };
  let resposta;
  try {
    resposta = await postarNoWorker('/google/trocar', { code: p.get('code'), verifier: pendente.verifier, redirect: redirecionamento() });
  } catch (e) {
    return { erro: e }; // sem rede na volta: avisa em vez de sumir calado
  }
  const { ok, j } = resposta;
  if (!ok || !j.cofre) return { erro: traduzirErroLogin(j.erro ?? '') };
  await gravar('classroomCofre', j.cofre);
  temCofre = true;
  token = j.access_token;
  expira = Date.now() + Number(j.expires_in ?? 3600) * 1000;
  return { ok: true };
}

async function esquecer() {
  token = null;
  temCofre = false;
  await apagar('classroomCofre');
}

async function garantirToken() {
  if (token && Date.now() < expira - 60000) return token;
  const cofre = await ler('classroomCofre');
  if (!cofre) throw new ErroClassroom('Conecte o Classroom para ver as atividades.', { pedirLogin: true });
  const { ok, j } = await postarNoWorker('/google/renovar', { cofre });
  if (!ok) {
    if (j.erro === 'invalid_grant' || j.erro === 'cofre_invalido') {
      await esquecer();
      throw new ErroClassroom('O acesso ao Classroom foi encerrado. Toque para conectar de novo.', { pedirLogin: true });
    }
    throw new ErroClassroom('O Google não respondeu agora. Mostrando as atividades salvas.');
  }
  token = j.access_token;
  expira = Date.now() + Number(j.expires_in ?? 3600) * 1000;
  return token;
}

async function pedirApi(caminho, filtros = {}, tentativa = 0) {
  const url = new URL(`https://classroom.googleapis.com${caminho}`);
  Object.entries(filtros).forEach(([k, v]) => v != null && url.searchParams.set(k, v));
  let r;
  try {
    r = await fetch(url, { headers: { Authorization: `Bearer ${await garantirToken()}` }, signal: comLimite(LIMITE_PADRAO) });
  } catch (e) {
    if (e instanceof ErroClassroom) throw e;
    throw new ErroClassroom('Sem conexão com o Classroom agora.');
  }
  if (r.status === 401 && tentativa === 0) {
    token = null; // vence antes do previsto: renova uma vez
    return pedirApi(caminho, filtros, 1);
  }
  if (r.status === 403) {
    const e = new ErroClassroom('A Ufac não libera o Classroom desta conta para apps externos. Dá para desconectar em Configurações.');
    e.bloqueado = true;
    throw e;
  }
  if (!r.ok) throw new ErroClassroom('O Classroom não respondeu agora. Tente daqui a pouco.');
  return r.json().catch(() => {
    throw new ErroClassroom('Sem conexão com o Classroom agora.');
  });
}

async function todasAsPaginas(caminho, filtros, campo) {
  const itens = [];
  let pagina;
  do {
    const j = await pedirApi(caminho, { ...filtros, pageSize: '100', pageToken: pagina });
    itens.push(...(j[campo] ?? []));
    pagina = j.nextPageToken;
  } while (pagina);
  return itens;
}

export async function atualizarClassroom() {
  const agora = new Date();
  const turmas = (await todasAsPaginas('/v1/courses', { studentId: 'me', courseStates: 'ACTIVE' }, 'courses')).map(lerTurma).filter(Boolean);
  const atividades = [];
  for (const t of turmas) {
    const base = `/v1/courses/${encodeURIComponent(t.id)}`;
    const [trabalhos, entregas] = await Promise.all([
      todasAsPaginas(`${base}/courseWork`, {}, 'courseWork'),
      todasAsPaginas(`${base}/courseWork/-/studentSubmissions`, { userId: 'me' }, 'studentSubmissions'),
    ]);
    const porAtividade = new Map(entregas.map((e) => [e.courseWorkId, e]));
    for (const j of trabalhos) {
      const a = lerAtividade(j, porAtividade.get(j.id), agora);
      if (a) atividades.push({ ...a, turma: t.nome });
    }
  }
  const c = { atividades: ordenarPorPrazo(atividades), lidoEm: agora.toISOString() };
  await gravar('classroom', c);
  return c;
}

/** Revoga o acesso no Google e apaga a autorização e as atividades deste iPhone. */
export async function desconectarClassroom() {
  const cofre = await ler('classroomCofre');
  let revogado = !cofre;
  if (cofre) revogado = (await postarNoWorker('/google/desconectar', { cofre }).catch(() => ({ ok: false }))).ok;
  await esquecer();
  await apagar('classroom');
  return revogado;
}
