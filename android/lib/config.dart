// Valores que podem mudar sem mexer no resto do app.

class HorarioRefeicao {
  const HorarioRefeicao(this.inicioMin, this.fimMin);
  final int inicioMin;
  final int fimMin;
}

enum Refeicao {
  cafe('Café', 'café', HorarioRefeicao(6 * 60 + 30, 8 * 60)),
  almoco('Almoço', 'almoço', HorarioRefeicao(11 * 60, 14 * 60)),
  jantar('Jantar', 'jantar', HorarioRefeicao(18 * 60, 19 * 60 + 30));

  const Refeicao(this.nome, this.nomeMinusculo, this.horario);
  final String nome;
  final String nomeMinusculo;
  final HorarioRefeicao horario;
}

const instagramRu = 'https://www.instagram.com/ru.informa.ufac/';
const urlCardapio = 'https://sistemas.ufac.br/eticket/menu/';
const urlRecarga = 'https://sistemas.ufac.br/eticket/valorPaga/';
const urlHistorico = 'https://sistemas.ufac.br/eticket/historico/';
const urlHistoricoRefeicoes = 'https://sistemas.ufac.br/eticket/historico/refeicoes/';
const urlAvisosRu = 'https://sistemas.ufac.br/eticket/informacao/';
const urlPortal = 'https://portal.ufac.br/aluno/index.action';

String urlMatricula(String idInterno) =>
    'https://portal.ufac.br/aluno/aluno/matricula/solicitacoes.action?matricula=$idInterno';
String urlBiblioteca(String idInterno) =>
    'https://portal.ufac.br/biblioteca/pesquisa/pesquisar.action?matricula=$idInterno';

// Biblioteca (mesmo login do portal). Detalhes em docs/reconhecimento.md.
const urlBibliotecaMeuEspaco = 'https://portal.ufac.br/biblioteca/usuario/index.action';
const urlBibliotecaRenovacao = 'https://portal.ufac.br/biblioteca/usuario/renovacao/emprestimos.action';
const urlBibliotecaReservas = 'https://portal.ufac.br/biblioteca/usuario/reserva/reservas.action';
const urlBibliotecaHistorico =
    'https://portal.ufac.br/biblioteca/usuario/emprestimo/gridhistorico.action?_search=false&rows=100&page=1&sidx=dataRetirada&sord=desc';
String urlAcervoPesquisa(String termo) =>
    Uri.https('portal.ufac.br', '/biblioteca/pesquisa/resultado.action', {'keyword': termo}).toString();
String urlAcervoExemplares(String idRegistro, {String titulo = '', String autor = ''}) =>
    Uri.https('portal.ufac.br', '/biblioteca/ajax/exemplar/itens.action', {'idRegistro': idRegistro, 'titulo': titulo, 'subtitulo': '', 'autor': autor}).toString();

enum RelatorioPortal {
  atestado('Atestado de Matrícula', 'atestadoMatricula', 'atestado_matricula.pdf'),
  comprovante('Comprovante de Matrícula', 'comprovanteMatricula', 'comprovante_matricula.pdf'),
  ficha('Ficha Cadastral do Aluno', 'fichaCadastral', 'ficha_cadastral.pdf'),
  historico('Histórico Escolar Simplificado', 'historicoEscolarSimplificado', 'historico_simplificado.pdf'),
  integralizacao('Histórico de Integralização', 'integralizacaoCurricular', 'historico_integralizacao.pdf'),
  solicitacao('Solicitação de Matrícula', 'solicitacaoMatricula', 'solicitacao_matricula.pdf'),
  aprovados('Histórico Escolar CR – Aprovados (SIE)', 'com/historicoEscolarCRAprovados', 'historico_cr_aprovados.pdf');

  const RelatorioPortal(this.nome, this.acao, this.arquivo);
  final String nome, acao, arquivo;

  String url(String idInterno) =>
      'https://portal.ufac.br/aluno/aluno/relatorio/$acao.action?matricula=$idInterno';
}

String urlRelatorios(String idInterno) =>
    'https://portal.ufac.br/aluno/aluno/relatorio/relatorios.action?matricula=$idInterno';
String urlNotas(String idInterno) => 'https://portal.ufac.br/aluno/aluno/nota/nota.action?matricula=$idInterno';
String urlHorarios(String idInterno) =>
    'https://portal.ufac.br/aluno/ajax/aluno/quadrohorario/quadrohorario.action?matricula=$idInterno';

// Portal do Professor. Endereços vistos na leitura mascarada de 2026-11-11 (docs/reconhecimento.md).
const _professor = 'https://portal.ufac.br/professor';
const urlProfessorInicio = '$_professor/index.action';
const urlProfessorTurmasFrequencia = '$_professor/professor/frequencia/minhasturmas/minhasturmas.action';
const urlProfessorTurmasNotas = '$_professor/professor/nota/minhasturmas.action';
const urlProfessorRelatorios = '$_professor/professor/relatorio/relatorios.action';
String urlProfessorTurma(String id) => '$_professor/professor/turma.action?turma=$id';
String urlProfessorAgenda(String id) => '$_professor/professor/frequencia/agenda/agendaturma/agenda.action?turma=$id';
String urlProfessorQuadroNotas(String id) => '$_professor/professor/nota/lancamento/quadro.action?turma=$id';
String urlProfessorChamada(String idAgenda) =>
    '$_professor/professor/frequencia/lancamento/horaaula/horaaula.action?agenda=$idAgenda&indexAba=1';
String urlProfessorAulasDoMes(String idTurma, String anoMes, int indice) =>
    '$_professor/ajax/professor/frequencia/agenda/agendaturma/buscarDadosAccordion.action'
    '?anoMesToSearchAgendas=$anoMes&idTurma=$idTurma&indexAba=$indice&lancamento=true&as=';

/// Relatórios do professor. Os nomes vêm dos endereços: na página eles aparecem só como ícones.
enum RelatorioProfessor {
  quadroHorario('Quadro de horário', 'quadrohorario'),
  frequencia('Frequência', 'frequencia'),
  quadroFrequencia('Quadro de frequência', 'quadrofrequencia'),
  fechamento('Relatório de fechamento', 'relatoriofechamento'),
  diario('Diário de classe', 'diarioclasse'),
  domiciliar('Atendimento domiciliar', 'atendimentodomiciliar');

  const RelatorioProfessor(this.nome, this.acao);
  final String nome, acao;
  String get url => '$_professor/professor/relatorio/$acao.action';
}

// Contato de "Relatar um problema". Vem do build, fora do código e do repositório:
// flutter build apk --dart-define-from-file=.env.json
const contatoWhatsapp = String.fromEnvironment('CONTATO_WHATSAPP');
const contatoEmail = String.fromEnvironment('CONTATO_EMAIL');

// Repositório público com os APKs ("dono/nome"). Também vem do build.
const repositorioAtualizacoes = String.fromEnvironment('ATUALIZACOES_REPO');

// Faltas: pode ter até 16 em cada disciplina; a 17ª reprova (decisão de Arthur).
const limiteFaltas = 16;

/// Hora do aviso diário do Classroom (com o que vence até o fim do dia seguinte).
const horaAvisoClassroom = 19;
