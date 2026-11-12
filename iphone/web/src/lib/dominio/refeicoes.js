// Refeições e cardápio. Porte de lib/config.dart, lib/data/refeicoes.dart e cardapio.dart.
import { mesmoDia } from './formatos.js';

// Horários do post do RU de 04/11/2026.
export const REFEICOES = [
  { id: 'cafe', nome: 'Café', minusculo: 'café', inicioMin: 6 * 60 + 30, fimMin: 8 * 60 },
  { id: 'almoco', nome: 'Almoço', minusculo: 'almoço', inicioMin: 11 * 60, fimMin: 14 * 60 },
  { id: 'jantar', nome: 'Jantar', minusculo: 'jantar', inicioMin: 18 * 60, fimMin: 19 * 60 + 30 },
];

export const refeicaoPorId = (id) => REFEICOES.find((r) => r.id === id);

/** A refeição em andamento ou a próxima. Depois do jantar, volta para o café. */
export function proximaRefeicao(agora) {
  const minutos = agora.getHours() * 60 + agora.getMinutes();
  return REFEICOES.find((r) => minutos < r.fimMin) ?? REFEICOES[0];
}

const SAUDACAO = /^(bo[am]\s+(café|cafe|almoço|almoco|jantar|janta|apetite|refeição|refeicao)|tenham?\s+um)/i;

/** "SALADA: Alface" vira "Salada: Alface". O rótulo é do próprio eTICKET, não inventado. */
function rotuloLegivel(linha) {
  const m = /^([A-ZÀ-Ý ]{3,}):\s*(.*)$/.exec(linha);
  if (!m) return linha;
  const r = m[1].trim().toLowerCase();
  return `${r[0].toUpperCase()}${r.slice(1)}: ${m[2]}`;
}

/**
 * Separa o texto do eTICKET em itens. Aceita os dois formatos já vistos:
 * uma frase com vírgulas ("Café preto, Leite, Pão.") e uma linha por item ("-Arroz\nSALADA: Alface\nBom almoço <3").
 * Saudações e enfeites saem. "Não informado" vira lista vazia.
 */
export function itensDoCardapio(texto) {
  const limpo = (texto ?? '').trim();
  const baixo = limpo.toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '').replace(/[.!\s]+$/, '');
  if (!limpo || baixo === 'nao informado' || baixo === 'indisponivel') return [];
  const linhas = limpo
    .split(/\r?\n/)
    .map((l) => l.replace(/^[\s\-–—•*·]+/, '').replace(/\s*(<3|❤️?|♥)+\s*$/u, '').trim())
    .filter((l) => l && !SAUDACAO.test(l));
  return linhas.flatMap((l) => {
    const semPonto = l.replace(/[.;]$/, '');
    if (/^[A-ZÀ-Ý ]{3,}:/.test(semPonto)) return [rotuloLegivel(semPonto)];
    return semPonto
      .split(',')
      .map((i) => i.trim())
      .filter(Boolean);
  });
}

/** Cardápio lido num dia: { lidoEm (ISO), textos: { cafe, almoco, jantar } }. A página não tem data. */
export const cardapioValeEm = (c, agora) => !!c && mesmoDia(new Date(c.lidoEm), agora);

/** Vale ler de novo se não há cardápio de hoje ou se falta alguma refeição. */
export const cardapioPendente = (c, agora) =>
  !cardapioValeEm(c, agora) || REFEICOES.some((r) => itensDoCardapio(c.textos[r.id]).length === 0);
