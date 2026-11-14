// "Entrar sozinho quando a sessão cair": CPF e senha que a pessoa digitou, cifrados só neste iPhone.
// Servem para o app refazer o login quando a sessão da Ufac cai. Só vão do iPhone, pelo Worker, para a Ufac:
// nunca para o registro, o relato, o cache ou qualquer outro lugar.
//
// Não há cofre do sistema para apps da web. A cifra é AES-GCM com uma chave do WebCrypto marcada como
// "não exportável": fica no IndexedDB do app, mas nenhum código (nem o do próprio app) consegue ler os bytes dela.
// conta: 'portal' (Portal do Aluno ou do Professor) | 'eticket'. As senhas podem ser diferentes.
import { apagar, gravar, ler } from './armazenamento.js';

const CHAVE_LIGADO = 'loginAutomatico';
const CHAVE_COFRE = 'credenciais';
const CHAVE_FALHOU = 'loginAutomaticoFalhou';

let memoria = null; // { portal: {cpf, senha}, eticket: {...} } já decifrado nesta abertura

/** Ligada por padrão. */
export const ligado = async () => (await ler(CHAVE_LIGADO)) !== false;

export async function definirLigado(valor) {
  await gravar(CHAVE_LIGADO, valor);
  if (!valor) await esquecer();
}

async function chaveDaCifra(cofre) {
  if (cofre?.chave) return cofre.chave;
  return crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
}

async function decifrarTudo() {
  if (memoria) return memoria;
  const cofre = await ler(CHAVE_COFRE);
  const contas = {};
  for (const [conta, { iv, dados }] of Object.entries(cofre?.contas ?? {})) {
    try {
      const claro = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, cofre.chave, dados);
      contas[conta] = JSON.parse(new TextDecoder().decode(claro));
    } catch {
      /* cofre corrompido ou chave perdida: como se não houvesse senha */
    }
  }
  memoria = contas;
  return contas;
}

export async function guardar(conta, cpf, senha) {
  const digitos = String(cpf).replace(/\D/g, '');
  if (digitos.length !== 11 || !senha || !(await ligado())) return;
  const cofre = (await ler(CHAVE_COFRE)) ?? { contas: {} };
  const chave = await chaveDaCifra(cofre);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const dados = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, chave, new TextEncoder().encode(JSON.stringify({ cpf: digitos, senha })));
  await gravar(CHAVE_COFRE, { chave, contas: { ...cofre.contas, [conta]: { iv, dados } } });
  await decifrarTudo();
  memoria[conta] = { cpf: digitos, senha };
  await gravar(CHAVE_FALHOU, ((await ler(CHAVE_FALHOU)) ?? []).filter((c) => c !== conta));
}

/** {cpf, senha} para o login automático. Null sem senha, com a chave desligada ou depois de uma recusa. */
export async function paraLoginAutomatico(conta) {
  if (!(await ligado())) return null;
  if (((await ler(CHAVE_FALHOU)) ?? []).includes(conta)) return null;
  return (await decifrarTudo())[conta] ?? null;
}

/** Senha recusada ou CAPTCHA: para de tentar até a pessoa entrar à mão (vale também nas próximas aberturas). */
export async function marcarFalha(conta) {
  const falhas = new Set((await ler(CHAVE_FALHOU)) ?? []);
  falhas.add(conta);
  await gravar(CHAVE_FALHOU, [...falhas]);
}

export const temSalvas = async () => Object.keys(await decifrarTudo()).length > 0;

/** "Esquecer senha salva": apaga CPF, senhas e a chave da cifra. A chave "Entrar sozinho" fica como está. */
export async function esquecer() {
  await apagar(CHAVE_COFRE);
  await apagar(CHAVE_FALHOU);
  memoria = {};
}

/** Depois de "Sair" (o banco inteiro já foi apagado): só a memória. */
export function limparMemoria() {
  memoria = null;
}
