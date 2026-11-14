/// Um título do acervo, como aparece em "Pesquisar Acervo". Dados públicos da Biblioteca.
class TituloAcervo {
  const TituloAcervo({
    required this.idRegistro,
    required this.titulo,
    this.subtitulo,
    this.autor,
    this.ano,
    this.biblioteca,
  });

  /// Número do registro no acervo (vai no endereço dos exemplares).
  final String idRegistro;
  final String titulo;
  final String? subtitulo, autor, ano, biblioteca;

  String get tituloCompleto => subtitulo == null ? titulo : '$titulo: $subtitulo';
}

/// Um exemplar físico de um título.
class Exemplar {
  const Exemplar({
    required this.localizacao,
    required this.biblioteca,
    required this.situacao,
    this.colecao,
    this.tipo,
    this.regulamento,
  });

  /// Número de chamada na estante (ex.: "CLA 06002-1").
  final String localizacao;
  final String biblioteca, situacao;
  final String? colecao, tipo, regulamento;

  bool get disponivel => situacao.toLowerCase().startsWith('dispon');
}

/// Um empréstimo do histórico da pessoa. Fica só no celular.
class EmprestimoHistorico {
  const EmprestimoHistorico({required this.titulo, required this.retirada, this.devolucao});

  final String titulo;
  final DateTime retirada;

  /// Null enquanto o livro não foi devolvido.
  final DateTime? devolucao;

  Map<String, Object?> paraMapa() => {
        't': titulo,
        'r': retirada.toIso8601String(),
        'd': devolucao?.toIso8601String(),
      };

  static EmprestimoHistorico deMapa(Map<String, dynamic> m) => EmprestimoHistorico(
        titulo: m['t'] as String,
        retirada: DateTime.parse(m['r'] as String),
        devolucao: m['d'] == null ? null : DateTime.parse(m['d'] as String),
      );
}
