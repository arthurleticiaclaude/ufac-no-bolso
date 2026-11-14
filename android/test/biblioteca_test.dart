import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/extractors/biblioteca.dart';
import 'package:ufac_no_bolso/session/regras_sessao.dart';

String fixture(String nome) => File('fixtures/$nome').readAsStringSync();

void main() {
  test('resultado da pesquisa no acervo', () {
    final r = lerResultadoAcervo(fixture('biblioteca_resultado.html'))!;
    expect(r, hasLength(2));
    expect(r[0].idRegistro, '1001');
    expect(r[0].titulo, 'Curso de direito civil de exemplo');
    expect(r[0].subtitulo, 'parte geral');
    expect(r[0].tituloCompleto, 'Curso de direito civil de exemplo: parte geral');
    expect(r[0].autor, 'SOUZA, Maria de Teste.');
    expect(r[0].ano, '2019');
    expect(r[0].biblioteca, 'Biblioteca Central');
    expect(r[1].autor, isNull);
    expect(r[1].ano, isNull);
  });

  test('pesquisa sem resultado é lista vazia; outra página é null', () {
    expect(lerResultadoAcervo(fixture('biblioteca_resultado_vazio.html')), isEmpty);
    expect(lerResultadoAcervo('<html><body>Requisição Incompleta</body></html>'), isNull);
  });

  test('exemplares de um título', () {
    final e = lerExemplares(fixture('biblioteca_itens.html'))!;
    expect(e, hasLength(3));
    expect(e[0].localizacao, 'CLA 00001-1');
    expect(e[0].biblioteca, 'CENTRAL');
    expect(e[0].regulamento, 'Empréstimo Normal - 10 Dias');
    expect(e[0].disponivel, isTrue);
    expect(e[1].disponivel, isFalse);
    expect(e[2].colecao, 'REFERÊNCIA');
    expect(lerExemplares('<div>nada</div>'), isNull);
  });

  test('histórico de empréstimos (JSON dentro do <pre> da WebView)', () {
    final h = lerHistoricoBiblioteca(fixture('biblioteca_historico.html'))!;
    expect(h, hasLength(2));
    expect(h[0].titulo, 'Curso de direito civil de exemplo: parte geral / Souza, Maria de Teste.');
    expect(h[0].retirada, DateTime(2026, 10, 3, 14, 5));
    expect(h[0].devolucao, DateTime(2026, 10, 13, 9, 30));
    expect(h[1].titulo, 'Manual fictício de contratos');
    expect(h[1].devolucao, isNull);
    expect(lerHistoricoBiblioteca('{"rows":[]}'), isEmpty);
    expect(lerHistoricoBiblioteca('<html>erro</html>'), isNull);
  });

  test('páginas da Biblioteca contam como logadas; login do portal não', () {
    expect(
      classificar(Sistema.biblioteca, Uri.parse('https://portal.ufac.br/biblioteca/usuario/index.action')),
      EstadoPagina.logado,
    );
    expect(classificar(Sistema.biblioteca, Uri.parse('https://portal.ufac.br/aluno/login.action')), EstadoPagina.naLogin);
    expect(classificar(Sistema.biblioteca, Uri.parse('https://portal.ufac.br/biblioteca/500.action')), EstadoPagina.outra);
    expect(classificar(Sistema.biblioteca, Uri.parse('https://sistemas.ufac.br/eticket/')), EstadoPagina.outra);
  });
}
