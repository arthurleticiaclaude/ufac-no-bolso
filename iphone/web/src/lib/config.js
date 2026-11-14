// Valores que mudam por ambiente. Vêm do build (variáveis VITE_*), nunca fixos no meio do código.
export const WORKER_URL = (import.meta.env?.VITE_WORKER_URL ?? 'http://localhost:8787').replace(/\/$/, '');
/** ID do cliente OAuth "Aplicativo da Web" do Google Cloud (não é segredo). Vazio = Classroom desligado. */
export const GOOGLE_CLIENT_ID = import.meta.env?.VITE_GOOGLE_CLIENT_ID ?? '';
export const INSTAGRAM_RU = 'https://www.instagram.com/ru.informa.ufac/';
export const CONTATO_EMAIL = import.meta.env?.VITE_CONTATO_EMAIL ?? '';
/** Número com DDI e DDD, só dígitos (ex.: 5568...). Vazio = sem botão de WhatsApp direto. */
export const CONTATO_WHATSAPP = import.meta.env?.VITE_CONTATO_WHATSAPP ?? '';
export const VERSAO = '0.1.0-ios';

export const URL_RECARGA = 'https://sistemas.ufac.br/eticket/valorPaga/';
export const URL_PORTAL_ALUNO = 'https://portal.ufac.br/aluno/index.action';
export const URL_PORTAL_PROFESSOR = 'https://portal.ufac.br/professor/index.action';

export const RELATORIOS = [
  ['Atestado de Matrícula', 'atestadoMatricula', 'atestado_matricula.pdf'],
  ['Comprovante de Matrícula', 'comprovanteMatricula', 'comprovante_matricula.pdf'],
  ['Ficha Cadastral do Aluno', 'fichaCadastral', 'ficha_cadastral.pdf'],
  ['Histórico Escolar Simplificado', 'historicoEscolarSimplificado', 'historico_simplificado.pdf'],
  ['Histórico de Integralização', 'integralizacaoCurricular', 'historico_integralizacao.pdf'],
  ['Solicitação de Matrícula', 'solicitacaoMatricula', 'solicitacao_matricula.pdf'],
  ['Histórico Escolar CR – Aprovados (SIE)', 'com/historicoEscolarCRAprovados', 'historico_cr_aprovados.pdf'],
].map(([nome, acao, arquivo]) => ({ nome, acao, arquivo }));

// Caminhos dentro do Worker (/portal → portal.ufac.br, /eticket → sistemas.ufac.br/eticket).
export const caminhos = {
  portalInicio: '/aluno/index.action',
  portalLoginPost: '/aluno/j_security_check',
  relatorios: (id) => `/aluno/aluno/relatorio/relatorios.action?matricula=${id}`,
  relatorio: (acao, id) => `/aluno/aluno/relatorio/${acao}.action?matricula=${id}`,
  notas: (id) => `/aluno/aluno/nota/nota.action?matricula=${id}`,
  horarios: (id) => `/aluno/ajax/aluno/quadrohorario/quadrohorario.action?matricula=${id}`,
  professorInicio: '/professor/index.action',
  professorLoginPost: '/professor/j_security_check',
  professorTurmasFrequencia: '/professor/professor/frequencia/minhasturmas/minhasturmas.action',
  professorTurmasNotas: '/professor/professor/nota/minhasturmas.action',
  professorTurma: (id) => `/professor/professor/turma.action?turma=${id}`,
  professorAgenda: (id) => `/professor/professor/frequencia/agenda/agendaturma/agenda.action?turma=${id}`,
  professorAulasDoMes: (idTurma, anoMes, indice) =>
    `/professor/ajax/professor/frequencia/agenda/agendaturma/buscarDadosAccordion.action?anoMesToSearchAgendas=${anoMes}&idTurma=${idTurma}&indexAba=${indice}&lancamento=true&as=`,
  eticketInicio: '/',
  eticketLogin: '/login/',
  eticketCardapio: '/menu/',
  eticketCardapioPublico: '/menuExterno/',
  eticketHistorico: '/historico/',
  eticketHistoricoRefeicoes: '/historico/refeicoes/',
};

/** Endereços oficiais, para abrir no Safari (chamada, notas, recarga, site completo). */
export const oficial = {
  matricula: (id) => `https://portal.ufac.br/aluno/aluno/matricula/solicitacoes.action?matricula=${id}`,
  biblioteca: (id) => `https://portal.ufac.br/biblioteca/pesquisa/pesquisar.action?matricula=${id}`,
  professorChamada: (idAgenda) => `https://portal.ufac.br/professor/professor/frequencia/lancamento/horaaula/horaaula.action?agenda=${idAgenda}&indexAba=1`,
  professorQuadroNotas: (id) => `https://portal.ufac.br/professor/professor/nota/lancamento/quadro.action?turma=${id}`,
  professorAgenda: (id) => `https://portal.ufac.br/professor/professor/frequencia/agenda/agendaturma/agenda.action?turma=${id}`,
};
