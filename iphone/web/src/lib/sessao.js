// Login nas duas etapas (Portal e eTICKET). Cada sistema tem a sua senha, que pode ser diferente.
// A senha vai pelo Worker direto para a Ufac. Só fica guardada (cifrada, neste iPhone) se a pessoa deixar
// ligada a chave "Entrar sozinho quando a sessão cair" (credenciais.js).
import { SemConexao, definirReentrada, pedir, marcarExpirado } from './api.js';
import { guardar, marcarFalha, paraLoginAutomatico, limparMemoria as esquecerDaMemoria } from './credenciais.js';
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
/** A página de login não abriu ou pediu CAPTCHA: não é senha errada. */
export class ErroSemFormulario extends ErroLogin {}
/** CAPTCHA é sempre da pessoa: o login automático nunca envia nada numa página com CAPTCHA. */
export class ErroCaptcha extends ErroLogin {}

const temCaptcha = (html) => /captcha/i.test(html);

const FRASE_TROCAR_SENHA = 'O Portal está pedindo para você trocar a senha.';

async function entrarNoPortal(sistema, cpf, senha, { automatico = false } = {}) {
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
  if (automatico && temCaptcha(await antes.resposta.text().catch(() => ''))) throw new ErroCaptcha('O Portal pediu CAPTCHA.');
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

async function entrarNoEticket(cpf, senha, { automatico = false } = {}) {
  const pagina = await pedir('eticket', caminhos.eticketLogin);
  if (pagina.estado === 'logado') return;
  const htmlLogin = await pagina.resposta.text();
  if (automatico && temCaptcha(htmlLogin)) throw new ErroCaptcha('O eTICKET pediu CAPTCHA.');
  const token = lerTokenLoginEticket(htmlLogin);
  if (!token) {
    registrar('login', { sistema: 'eticket', resultado: 'sem formulário de login', status: pagina.status, foiPara: semParametros(pagina.urlFinal) });
    throw new ErroSemFormulario('Não consegui abrir o login do eTICKET agora. Tente daqui a pouco.');
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
/** lembrar: guarda CPF e senha (cifrados) para o app entrar sozinho quando a sessão cair. */
export async function entrar(perfil, cpf, senha, { etapa = 'ambos', aoProgredir = () => {}, concluir = true, lembrar = false } = {}) {
  const sistema = perfil === 'professor' ? 'professor' : 'portal';
  if (etapa !== 'eticket') {
    aoProgredir(perfil === 'professor' ? 'Portal do Professor' : 'Portal do Aluno');
    await entrarNoPortal(sistema, cpf, senha);
    if (lembrar) await guardar('portal', cpf, senha);
  }
  if (etapa !== 'portal' && perfil !== 'professor') {
    aoProgredir('eTICKET do RU');
    await entrarNoEticket(cpf, senha);
    if (lembrar) await guardar('eticket', cpf, senha);
    await apagar('semEticket'); // conectou o eTICKET: some o aviso das abas
  }
  await gravar('perfil', perfil);
  if (concluir) await gravar('loginConcluido', true);
}

// ---------- Entrar sozinho quando a sessão cair ----------

const emAndamento = new Map(); // um login por sistema, mesmo com várias telas lendo ao mesmo tempo

async function tentarEntrarSozinho(sistema) {
  const conta = sistema === 'eticket' ? 'eticket' : 'portal';
  const c = await paraLoginAutomatico(conta);
  if (!c) return false;
  try {
    if (sistema === 'eticket') await entrarNoEticket(c.cpf, c.senha, { automatico: true });
    else await entrarNoPortal(sistema, c.cpf, c.senha, { automatico: true });
    registrar('login', { sistema, resultado: 'entrou sozinho' });
    return true;
  } catch (falha) {
    // Sem internet ou página que não abriu: tenta de novo na próxima leitura.
    if (falha instanceof SemConexao) throw falha;
    if (falha instanceof ErroSemFormulario) return false;
    // Senha recusada, senha vencida ou CAPTCHA: para até a pessoa entrar à mão.
    registrar('login', { sistema, resultado: falha instanceof ErroCaptcha ? 'CAPTCHA: parou de entrar sozinho' : 'senha recusada: parou de entrar sozinho' });
    await marcarFalha(conta);
    return false;
  }
}

/** Uma tentativa por leitura. true: entrou de novo e a página pode ser pedida outra vez. */
function reentrar(sistema) {
  if (!emAndamento.has(sistema)) emAndamento.set(sistema, tentarEntrarSozinho(sistema).finally(() => emAndamento.delete(sistema)));
  return emAndamento.get(sistema);
}
definirReentrada(reentrar);

export const loginConcluido = async () => (await ler('loginConcluido')) === true;

/** true quando a pessoa entrou só com o Portal (ainda sem acesso ao eTICKET). O app não pede nada ao eTICKET logado. */
export const semEticket = async () => (await ler('semEticket')) === true;

/** Conclui o primeiro login só com o Portal (etapa 1 já feita). O eTICKET pode ser conectado depois, em qualquer aba. */
export async function concluirSemEticket() {
  await gravar('perfil', 'aluno');
  await gravar('semEticket', true);
  await marcarExpirado('eticket', false);
  await gravar('loginConcluido', true);
  registrar('login', { sistema: 'eticket', resultado: 'continuou sem o eTICKET' });
}

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
  await apagarTudo(); // inclui CPF, senhas e a chave da cifra
  esquecerDaMemoria();
  navigator.clearAppBadge?.();
}
