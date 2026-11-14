class RegistroRefeicao {
  const RegistroRefeicao({
    required this.data,
    required this.hora,
    required this.refeicao,
    required this.prato,
    required this.valor,
    required this.status,
  });

  final String data, hora, refeicao, prato, status;
  final double? valor;

  Map<String, Object?> paraMapa() =>
      {'data': data, 'hora': hora, 'refeicao': refeicao, 'prato': prato, 'valor': valor, 'status': status};

  static RegistroRefeicao deMapa(Map<String, dynamic> m) => RegistroRefeicao(
        data: m['data'] as String,
        hora: m['hora'] as String,
        refeicao: m['refeicao'] as String,
        prato: m['prato'] as String,
        valor: (m['valor'] as num?)?.toDouble(),
        status: m['status'] as String,
      );
}

class RegistroRecarga {
  const RegistroRecarga({
    required this.valor,
    required this.forma,
    required this.data,
    required this.hora,
    required this.situacao,
  });

  final double? valor;
  final String forma, data, hora, situacao;

  Map<String, Object?> paraMapa() =>
      {'valor': valor, 'forma': forma, 'data': data, 'hora': hora, 'situacao': situacao};

  static RegistroRecarga deMapa(Map<String, dynamic> m) => RegistroRecarga(
        valor: (m['valor'] as num?)?.toDouble(),
        forma: m['forma'] as String,
        data: m['data'] as String,
        hora: m['hora'] as String,
        situacao: m['situacao'] as String,
      );
}

class HistoricoRu {
  const HistoricoRu({required this.lidoEm, required this.refeicoes, required this.recargas});

  final DateTime lidoEm;
  final List<RegistroRefeicao> refeicoes;
  final List<RegistroRecarga> recargas;

  Map<String, Object> paraMapa() => {
        'lidoEm': lidoEm.toIso8601String(),
        'refeicoes': refeicoes.map((r) => r.paraMapa()).toList(),
        'recargas': recargas.map((r) => r.paraMapa()).toList(),
      };

  static HistoricoRu deMapa(Map<String, dynamic> m) => HistoricoRu(
        lidoEm: DateTime.parse(m['lidoEm'] as String),
        refeicoes: [for (final r in m['refeicoes'] as List) RegistroRefeicao.deMapa(r as Map<String, dynamic>)],
        recargas: [for (final r in m['recargas'] as List) RegistroRecarga.deMapa(r as Map<String, dynamic>)],
      );
}
