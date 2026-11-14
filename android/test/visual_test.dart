// Prints das telas nos dois perfis, para conferir as cores sem mexer no celular.
// Gerar: flutter test test/visual_test.dart --update-goldens --tags visual
@Tags(['visual'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/data/academico.dart';
import 'package:ufac_no_bolso/data/repositorio_portal.dart';
import 'package:ufac_no_bolso/data/repositorio_ru.dart';
import 'package:ufac_no_bolso/screens/boas_vindas.dart';
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

void main() {
  setUpAll(() async {
    await _carregarFontes();
    Sessao.instancia.leitor = (_, _) async => const PaginaLida(ResultadoVerificacao.semResposta);
    final portal = RepositorioPortal.instancia;
    portal.identificacao = const Identificacao(
      nome: 'Pessoa Teste de Exemplo',
      curso: 'Curso de Exemplo',
      periodo: '3',
      semestre: '2° Semestre / 2026',
    );
    portal.matricula = '12345678901';
    portal.aulas = const [];
    RepositorioRu.instancia.saldo = 12.5;
  });

  Future<void> foto(WidgetTester t, Widget tela, ThemeData tema, String nome) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: tema, home: tela));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$nome.png'));
  }

  final temas = {
    'aluno_claro': AppTema.claro,
    'aluno_escuro': AppTema.escuro,
    'professor_claro': AppTema.professorClaro,
    'professor_escuro': AppTema.professorEscuro,
  };
  for (final t in temas.entries) {
    testWidgets('inicio ${t.key}', (tester) => foto(tester, const Casca(), t.value, 'inicio_${t.key}'));
  }
  testWidgets('boas-vindas', (tester) => foto(tester, const TelaBoasVindas(), AppTema.claro, 'boas_vindas'));
}
