// Regras do Portal do Professor. Porte de lib/data/professor.dart.
import { deDataISO, soData } from './formatos.js';

export const lancamentoNotasAberto = (turma) => (turma.situacaoNotas ?? '').toLowerCase().includes('aberto');

/** Aulas da Agenda que já aconteceram e ainda estão sem chamada. */
export function semChamada(turmaCompleta, agora) {
  const hoje = soData(agora).getTime();
  return (turmaCompleta.aulasDoMes ?? []).filter((a) => !a.chamadaLancada && deDataISO(a.data).getTime() <= hoje);
}

/** Os horários de todas as turmas, no formato que Horários e "Próxima aula" usam. */
export const aulasDoProfessor = (turmas) =>
  turmas.flatMap((t) =>
    (t.detalhe?.horarios ?? []).map((h) => ({
      disciplina: `${t.turma.disciplina} · ${t.turma.nome}`,
      diaSemana: h.diaSemana,
      inicioMin: h.inicioMin,
      fimMin: h.fimMin,
      valeDe: h.valeDe,
      valeAte: h.valeAte,
    })),
  );
