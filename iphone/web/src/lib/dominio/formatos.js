// Formatos brasileiros: R$ 12,50; Quarta, 4 de novembro; 10h20.
// Porte de lib/ui/formatos.dart.

export const DIAS = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
export const MESES = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/** Como DateTime.weekday do Dart: segunda = 1, domingo = 7. */
export const diaDaSemana = (d) => d.getDay() || 7;

/** Só a data, à meia-noite local. */
export const soData = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

export const mesmoDia = (a, b) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

export function formatarMoeda(valor) {
  const [inteiro, centavos] = valor.toFixed(2).split('.');
  return `R$ ${inteiro.replace(/(\d)(?=(\d{3})+$)/g, '$1.')},${centavos}`;
}

export const formatarData = (d) => `${DIAS[diaDaSemana(d) - 1]}, ${d.getDate()} de ${MESES[d.getMonth()]}`;

export const formatarHora = (h, m) => (m === 0 ? `${h}h` : `${h}h${String(m).padStart(2, '0')}`);

export const formatarHoraMin = (minutos) => formatarHora(Math.floor(minutos / 60), minutos % 60);

/** Mostra só os 4 últimos dígitos. */
export function mascararNumero(numero) {
  if (numero.length <= 4) return numero;
  return '•'.repeat(numero.length - 4) + numero.slice(-4);
}

/** "4/11 às 10h20" */
export const formatarDiaHora = (d) =>
  `${d.getDate()}/${d.getMonth() + 1} às ${formatarHora(d.getHours(), d.getMinutes())}`;

/** "hoje 23h59", "amanhã 10h", "sex 18h". */
export function formatarPrazoCurto(prazo, agora) {
  const diferenca = Math.round((soData(prazo) - soData(agora)) / 86400000);
  const hora = formatarHora(prazo.getHours(), prazo.getMinutes());
  if (diferenca === 0) return `hoje ${hora}`;
  if (diferenca === 1) return `amanhã ${hora}`;
  return `${DIAS[diaDaSemana(prazo) - 1].slice(0, 3).toLowerCase()} ${hora}`;
}

/** "Atualizado às 9h40" ou "Atualizado em 3/11 às 9h40". */
export function rotuloAtualizado(quando, agora = new Date()) {
  if (!quando) return 'Ainda não atualizado';
  const d = new Date(quando);
  const hora = formatarHora(d.getHours(), d.getMinutes());
  return mesmoDia(d, agora) ? `Atualizado às ${hora}` : `Atualizado em ${formatarDiaHora(d)}`;
}

/** Data sem hora, como texto "2026-08-03" (evita o fuso virar o dia). */
export const dataISO = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/** Lê "2026-08-03" como meia-noite local. Null se não for data. */
export function deDataISO(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s ?? '');
  return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])) : null;
}
