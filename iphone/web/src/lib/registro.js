// Registro de eventos para o "Relatar um problema": fica só neste iPhone e só sai quando a pessoa envia.
// Guarda o que deu errado (pedido, leitura, login, erro do app), nunca senha, cookie, HTML, nome, CPF ou matrícula.
import { gravar, ler } from './armazenamento.js';

const CHAVE = 'registro';
const MAXIMO = 60;

/** Tira o que pode identificar a pessoa: números longos (CPF, matrícula, id interno), CPF com pontos e e-mails. */
export function anonimizar(texto) {
  return String(texto ?? '')
    .replace(/\d{3}\.\d{3}\.\d{3}-\d{2}/g, '#')
    .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, '@')
    .replace(/\d{4,}/g, '#')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 200);
}

/** Endereço sem parâmetros: "/aluno/nota.action?matricula=123" vira "/aluno/nota.action". */
export const semParametros = (endereco) => anonimizar(String(endereco ?? '').replace(/^https?:\/\/[^/]+/, '').split(/[?#]/)[0]);

function limpar(dados) {
  const saida = {};
  for (const [k, v] of Object.entries(dados ?? {})) {
    if (v == null || v === '') continue;
    if (typeof v === 'number' || typeof v === 'boolean') saida[k] = v;
    else if (Array.isArray(v)) saida[k] = v.slice(0, 6).map((x) => (typeof x === 'object' ? limpar(x) : anonimizar(x)));
    else if (typeof v === 'object') saida[k] = limpar(v);
    else saida[k] = anonimizar(v);
  }
  return saida;
}

// Gravações em fila, para eventos simultâneos não se sobrescreverem.
let fila = Promise.resolve();

/** tipo: 'rede' | 'leitura' | 'login' | 'sessao' | 'app'. Nunca lança: registrar não pode quebrar o app. */
export function registrar(tipo, dados = {}) {
  const evento = { em: new Date().toISOString(), tipo, ...limpar(dados) };
  fila = fila
    .then(async () => {
      const lista = (await ler(CHAVE)) ?? [];
      lista.push(evento);
      await gravar(CHAVE, lista.slice(-MAXIMO));
    })
    .catch(() => {});
  return fila;
}

export const lerRegistro = async () => (await ler(CHAVE).catch(() => null)) ?? [];
