// Lista local de feriados. Porte de lib/data/feriados.dart. Revisar todo ano em fonte oficial.
import { soData } from './formatos.js';

const F = 'feriado';
const PF = 'pontoFacultativo';

// Feriados do Acre e de Rio Branco mudam por decreto a cada ano: só entram depois de conferidos.
// 2026: Decreto estadual nº 11.809/2025 e calendário da Prefeitura.
const LOCAIS = {
  2026: [
    [1, 22, 'Dia do Católico', F],
    [1, 23, 'Dia do Evangélico', F],
    [3, 8, 'Dia Internacional da Mulher', F],
    [6, 15, 'Aniversário do Acre', F],
    [9, 5, 'Dia da Amazônia', F],
    [11, 17, 'Tratado de Petrópolis', F],
    [12, 28, 'Aniversário de Rio Branco', F],
  ],
};

/** Domingo de Páscoa (algoritmo de Meeus). */
export function pascoa(ano) {
  const a = ano % 19, b = Math.floor(ano / 100), c = ano % 100;
  const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const mes = Math.floor((h + l - 7 * m + 114) / 31);
  const dia = ((h + l - 7 * m + 114) % 31) + 1;
  return new Date(ano, mes - 1, dia);
}

export function feriadosDoAno(ano) {
  const p = pascoa(ano);
  const daPascoa = (dias) => new Date(p.getFullYear(), p.getMonth(), p.getDate() + dias);
  const f = (mes, dia, nome, tipo = F) => ({ data: new Date(ano, mes - 1, dia), nome, tipo });
  return [
    f(1, 1, 'Confraternização Universal'),
    { data: daPascoa(-48), nome: 'Carnaval', tipo: PF },
    { data: daPascoa(-47), nome: 'Carnaval', tipo: PF },
    { data: daPascoa(-2), nome: 'Sexta-feira Santa', tipo: F },
    f(4, 21, 'Tiradentes'),
    f(5, 1, 'Dia do Trabalho'),
    { data: daPascoa(60), nome: 'Corpus Christi', tipo: PF },
    f(9, 7, 'Independência do Brasil'),
    f(10, 12, 'Nossa Senhora Aparecida'),
    f(11, 2, 'Finados'),
    f(11, 15, 'Proclamação da República'),
    f(11, 20, 'Dia da Consciência Negra'),
    f(12, 25, 'Natal'),
    ...(LOCAIS[ano] ?? []).map(([m, d, nome, tipo]) => f(m, d, nome, tipo)),
  ];
}

function noDia(dia) {
  const d = soData(dia).getTime();
  return feriadosDoAno(dia.getFullYear()).find((f) => f.data.getTime() === d) ?? null;
}

/** Aparece na véspera e no próprio dia. Nunca afirma que o RU está fechado. */
export function avisoFeriado(agora) {
  const hoje = noDia(agora);
  const amanha = hoje ? null : noDia(new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + 1));
  const feriado = hoje ?? amanha;
  if (!feriado) return null;
  const quando = hoje ? 'Hoje' : 'Amanhã';
  if (feriado.tipo === PF) {
    return { titulo: `${quando} é ponto facultativo · ${feriado.nome}`, texto: 'Confira se há aula e o funcionamento do RU.' };
  }
  return { titulo: `${quando} é feriado · ${feriado.nome}`, texto: 'Sem aulas. Confira o funcionamento do RU.' };
}
