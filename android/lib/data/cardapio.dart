import '../config.dart';
import 'refeicoes.dart';

/// Cardápio lido num dia. A página do eTICKET não tem data, então guardamos a da leitura.
class CardapioDoDia {
  const CardapioDoDia(this.lidoEm, this.textos);

  final DateTime lidoEm;
  final Map<Refeicao, String> textos;

  bool valeEm(DateTime agora) =>
      lidoEm.year == agora.year && lidoEm.month == agora.month && lidoEm.day == agora.day;

  List<String> itens(Refeicao r) => itensDoCardapio(textos[r] ?? '');

  Map<String, Object> paraMapa() => {
        'lidoEm': lidoEm.toIso8601String(),
        for (final e in textos.entries) e.key.name: e.value,
      };

  static CardapioDoDia? deMapa(Map<String, dynamic> m) {
    final data = DateTime.tryParse(m['lidoEm'] as String? ?? '');
    if (data == null) return null;
    return CardapioDoDia(data, {
      for (final r in Refeicao.values)
        if (m[r.name] is String) r: m[r.name] as String,
    });
  }
}

/// Vale ler de novo se não há cardápio de hoje ou se falta alguma refeição,
/// porque o eTICKET costuma publicar pouco antes do horário.
bool cardapioPendente(CardapioDoDia? c, DateTime agora) =>
    c == null || !c.valeEm(agora) || Refeicao.values.any((r) => c.itens(r).isEmpty);
