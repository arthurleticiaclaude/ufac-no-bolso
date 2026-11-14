// Prints das telas do professor com dados fictícios, para conferir o visual sem o celular.
// Gerar: flutter test test/visual_professor_test.dart --update-goldens --tags visual
@Tags(['visual'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/data/perfil.dart';
import 'package:ufac_no_bolso/data/professor.dart';
import 'package:ufac_no_bolso/data/repositorio_professor.dart';
import 'package:ufac_no_bolso/data/repositorio_ru.dart';
import 'package:ufac_no_bolso/screens/casca.dart';
import 'package:ufac_no_bolso/session/sessao.dart';
import 'package:ufac_no_bolso/theme/app_tema.dart';

Future<void> _carregarFontes() async {
  final jakarta = FontLoader('PlusJakartaSans')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'));
  await jakarta.load();
  final raiz = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter_sdk';
  final icones = File('$raiz/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icones.existsSync()) {
    final f = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icones.readAsBytesSync().buffer)));
    await f.load();
  }
}

/// Turmas de exemplo, relativas a hoje, para sempre ter aula passada sem chamada e aula futura.
List<TurmaCompleta> turmasDeExemplo() {
  final hoje = DateTime.now();
  final d = DateTime(hoje.year, hoje.month, hoje.day);
  AulaAgenda aula(int dias, bool ok, String id) => AulaAgenda(
        data: d.add(Duration(days: dias)),
        inicioMin: 8 * 60,
        fimMin: 9 * 60 + 40,
        chamadaLancada: ok,
        idAgenda: id,
        conteudo: ok ? 'Introdução ao tema da unidade' : null,
      );
  TurmaCompleta turma(String id, String disciplina, String nome, int dia, {bool notas = false, List<AulaAgenda> aulas = const []}) =>
      TurmaCompleta(
        TurmaProfessor(
          id: id,
          disciplina: disciplina,
          nome: nome,
          codigo: 'CCET$id',
          curso: 'Curso de Exemplo',
          periodo: '2° Semestre / 2026',
          situacaoFrequencia: 'Frequência Não Encerrada',
          situacaoNotas: notas ? 'Lançamento Aberto' : 'Lançamento Fechado',
        ),
        detalhe: DetalheTurma(
          tipo: 'Teórica',
          matriculas: 38,
          vagas: 40,
          cargaHorariaRealizada: 24,
          docentes: const [('Pessoa Teste de Exemplo', 'Titular')],
          horarios: [
            for (final dia2 in [dia, dia + 2])
              HorarioTurma(diaSemana: dia2.clamp(1, 7), inicioMin: 8 * 60, fimMin: 9 * 60 + 40, tipo: 'Teórica'),
          ],
          modeloNotas: const [
            GrupoNotas('N1', '50', [AvaliacaoModelo('P1', '100', 'Prova 1')]),
            GrupoNotas('N2', '50', [AvaliacaoModelo('P2', '100', 'Prova 2')]),
          ],
        ),
        aulasDoMes: aulas,
      );
  return [
    turma('101', 'Cálculo Diferencial e Integral I', 'Turma A', 1, notas: true, aulas: [
      aula(-9, true, 'a1'),
      aula(-7, true, 'a2'),
      aula(-2, false, 'a3'),
      aula(5, false, 'a4'),
    ]),
    turma('102', 'Álgebra Linear', 'Turma B', 2, aulas: [aula(-6, true, 'b1'), aula(-1, false, 'b2'), aula(6, false, 'b3')]),
    turma('103', 'Geometria Analítica', 'Turma C', 3, aulas: [aula(-5, true, 'c1'), aula(2, false, 'c2')]),
  ];
}

void main() {
  setUpAll(() async {
    await _carregarFontes();
    Sessao.instancia.leitor = (_, _) async => const PaginaLida(ResultadoVerificacao.semResposta);
    Perfil.instancia.atual = PerfilUsuario.professor;
    final prof = RepositorioProfessor.instancia;
    prof.nome = 'Pessoa Teste de Exemplo';
    prof.turmas = turmasDeExemplo();
    prof.lidoEm = DateTime.now();
    RepositorioRu.instancia.saldo = 12.5;
  });

  Future<void> preparar(WidgetTester t, ThemeData tema) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: tema, home: const Casca()));
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> foto(WidgetTester t, String nome) async {
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/professor/$nome.png'));
  }

  final temas = {'claro': AppTema.professorClaro, 'escuro': AppTema.professorEscuro};
  for (final e in temas.entries) {
    testWidgets('professor inicio ${e.key}', (t) async {
      await preparar(t, e.value);
      await foto(t, 'inicio_${e.key}');
    });
    testWidgets('professor turmas ${e.key}', (t) async {
      await preparar(t, e.value);
      await t.tap(find.text('Turmas').last);
      await t.pump(const Duration(milliseconds: 400));
      await foto(t, 'turmas_${e.key}');
    });
    testWidgets('professor turma ${e.key}', (t) async {
      await preparar(t, e.value);
      await t.tap(find.text('Turmas').last);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Álgebra Linear').last);
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      await foto(t, 'turma_${e.key}');
    });
    testWidgets('professor horarios ${e.key}', (t) async {
      await preparar(t, e.value);
      await t.tap(find.text('Horários').last);
      await t.pump(const Duration(milliseconds: 400));
      await foto(t, 'horarios_${e.key}');
    });
  }
}
