import '../config.dart';

/// A refeição em andamento ou a próxima. Depois do jantar, volta para o café.
Refeicao proximaRefeicao(DateTime agora) {
  final minutos = agora.hour * 60 + agora.minute;
  for (final r in Refeicao.values) {
    if (minutos < r.horario.fimMin) return r;
  }
  return Refeicao.cafe;
}

/// Separa o texto único do eTICKET em itens. "Não informado" vira lista vazia.
List<String> itensDoCardapio(String texto) {
  final limpo = texto.trim();
  if (limpo.isEmpty || limpo.toLowerCase() == 'não informado' || limpo.toLowerCase() == 'indisponível') {
    return const [];
  }
  return limpo
      .replaceFirst(RegExp(r'\.$'), '')
      .split(',')
      .map((i) => i.trim())
      .where((i) => i.isNotEmpty)
      .toList();
}
