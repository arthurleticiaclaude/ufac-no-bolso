// Regras do Portal. Porte de lib/data/academico.dart.
import { deDataISO, diaDaSemana, formatarHoraMin, soData } from './formatos.js';

/** Faltas: pode ter até 16 em cada disciplina; a 17ª reprova (decisão de Arthur). */
export const LIMITE_FALTAS = 16;

export const primeiroNome = (nome) => nome.split(' ')[0];

export function iniciais(nome) {
  const partes = nome.split(' ').filter(Boolean);
  if (partes.length === 0) return '';
  return partes.length < 2 ? partes[0][0] : partes[0][0] + partes[partes.length - 1][0];
}

/** Aula = { disciplina, diaSemana (1..7), inicioMin, fimMin, valeDe?, valeAte? } (datas em ISO). */
export function aulaValeNoDia(aula, dia) {
  const d = soData(dia).getTime();
  const de = aula.valeDe ? deDataISO(aula.valeDe).getTime() : null;
  const ate = aula.valeAte ? deDataISO(aula.valeAte).getTime() : null;
  return (de === null || d >= de) && (ate === null || d <= ate);
}

const DIAS_CURTOS = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

/** A aula em andamento ou a próxima nos próximos 7 dias. Null se não houver nenhuma. */
export function proximaAula(aulas, agora) {
  const minutos = agora.getHours() * 60 + agora.getMinutes();
  for (let d = 0; d < 7; d++) {
    const dia = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + d);
    const doDia = aulas
      .filter((a) => a.diaSemana === diaDaSemana(dia) && aulaValeNoDia(a, dia))
      .sort((a, b) => a.inicioMin - b.inicioMin);
    for (const a of doDia) {
      if (d === 0 && a.fimMin <= minutos) continue;
      if (d === 0 && a.inicioMin <= minutos) return { aula: a, rotulo: 'em andamento', emAndamento: true };
      if (d === 0) {
        const falta = a.inicioMin - minutos;
        return { aula: a, rotulo: falta < 60 ? `começa em ${falta} min` : `hoje às ${formatarHoraMin(a.inicioMin)}` };
      }
      if (d === 1) return { aula: a, rotulo: `amanhã às ${formatarHoraMin(a.inicioMin)}` };
      return { aula: a, rotulo: `${DIAS_CURTOS[diaDaSemana(dia) - 1]} às ${formatarHoraMin(a.inicioMin)}` };
    }
  }
  return null;
}

/** "2° Semestre / 2026" vira "2º / 2026". */
export function semestreCurto(semestre) {
  const m = /(\d+)\D+(\d{4})/.exec(semestre);
  return m ? `${m[1]}º / ${m[2]}` : semestre;
}

/**
 * Reprova quem passa de `percentual` da carga horária. Sem a carga, usa `permitidasSemCarga`.
 * O aviso começa em 75% das faltas permitidas. Null quando o portal ainda não informa faltas.
 */
export function situacaoFaltas(faltas, { cargaHoraria = null, percentual = 0, permitidasSemCarga = LIMITE_FALTAS } = {}) {
  const t = String(faltas ?? '').trim();
  if (!/^\d+$/.test(t)) return null;
  const n = Number(t);
  const permitidas = cargaHoraria == null ? permitidasSemCarga : Math.floor(cargaHoraria * percentual);
  const aviso = Math.ceil(permitidas * 0.75);
  const nivel = n > permitidas ? 'limite' : n >= aviso ? 'atencao' : 'tranquilo';
  return { faltas: n, permitidas, nivel, estimado: cargaHoraria == null };
}

/** O quadro de horários e a lista de notas escrevem o nome com detalhes diferentes. */
export const nomeDeDisciplinaComparavel = (nome) =>
  nome.replace(/\s*\([^()]*\)\s*$/, '').replace(/\s+/g, ' ').trim().toLowerCase();

export function notasDaDisciplina(notas, disciplina) {
  const alvo = nomeDeDisciplinaComparavel(disciplina);
  return notas?.find((n) => nomeDeDisciplinaComparavel(n.disciplina) === alvo) ?? null;
}

/** O portal chama de "Matrícula" a disciplina em andamento. */
export const situacaoApresentavel = (s) => (s === 'Matrícula' ? 'Cursando' : s);

/** O total de uma coluna "Nota 1" é o último item. */
export const totalDaNota = (nota) => (nota.itens.length ? nota.itens[nota.itens.length - 1].valor : '');
