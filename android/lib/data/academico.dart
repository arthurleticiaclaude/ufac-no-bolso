/// Dados do Portal. A matrícula não entra aqui: ela é igual ao número do QR e fica no cofre.
class Identificacao {
  const Identificacao({required this.nome, required this.curso, required this.periodo, required this.semestre});

  final String nome, curso, periodo, semestre;

  String get primeiroNome => nome.split(' ').first;

  String get iniciais {
    final partes = nome.split(' ');
    return partes.length < 2 ? partes.first[0] : '${partes.first[0]}${partes.last[0]}';
  }

  Map<String, String> paraMapa() => {'nome': nome, 'curso': curso, 'periodo': periodo, 'semestre': semestre};

  static Identificacao deMapa(Map<String, dynamic> m) => Identificacao(
        nome: m['nome'] as String,
        curso: m['curso'] as String,
        periodo: m['periodo'] as String,
        semestre: m['semestre'] as String,
      );
}

class Aula {
  const Aula({
    required this.disciplina,
    required this.diaSemana,
    required this.inicioMin,
    required this.fimMin,
    this.valeDe,
    this.valeAte,
  });

  final String disciplina;

  /// Como em DateTime.weekday: segunda = 1, domingo = 7.
  final int diaSemana;
  final int inicioMin, fimMin;
  final DateTime? valeDe, valeAte;

  bool valeNoDia(DateTime dia) {
    final d = DateTime(dia.year, dia.month, dia.day);
    return (valeDe == null || !d.isBefore(valeDe!)) && (valeAte == null || !d.isAfter(valeAte!));
  }

  Map<String, Object?> paraMapa() => {
        'disciplina': disciplina,
        'dia': diaSemana,
        'ini': inicioMin,
        'fim': fimMin,
        'de': valeDe?.toIso8601String(),
        'ate': valeAte?.toIso8601String(),
      };

  static Aula deMapa(Map<String, dynamic> m) => Aula(
        disciplina: m['disciplina'] as String,
        diaSemana: m['dia'] as int,
        inicioMin: m['ini'] as int,
        fimMin: m['fim'] as int,
        valeDe: DateTime.tryParse(m['de'] as String? ?? ''),
        valeAte: DateTime.tryParse(m['ate'] as String? ?? ''),
      );
}

/// Uma célula do quadro: "Aval. 1" com peso "100.00%" e valor "10,00".
class ItemNota {
  const ItemNota(this.rotulo, this.peso, this.valor);
  final String rotulo, peso, valor;

  Map<String, String> paraMapa() => {'rotulo': rotulo, 'peso': peso, 'valor': valor};

  static ItemNota deMapa(Map<String, dynamic> m) =>
      ItemNota(m['rotulo'] as String, m['peso'] as String, m['valor'] as String);
}

/// Uma coluna "Nota 1 (50.00%)", com as avaliações e o total.
class NotaAvaliacao {
  const NotaAvaliacao(this.rotulo, this.peso, this.itens);
  final String rotulo, peso;
  final List<ItemNota> itens;

  String get total => itens.isEmpty ? '' : itens.last.valor;

  Map<String, Object> paraMapa() => {'rotulo': rotulo, 'peso': peso, 'itens': [for (final i in itens) i.paraMapa()]};

  static NotaAvaliacao deMapa(Map<String, dynamic> m) => NotaAvaliacao(
        m['rotulo'] as String,
        m['peso'] as String,
        [for (final i in m['itens'] as List) ItemNota.deMapa(i as Map<String, dynamic>)],
      );
}

class NotasDisciplina {
  const NotasDisciplina({
    required this.disciplina,
    required this.situacao,
    this.notas = const [],
    this.resumo = const [],
    this.media = '',
    this.faltas = '',
    this.cargaHoraria,
  });

  final String disciplina, situacao, media, faltas;

  /// Da página da turma. Null quando não foi possível ler.
  final int? cargaHoraria;

  NotasDisciplina comCargaHoraria(int? carga) => NotasDisciplina(
        disciplina: disciplina,
        situacao: situacao,
        notas: notas,
        resumo: resumo,
        media: media,
        faltas: faltas,
        cargaHoraria: carga,
      );
  final List<NotaAvaliacao> notas;

  /// A última coluna do quadro: Média, Exame, Média Final.
  final List<ItemNota> resumo;

  /// O portal chama de "Matrícula" a disciplina em andamento.
  String get situacaoApresentavel => situacao == 'Matrícula' ? 'Cursando' : situacao;

  Map<String, Object> paraMapa() => {
        'disciplina': disciplina,
        'situacao': situacao,
        'media': media,
        'faltas': faltas,
        'carga': ?cargaHoraria,
        'notas': [for (final n in notas) n.paraMapa()],
        'resumo': [for (final r in resumo) r.paraMapa()],
      };

  static NotasDisciplina deMapa(Map<String, dynamic> m) => NotasDisciplina(
        disciplina: m['disciplina'] as String,
        situacao: m['situacao'] as String,
        media: m['media'] as String,
        faltas: m['faltas'] as String,
        cargaHoraria: m['carga'] as int?,
        notas: [for (final n in m['notas'] as List) NotaAvaliacao.deMapa(n as Map<String, dynamic>)],
        resumo: [for (final r in m['resumo'] as List) ItemNota.deMapa(r as Map<String, dynamic>)],
      );
}

class ProximaAula {
  const ProximaAula(this.aula, this.rotulo);
  final Aula aula;
  final String rotulo;
}

const _diasCurtos = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

String _hora(int minutos) {
  final h = minutos ~/ 60, m = minutos % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// A aula em andamento ou a próxima nos próximos 7 dias. Null se não houver nenhuma.
ProximaAula? proximaAula(List<Aula> aulas, DateTime agora) {
  final minutos = agora.hour * 60 + agora.minute;
  for (var d = 0; d < 7; d++) {
    final dia = agora.add(Duration(days: d));
    final doDia = aulas.where((a) => a.diaSemana == dia.weekday && a.valeNoDia(dia)).toList()
      ..sort((a, b) => a.inicioMin.compareTo(b.inicioMin));
    for (final a in doDia) {
      if (d == 0 && a.fimMin <= minutos) continue;
      if (d == 0 && a.inicioMin <= minutos) return ProximaAula(a, 'em andamento');
      if (d == 0) {
        final falta = a.inicioMin - minutos;
        return ProximaAula(a, falta < 60 ? 'começa em $falta min' : 'hoje às ${_hora(a.inicioMin)}');
      }
      if (d == 1) return ProximaAula(a, 'amanhã às ${_hora(a.inicioMin)}');
      return ProximaAula(a, '${_diasCurtos[dia.weekday - 1]} às ${_hora(a.inicioMin)}');
    }
  }
  return null;
}

/// "2° Semestre / 2026" vira "2º / 2026".
String semestreCurto(String semestre) {
  final m = RegExp(r'(\d+)\D+(\d{4})').firstMatch(semestre);
  return m == null ? semestre : '${m[1]}º / ${m[2]}';
}

enum NivelFaltas { tranquilo, atencao, limite }

class SituacaoFaltas {
  const SituacaoFaltas(this.faltas, this.permitidas, this.nivel, {required this.estimado});
  final int faltas, permitidas;
  final NivelFaltas nivel;

  /// True quando a carga horária não foi lida e o limite é o padrão.
  final bool estimado;
}

/// Reprova quem passa de [percentual] da carga horária. Sem a carga, usa [permitidasSemCarga].
/// O aviso começa em 75% das faltas permitidas. Null quando o portal ainda não informa faltas.
SituacaoFaltas? situacaoFaltas(
  String faltas, {
  required int? cargaHoraria,
  required double percentual,
  required int permitidasSemCarga,
}) {
  final n = int.tryParse(faltas.trim());
  if (n == null) return null;
  final permitidas = cargaHoraria == null ? permitidasSemCarga : (cargaHoraria * percentual).floor();
  final aviso = (permitidas * 0.75).ceil();
  final nivel = n > permitidas
      ? NivelFaltas.limite
      : n >= aviso
          ? NivelFaltas.atencao
          : NivelFaltas.tranquilo;
  return SituacaoFaltas(n, permitidas, nivel, estimado: cargaHoraria == null);
}

/// O quadro de horários e a lista de notas escrevem o nome com detalhes diferentes.
String nomeDeDisciplinaComparavel(String nome) => nome
    .replaceFirst(RegExp(r'\s*\([^()]*\)\s*$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

NotasDisciplina? notasDaDisciplina(List<NotasDisciplina>? notas, String disciplina) {
  final alvo = nomeDeDisciplinaComparavel(disciplina);
  return notas?.where((n) => nomeDeDisciplinaComparavel(n.disciplina) == alvo).firstOrNull;
}
