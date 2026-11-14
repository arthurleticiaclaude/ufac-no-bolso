// Lista local de feriados. Revisar todo ano, conferindo em fonte oficial (ver docs/decisoes.md).

enum TipoFeriado { feriado, pontoFacultativo }

class Feriado {
  const Feriado(this.data, this.nome, this.tipo);
  final DateTime data;
  final String nome;
  final TipoFeriado tipo;
}

class AvisoFeriado {
  const AvisoFeriado(this.titulo, this.texto);
  final String titulo, texto;
}

// Feriados do Acre e de Rio Branco mudam de dia por decreto a cada ano, então só entram
// depois de conferidos. 2026: Decreto estadual nº 11.809/2025 e calendário da Prefeitura.
final _locaisPorAno = <int, List<Feriado>>{
  2026: [
    Feriado(DateTime(2026, 1, 22), 'Dia do Católico', TipoFeriado.feriado), // 20/1 adiado pela Lei 2.126/2009
    Feriado(DateTime(2026, 1, 23), 'Dia do Evangélico', TipoFeriado.feriado),
    Feriado(DateTime(2026, 3, 8), 'Dia Internacional da Mulher', TipoFeriado.feriado),
    Feriado(DateTime(2026, 6, 15), 'Aniversário do Acre', TipoFeriado.feriado),
    Feriado(DateTime(2026, 9, 5), 'Dia da Amazônia', TipoFeriado.feriado),
    Feriado(DateTime(2026, 11, 17), 'Tratado de Petrópolis', TipoFeriado.feriado),
    Feriado(DateTime(2026, 12, 28), 'Aniversário de Rio Branco', TipoFeriado.feriado),
  ],
};

/// Domingo de Páscoa (calendário gregoriano, algoritmo de Meeus).
DateTime pascoa(int ano) {
  final a = ano % 19, b = ano ~/ 100, c = ano % 100;
  final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31;
  final dia = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime(ano, mes, dia);
}

List<Feriado> feriadosDoAno(int ano) {
  final p = pascoa(ano);
  // DateTime faz a conta de dias sem cair em horário de verão antigo.
  DateTime daPascoa(int dias) => DateTime(p.year, p.month, p.day + dias);
  Feriado f(int mes, int dia, String nome) => Feriado(DateTime(ano, mes, dia), nome, TipoFeriado.feriado);
  return [
    f(1, 1, 'Confraternização Universal'),
    Feriado(daPascoa(-48), 'Carnaval', TipoFeriado.pontoFacultativo),
    Feriado(daPascoa(-47), 'Carnaval', TipoFeriado.pontoFacultativo),
    Feriado(daPascoa(-2), 'Sexta-feira Santa', TipoFeriado.feriado),
    f(4, 21, 'Tiradentes'),
    f(5, 1, 'Dia do Trabalho'),
    Feriado(daPascoa(60), 'Corpus Christi', TipoFeriado.pontoFacultativo),
    f(9, 7, 'Independência do Brasil'),
    f(10, 12, 'Nossa Senhora Aparecida'),
    f(11, 2, 'Finados'),
    f(11, 15, 'Proclamação da República'),
    f(11, 20, 'Dia da Consciência Negra'),
    f(12, 25, 'Natal'),
    ...?_locaisPorAno[ano],
  ];
}

Feriado? _noDia(DateTime dia) {
  final d = DateTime(dia.year, dia.month, dia.day);
  return feriadosDoAno(dia.year).where((f) => f.data == d).firstOrNull;
}

/// Aparece na véspera e no próprio dia. Nunca afirma que o RU está fechado.
AvisoFeriado? avisoFeriado(DateTime agora) {
  final hoje = _noDia(agora);
  final amanha = hoje == null ? _noDia(DateTime(agora.year, agora.month, agora.day + 1)) : null;
  final feriado = hoje ?? amanha;
  if (feriado == null) return null;
  final quando = hoje != null ? 'Hoje' : 'Amanhã';
  if (feriado.tipo == TipoFeriado.pontoFacultativo) {
    return AvisoFeriado(
      '$quando é ponto facultativo · ${feriado.nome}',
      'Confira se há aula e o funcionamento do RU.',
    );
  }
  return AvisoFeriado('$quando é feriado · ${feriado.nome}', 'Sem aulas. Confira o funcionamento do RU.');
}
