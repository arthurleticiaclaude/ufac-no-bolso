import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/data/feriados.dart';
import 'package:ufac_no_bolso/screens/relatar.dart';

void main() {
  group('pascoa e datas moveis', () {
    test('2026 bate com o calendario oficial', () {
      expect(pascoa(2026), DateTime(2026, 4, 5));
      final datas = feriadosDoAno(2026).map((f) => f.data).toSet();
      expect(datas, containsAll([DateTime(2026, 2, 16), DateTime(2026, 2, 17), DateTime(2026, 4, 3), DateTime(2026, 6, 4)]));
    });
    test('outros anos conhecidos', () {
      expect(pascoa(2025), DateTime(2025, 4, 20));
      expect(pascoa(2027), DateTime(2027, 3, 28));
      expect(pascoa(2028), DateTime(2028, 4, 16));
    });
  });

  group('listas de 2026 e de outros anos', () {
    test('2026 tem os feriados do Acre e de Rio Branco', () {
      final datas = feriadosDoAno(2026).map((f) => f.data).toSet();
      expect(datas, containsAll([DateTime(2026, 6, 15), DateTime(2026, 11, 17), DateTime(2026, 12, 28)]));
    });
    test('ano sem revisao nao inventa feriado local', () {
      final datas = feriadosDoAno(2027).map((f) => f.data).toSet();
      expect(datas, contains(DateTime(2027, 11, 20)));
      expect(datas, isNot(contains(DateTime(2027, 12, 28))));
    });
  });

  group('avisoFeriado', () {
    test('na vespera', () {
      final a = avisoFeriado(DateTime(2026, 11, 19, 10))!;
      expect(a.titulo, 'Amanhã é feriado · Dia da Consciência Negra');
      expect(a.texto, 'Sem aulas. Confira o funcionamento do RU.');
    });
    test('no proprio dia', () {
      expect(avisoFeriado(DateTime(2026, 12, 25, 23, 59))!.titulo, 'Hoje é feriado · Natal');
    });
    test('hoje tem prioridade sobre amanha', () {
      expect(avisoFeriado(DateTime(2026, 2, 16))!.titulo, 'Hoje é ponto facultativo · Carnaval');
    });
    test('ponto facultativo nao afirma que nao ha aula', () {
      final a = avisoFeriado(DateTime(2026, 6, 3))!;
      expect(a.titulo, 'Amanhã é ponto facultativo · Corpus Christi');
      expect(a.texto, isNot(contains('Sem aulas')));
    });
    test('virada de ano', () {
      expect(avisoFeriado(DateTime(2026, 12, 31))!.titulo, 'Amanhã é feriado · Confraternização Universal');
    });
    test('dia comum', () {
      expect(avisoFeriado(DateTime(2026, 11, 4)), isNull);
    });
    test('nunca afirma que o RU esta fechado', () {
      for (final d in [DateTime(2026, 12, 25), DateTime(2026, 2, 17)]) {
        expect(avisoFeriado(d)!.texto.toLowerCase(), isNot(contains('fechado')));
      }
    });
  });

  test('relato so leva versao, aparelho e tela', () {
    final r = montarRelato(versao: '0.1.0', modelo: 'motorola moto g35', android: '15', tela: 'Notas');
    expect(r, contains('O que aconteceu?'));
    expect(r, contains('Versão do app: 0.1.0'));
    expect(r, contains('Tela: Notas'));
    expect(r.toLowerCase(), isNot(anyOf(contains('cpf'), contains('matrícula'), contains('qr'))));
  });
}
