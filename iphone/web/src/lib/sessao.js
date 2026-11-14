// Login nas duas etapas (Portal e eTICKET). Cada sistema tem a sua senha, que pode ser diferente.
// A senha fica só na memória durante o login: vai pelo Worker direto para a Ufac e é esquecida.
import { pedir, marcarExpirado } from './api.js';
import { apagar, apagarTudo, gravar, ler } from './armazenamento.js';
import { caminhos } from './config.js';
import { lerEticketInicio, lerTokenLoginEticket } from './extratores/eticket.js';
import { cpfFormatado } from './regras.js';
import { registrar, semParametros } from './registro.js';
import { cancelarPush } from './push.js';
import { desconectarClassroom } from './classroom.js';

export class ErroLogin extends Error {}
/** O Portal aceitou a senha, mas exige trocar por uma nova no site antes de abrir qualquer página. */
export class ErroTrocarSenha extends ErroLogin {}

const FRASE_TROCAR_SENHA = 'O Portal está pedindo para você trocar a senha.';

async function entrarNoPortal(sistema, cpf, senha) {
  const inicio = sistema === 'professor' ? caminhos.professorInicio : caminhos.portalInicio;
  const post = sistema === 'professor' ? caminhos.professorLoginPost : caminhos.portalLoginPost;
  // Primeiro abre a página protegida: o Tomcat só aceita o formulário com a sessão que ela cria.
  const antes = await pedir(sistema, inicio);
  if (antes.estado === 'logado') return;
  // Já entrou antes, mas o Portal prende a sessão em "Alterar Senha": mandar a senha de novo só daria 404.
  if (antes.estado === 'trocarSenha') {
    registrar('login', { sistema, resultado: 'trocarSenha', antes: semParametros(antes.urlFinal) });
    await portalPedeSenha();
    throw new ErroTrocarSenha(FRASE_TROCAR_SENHA);
  }
  const r = await pedir(sistema, post, { metodo: 'POST', formulario: { j_username: cpf.replace(/\D/g, ''), j_password: senha } });
  // Onde o Portal parou depois do login (sem parâmetros): separa senha errada de outra página no caminho.
  registrar('login', { sistema, resultado: r.estado, status: r.status, antes: semParametros(antes.urlFinal), foiPara: semParametros(r.urlFinal) });
  if (r.estado === 'trocarSenha') {
    await portalPedeSenha();
    throw new ErroTrocarSenha(FRASE_TROCAR_SENHA);
  }
  if (r.estado !== 'logado') throw new ErroLogin('O Portal não aceitou o CPF ou a senha. Confira e tente de novo.');
  await apagar('portalPedeSenha');
  await marcarExpirado(sistema, false);
}

/** Marca o pedido de senha nova (a Início troca a faixa) e esquece o diagnóstico de "página desconhecida". */
async function portalPedeSenha() {
  await gravar('portalPedeSenha', true);
  await apagar('diagnosticoPortal');
}

async function entrarNoEticket(cpf, senha) {
  const pagina = await pedir('eticket', caminhos.eticketLogin);
  if (pagina.estado === 'logado') return;
  const token = lerTokenLoginEticket(await pagina.resposta.text());
  if (!token) {
    registrar('login', { sistema: 'eticket', resultado: 'sem formulário de login', status: pagina.status, foiPara: semParametros(pagina.urlFinal) });
    throw new ErroLogin('Não consegui abrir o login do eTICKET agora. Tente daqui a pouco.');
  }
  const r = await pedir('eticket', caminhos.eticketLogin, {
    metodo: 'POST',
    formulario: { csrfmiddlewaretoken: token, cpf: cpfFormatado(cpf), password: senha },
  });
  registrar('login', { sistema: 'eticket', resultado: r.estado, status: r.status, foiPara: semParametros(r.urlFinal) });
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
