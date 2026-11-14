import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/config.dart';
import 'package:ufac_no_bolso/data/perfil.dart';
import 'package:ufac_no_bolso/data/professor.dart';
import 'package:ufac_no_bolso/data/refeicoes.dart';
import 'package:ufac_no_bolso/data/repositorio_professor.dart';
import 'package:ufac_no_bolso/extractors/eticket_cardapio.dart';
import 'package:ufac_no_bolso/extractors/professor.dart';
import 'package:ufac_no_bolso/main.dart';
import 'package:ufac_no_bolso/session/sessao.dart';
import 'package:ufac_no_bolso/ui/formatos.dart';

void main() {
  group('proximaRefeicao', () {
    DateTime as(int h, int m) => DateTime(2026, 11, 4, h, m);

    test('segue os horarios do RU', () {
      expect(proximaRefeicao(as(5, 0)), Refeicao.cafe);
      expect(proximaRefeicao(as(7, 59)), Refeicao.cafe);
      expect(proximaRefeicao(as(8, 0)), Refeicao.almoco);
      expect(proximaRefeicao(as(13, 59)), Refeicao.almoco);
      expect(proximaRefeicao(as(14, 0)), Refeicao.jantar);
      expect(proximaRefeicao(as(19, 29)), Refeicao.jantar);
      expect(proximaRefeicao(as(19, 30)), Refeicao.cafe);
    });
  });

  group('itensDoCardapio', () {
    test('separa pelas virgulas e tira o ponto final', () {
      expect(itensDoCardapio('Café preto, Leite Integral, Pão com ovos mexidos, Melão.'),
          ['Café preto', 'Leite Integral', 'Pão com ovos mexidos', 'Melão']);
    });
    test('sem cardapio vira lista vazia', () {
      expect(itensDoCardapio('Não informado'), isEmpty);
      expect(itensDoCardapio('Indisponível'), isEmpty);
      expect(itensDoCardapio('  '), isEmpty);
    });
    test('formato de 12/11/2026: um item por linha, com rótulos e saudação (issue #1)', () {
      const texto = '-Bife de panela acebolado \n-Arroz a grega \n-Feijão carioca \nSALADA: Alface com repolho \n'
          'SOBREMESA: Gelado de coco com maçã caramelizada \n\nBom almoço <3';
      expect(itensDoCardapio(texto), [
        'Bife de panela acebolado',
        'Arroz a grega',
        'Feijão carioca',
        'Salada: Alface com repolho',
        'Sobremesa: Gelado de coco com maçã caramelizada',
      ]);
    });
  });

  test('cardápio guarda as quebras de linha (<br>) e aceita bloco aninhado', () {
    final t = lerEticketCardapio(
      '<div><div class="x"><h2 class="meal-title">Almoço</h2></div>'
      '<div><p>R\$ 1.00</p><div class="cardapio">-Arroz<br>-Feijão<br>SALADA: Alface</div></div>'
      '<h2 class="meal-title">Café da Manhã</h2><div class="cardapio">Não informado</div></div>',
    )!;
    expect(t[Refeicao.almoco], '-Arroz\n-Feijão\nSALADA: Alface');
    expect(itensDoCardapio(t[Refeicao.almoco]!), ['Arroz', 'Feijão', 'Salada: Alface']);
    expect(t[Refeicao.cafe], 'Não informado');
  });

  group('formatos', () {
    test('moeda', () {
      expect(formatarMoeda(12.5), 'R\$ 12,50');
      expect(formatarMoeda(1234.5), 'R\$ 1.234,50');
      expect(formatarMoeda(0), 'R\$ 0,00');
    });
    test('data e hora', () {
      expect(formatarData(DateTime(2026, 11, 4)), 'Quarta, 4 de novembro');
      expect(formatarHora(10, 20), '10h20');
      expect(formatarHora(19, 0), '19h');
      expect(formatarHoraMin(390), '6h30');
    });
  });

  testWidgets('as 5 abas abrem sem erro de layout', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    Sessao.instancia.leitor = (_, _) async => const PaginaLida(ResultadoVerificacao.semResposta);
    await tester.pumpWidget(const UfacNoBolso(loginConcluido: true));
    for (final aba in ['Horários', 'Notas', 'Biblioteca', 'RU', 'Início']) {
      await tester.tap(find.widgetWithText(NavigationDestination, aba));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('as 5 abas do professor abrem com dados das fixtures', (tester) async {
    Sessao.instancia.leitor = (_, _) async => const PaginaLida(ResultadoVerificacao.semResposta);
    String fx(String n) => File('fixtures/$n').readAsStringSync();
    final prof = RepositorioProfessor.instancia;
    prof.nome = lerNomeProfessor(fx('professor_turmas_frequencia.html'));
    final hoje = DateTime.now();
    prof.turmas = [
      for (final t in lerTurmasProfessor(fx('professor_turmas_frequencia.html'))!)
        TurmaCompleta(
          t.comNotas('Lançamento Aberto'),
          detalhe: lerDetalheTurma(fx('professor_turma.html')),
          aulasDoMes: lerAulasDoMes(fx('professor_aulas_mes_ajax.html'), ano: hoje.year, mes: hoje.month),
        ),
    ];
    Perfil.instancia.atual = PerfilUsuario.professor;
    addTearDown(() {
      Perfil.instancia.atual = PerfilUsuario.aluno;
      prof.limpar();
    });
    await tester.pumpWidget(const UfacNoBolso(loginConcluido: true));
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(find.text('Para fazer'), findsOneWidget);
    for (final aba in ['Horários', 'Turmas', 'Relatórios', 'RU', 'Início']) {
      await tester.tap(find.widgetWithText(NavigationDestination, aba));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Turmas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direito Civil II').first);
    await tester.pumpAndSettle();
    expect(find.text('Fazer chamada'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
