// Login nas duas etapas (Portal e eTICKET). Cada sistema tem a sua senha, que pode ser diferente.
// A senha fica só na memória durante o login: vai pelo Worker direto para a Ufac e é esquecida.
import { pedir, marcarExpirado } from './api.js';
import { apagarTudo, gravar, ler } from './armazenamento.js';
import { caminhos } from './config.js';
import { lerEticketInicio, lerTokenLoginEticket } from './extratores/eticket.js';
import { cpfFormatado } from './regras.js';
import { cancelarPush } from './push.js';
import { desconectarClassroom } from './classroom.js';

export class ErroLogin extends Error {}

async function entrarNoPortal(sistema, cpf, senha) {
  const inicio = sistema === 'professor' ? caminhos.professorInicio : caminhos.portalInicio;
  const post = sistema === 'professor' ? caminhos.professorLoginPost : caminhos.portalLoginPost;
  // Primeiro abre a página protegida: o Tomcat só aceita o formulário com a sessão que ela cria.
  const antes = await pedir(sistema, inicio);
  if (antes.estado === 'logado') return;
  const r = await pedir(sistema, post, { metodo: 'POST', formulario: { j_username: cpf.replace(/\D/g, ''), j_password: senha } });
  if (r.estado !== 'logado') throw new ErroLogin('O Portal não aceitou o CPF ou a senha. Confira e tente de novo.');
  await marcarExpirado(sistema, false);
}

async function entrarNoEticket(cpf, senha) {
  const pagina = await pedir('eticket', caminhos.eticketLogin);
  if (pagina.estado === 'logado') return;
  const token = lerTokenLoginEticket(await pagina.resposta.text());
  if (!token) throw new ErroLogin('Não consegui abrir o login do eTICKET agora. Tente daqui a pouco.');
  const r = await pedir('eticket', caminhos.eticketLogin, {
    metodo: 'POST',
    formulario: { csrfmiddlewaretoken: token, cpf: cpfFormatado(cpf), password: senha },
  });
  if (r.estado !== 'logado') throw new ErroLogin('O eTICKET não aceitou o CPF ou a senha. Confira e tente de novo.');
  const dados = lerEticketInicio(await r.resposta.text());
  if (dados) await gravar('ru', { ...dados, lidoEm: new Date().toISOString() });
  await marcarExpirado('eticket', false);
}

/** etapa: 'portal' | 'eticket' | 'ambos'. aoProgredir recebe o nome da etapa em andamento. */
/** concluir: false na etapa 1 do primeiro login, para não marcar o login como completo só com o Portal. */
export async function entrar(perfil, cpf, senha, { etapa = 'ambos', aoProgredir = () => {}, concluir = true } = {}) {
  const sistema = perfil === 'professor' ? 'professor' : 'portal';
  if (etapa !== 'eticket') {
    aoProgredir(perfil === 'professor' ? 'Portal do Professor' : 'Portal do Aluno');
    await entrarNoPortal(sistema, cpf, senha);
  }
  if (etapa !== 'portal' && perfil !== 'professor') {
    aoProgredir('eTICKET do RU');
    await entrarNoEticket(cpf, senha);
  }
  await gravar('perfil', perfil);
  if (concluir) await gravar('loginConcluido', true);
}

export const loginConcluido = async () => (await ler('loginConcluido')) === true;

/** Apaga sessão, cache, número do QR e foto deste iPhone. */
export async function sair() {
  try {
    const reg = await navigator.serviceWorker?.getRegistration();
    const inscricao = await reg?.pushManager?.getSubscription();
    if (inscricao) await cancelarPush(inscricao);
  } catch {
    /* sem push, nada a cancelar */
  }
  await desconectarClassroom().catch(() => {});
  await apagarTudo();
  navigator.clearAppBadge?.();
}
