import 'academico.dart';

/// Uma linha de "Minhas turmas" do Portal do Professor.
class TurmaProfessor {
  const TurmaProfessor({
    required this.id,
    required this.disciplina,
    required this.nome,
    this.codigo,
    this.curso,
    this.periodo,
    this.situacaoFrequencia,
    this.situacaoNotas,
  });

  /// Número interno da turma no portal (vai nos endereços).
  final String id;
  final String disciplina, nome;
  final String? codigo, curso, periodo, situacaoFrequencia, situacaoNotas;

  bool get lancamentoNotasAberto => situacaoNotas?.toLowerCase().contains('aberto') ?? false;

  TurmaProfessor comNotas(String? situacao) => TurmaProfessor(
        id: id,
        disciplina: disciplina,
        nome: nome,
        codigo: codigo,
        curso: curso,
        periodo: periodo,
        situacaoFrequencia: situacaoFrequencia,
        situacaoNotas: situacao,
      );

  Map<String, Object?> paraMapa() => {
        'id': id,
        'disciplina': disciplina,
        'nome': nome,
        'codigo': codigo,
        'curso': curso,
        'periodo': periodo,
        'freq': situacaoFrequencia,
        'notas': situacaoNotas,
      };

  static TurmaProfessor deMapa(Map<String, dynamic> m) => TurmaProfessor(
        id: m['id'] as String,
        disciplina: m['disciplina'] as String,
        nome: m['nome'] as String,
        codigo: m['codigo'] as String?,
        curso: m['curso'] as String?,
        periodo: m['periodo'] as String?,
        situacaoFrequencia: m['freq'] as String?,
        situacaoNotas: m['notas'] as String?,
      );
}

class HorarioTurma {
  const HorarioTurma({
    required this.diaSemana,
    required this.inicioMin,
    required this.fimMin,
    this.tipo,
    this.valeDe,
    this.valeAte,
  });

  /// Segunda = 1, domingo = 7.
  final int diaSemana, inicioMin, fimMin;
  final String? tipo;
  final DateTime? valeDe, valeAte;

  Map<String, Object?> paraMapa() => {
        'dia': diaSemana,
        'ini': inicioMin,
        'fim': fimMin,
        'tipo': tipo,
        'de': valeDe?.toIso8601String(),
        'ate': valeAte?.toIso8601String(),
      };

  static HorarioTurma deMapa(Map<String, dynamic> m) => HorarioTurma(
        diaSemana: m['dia'] as int,
        inicioMin: m['ini'] as int,
        fimMin: m['fim'] as int,
        tipo: m['tipo'] as String?,
        valeDe: DateTime.tryParse(m['de'] as String? ?? ''),
        valeAte: DateTime.tryParse(m['ate'] as String? ?? ''),
      );
}

/// "Aval. 1 · 60.00% · Prova" dentro de "Nota 2 (50.00%)".
class AvaliacaoModelo {
  const AvaliacaoModelo(this.codigo, this.peso, this.nome);
  final String codigo, peso, nome;
  Map<String, String> paraMapa() => {'c': codigo, 'p': peso, 'n': nome};
  static AvaliacaoModelo deMapa(Map<String, dynamic> m) =>
      AvaliacaoModelo(m['c'] as String, m['p'] as String, m['n'] as String);
}

class GrupoNotas {
  const GrupoNotas(this.rotulo, this.peso, this.avaliacoes);
  final String rotulo, peso;
  final List<AvaliacaoModelo> avaliacoes;
  Map<String, Object> paraMapa() => {
        'r': rotulo,
        'p': peso,
        'a': [for (final a in avaliacoes) a.paraMapa()],
      };
  static GrupoNotas deMapa(Map<String, dynamic> m) => GrupoNotas(
        m['r'] as String,
        m['p'] as String,
        [for (final a in m['a'] as List) AvaliacaoModelo.deMapa(a as Map<String, dynamic>)],
      );
}

/// Página "Detalhes da Turma". Não traz nome de aluno, só totais.
class DetalheTurma {
  const DetalheTurma({
    this.curso,
    this.disciplina,
    this.tipo,
    this.periodo,
    this.cargaHorariaRealizada,
    this.vagas,
    this.matriculas,
    this.docentes = const [],
    this.horarios = const [],
    this.modeloNotas = const [],
  });

  final String? curso, disciplina, tipo, periodo;
  final int? cargaHorariaRealizada, vagas, matriculas;

  /// (nome, papel)
  final List<(String, String)> docentes;
  final List<HorarioTurma> horarios;
  final List<GrupoNotas> modeloNotas;

  Map<String, Object?> paraMapa() => {
        'curso': curso,
        'disciplina': disciplina,
        'tipo': tipo,
        'periodo': periodo,
        'ch': cargaHorariaRealizada,
        'vagas': vagas,
        'mat': matriculas,
        'doc': [for (final d in docentes) [d.$1, d.$2]],
        'hor': [for (final h in horarios) h.paraMapa()],
        'notas': [for (final g in modeloNotas) g.paraMapa()],
      };

  static DetalheTurma deMapa(Map<String, dynamic> m) => DetalheTurma(
        curso: m['curso'] as String?,
        disciplina: m['disciplina'] as String?,
        tipo: m['tipo'] as String?,
        periodo: m['periodo'] as String?,
        cargaHorariaRealizada: m['ch'] as int?,
        vagas: m['vagas'] as int?,
        matriculas: m['mat'] as int?,
        docentes: [for (final d in m['doc'] as List) (d[0] as String, d[1] as String)],
        horarios: [for (final h in m['hor'] as List) HorarioTurma.deMapa(h as Map<String, dynamic>)],
        modeloNotas: [for (final g in m['notas'] as List) GrupoNotas.deMapa(g as Map<String, dynamic>)],
      );
}

/// Um mês da Agenda da Turma: o portal carrega cada um à parte.
class MesAgenda {
  const MesAgenda({required this.indice, required this.ano, required this.mes, required this.anoMes});
  final int indice, ano, mes;

  /// "2026_11", como o portal espera.
  final String anoMes;
}

/// Uma aula da Agenda, com a situação da chamada.
class AulaAgenda {
  const AulaAgenda({
    required this.data,
    required this.inicioMin,
    required this.fimMin,
    required this.chamadaLancada,
    this.periodos,
    this.conteudo,
    this.idAgenda,
  });

  final DateTime data;
  final int inicioMin, fimMin;
  final bool chamadaLancada;
  final int? periodos;
  final String? conteudo, idAgenda;

  Map<String, Object?> paraMapa() => {
        'data': data.toIso8601String(),
        'ini': inicioMin,
        'fim': fimMin,
        'ok': chamadaLancada,
        'per': periodos,
        'cont': conteudo,
        'ag': idAgenda,
      };

  static AulaAgenda deMapa(Map<String, dynamic> m) => AulaAgenda(
        data: DateTime.parse(m['data'] as String),
        inicioMin: m['ini'] as int,
        fimMin: m['fim'] as int,
        chamadaLancada: m['ok'] as bool,
        periodos: m['per'] as int?,
        conteudo: m['cont'] as String?,
        idAgenda: m['ag'] as String?,
      );
}

/// Tudo que o app sabe de uma turma.
class TurmaCompleta {
  const TurmaCompleta(this.turma, {this.detalhe, this.aulasDoMes});
  final TurmaProfessor turma;
  final DetalheTurma? detalhe;
  final List<AulaAgenda>? aulasDoMes;

  /// Aulas que já aconteceram e ainda estão sem chamada.
  List<AulaAgenda> semChamada(DateTime agora) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return [
      for (final a in aulasDoMes ?? const <AulaAgenda>[])
        if (!a.chamadaLancada && !a.data.isAfter(hoje)) a,
    ];
  }

  Map<String, Object?> paraMapa() => {
        't': turma.paraMapa(),
        'd': detalhe?.paraMapa(),
        'a': aulasDoMes == null ? null : [for (final a in aulasDoMes!) a.paraMapa()],
      };

  static TurmaCompleta deMapa(Map<String, dynamic> m) => TurmaCompleta(
        TurmaProfessor.deMapa(m['t'] as Map<String, dynamic>),
        detalhe: m['d'] == null ? null : DetalheTurma.deMapa(m['d'] as Map<String, dynamic>),
        aulasDoMes: m['a'] == null
            ? null
            : [for (final a in m['a'] as List) AulaAgenda.deMapa(a as Map<String, dynamic>)],
      );
}

/// Os horários de todas as turmas, no formato que Horários e "Próxima aula" já usam.
List<Aula> aulasDoProfessor(List<TurmaCompleta> turmas) => [
      for (final t in turmas)
        for (final h in t.detalhe?.horarios ?? const <HorarioTurma>[])
          Aula(
            disciplina: '${t.turma.disciplina} · ${t.turma.nome}',
            diaSemana: h.diaSemana,
            inicioMin: h.inicioMin,
            fimMin: h.fimMin,
            valeDe: h.valeDe,
            valeAte: h.valeAte,
          ),
    ];
