// Leitura das respostas do Google Classroom. Porte de lib/data/classroom.dart e avisos_classroom.dart.
import { formatarPrazoCurto } from './formatos.js';

/** Só leitura. Nenhum escopo além destes dois. */
export const ESCOPOS = [
  'https://www.googleapis.com/auth/classroom.courses.readonly',
  'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
];

/** Hora do aviso diário (com o que vence até o fim do dia seguinte). */
export const HORA_AVISO_CLASSROOM = 19;

const linkSeguro = (v) => (typeof v === 'string' && v.startsWith('https://classroom.google.com/') ? v : null);

export function lerTurma(j) {
  if (typeof j?.id !== 'string' || typeof j?.name !== 'string') return null;
  return { id: j.id, nome: j.name, secao: j.section ?? null, link: linkSeguro(j.alternateLink) };
}

/** O Classroom manda o prazo em UTC, separado em data e hora. */
export function lerPrazo(j) {
  const d = j?.dueDate;
  if (!d || !Number.isInteger(d.year) || !Number.isInteger(d.month) || !Number.isInteger(d.day)) return null;
  const h = j.dueTime ?? {};
  return new Date(Date.UTC(d.year, d.month - 1, d.day, h.hours ?? 0, h.minutes ?? 0));
}

export function lerSituacao(entrega, prazo, agora) {
  const estado = entrega?.state;
  if (estado === 'TURNED_IN' || estado === 'RETURNED') return 'entregue';
  if (entrega?.late === true || (prazo && agora > prazo)) return 'atrasada';
  return 'pendente';
}

export function lerAtividade(j, entrega, agora) {
  if (typeof j?.id !== 'string' || typeof j?.title !== 'string') return null;
  const prazo = lerPrazo(j);
  return {
    id: j.id,
    titulo: j.title,
    turma: null,
    prazo: prazo?.toISOString() ?? null,
    link: linkSeguro(j.alternateLink),
    situacao: lerSituacao(entrega, prazo, agora),
  };
}

/** Prazo mais próximo primeiro; sem prazo vai para o fim. */
export const ordenarPorPrazo = (lista) =>
  [...lista].sort((a, b) => {
    if (!a.prazo && !b.prazo) return a.titulo.localeCompare(b.titulo);
    if (!a.prazo) return 1;
    if (!b.prazo) return -1;
    return new Date(a.prazo) - new Date(b.prazo);
  });

const SEMANA = 7 * 86400000;

/** O que falta entregar com prazo nos próximos 7 dias, mais o que atrasou nos últimos 7. */
export const atividadesDaSemana = (todas, agora) =>
  ordenarPorPrazo(
    todas.filter((a) => {
      if (a.situacao === 'entregue' || !a.prazo) return false;
      const p = new Date(a.prazo).getTime();
      return p > agora.getTime() - SEMANA && p < agora.getTime() + SEMANA;
    }),
  );

/**
 * Um aviso por dia, às 19h, com o que falta entregar até o fim do dia seguinte.
 * Sem nada a entregar, não há aviso naquele dia (o iPhone exige mostrar todo push recebido).
 */
export function planejarAvisos(lista, agora, dias = 7) {
  const avisos = [];
  for (let d = 0; d < dias; d++) {
    const quando = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + d, HORA_AVISO_CLASSROOM);
    if (quando <= agora) continue;
    const limite = new Date(quando.getFullYear(), quando.getMonth(), quando.getDate() + 2);
    const doDia = ordenarPorPrazo(
      lista.filter((a) => a.situacao !== 'entregue' && a.prazo && new Date(a.prazo) > quando && new Date(a.prazo) < limite),
    );
    if (!doDia.length) continue;
    avisos.push({
      quando,
      titulo: doDia.length === 1 ? '1 atividade para entregar' : `${doDia.length} atividades para entregar`,
      texto: doDia
        .map((a) => `${a.titulo} · ${formatarPrazoCurto(new Date(a.prazo), quando)}${a.turma ? ` · ${a.turma}` : ''}`)
        .join('\n'),
    });
  }
  return avisos;
}
