import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/extractors/portal.dart';
import 'package:ufac_no_bolso/pdf/baixar_pdf.dart';

void main() {
  late HttpServer servidor;
  final cookiesRecebidos = <String?>[];

  setUp(() async {
    cookiesRecebidos.clear();
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    servidor.listen((p) async {
      cookiesRecebidos.add(p.headers.value(HttpHeaders.cookieHeader));
      switch (p.uri.path) {
        case '/pdf':
          p.response.add(utf8.encode('%PDF-1.4 falso'));
        case '/redireciona':
          p.response.statusCode = HttpStatus.movedTemporarily;
          p.response.headers.set(HttpHeaders.locationHeader, '/pdf');
        case '/login':
          p.response.statusCode = HttpStatus.movedTemporarily;
          p.response.headers.set(HttpHeaders.locationHeader, '/html');
        case '/laco':
          p.response.statusCode = HttpStatus.movedTemporarily;
          p.response.headers.set(HttpHeaders.locationHeader, '/laco');
        case '/erro':
          p.response.statusCode = HttpStatus.internalServerError;
        default:
          p.response.write('<html>login</html>');
      }
      await p.response.close();
    });
  });

  tearDown(() => servidor.close(force: true));

  Uri em(String caminho) => Uri.parse('http://127.0.0.1:${servidor.port}$caminho');

  test('baixa PDF enviando o cookie', () async {
    final b = await baixarPdf(em('/pdf'), 'SESSAO=1');
    expect(ehPdf(b!), isTrue);
    expect(cookiesRecebidos, ['SESSAO=1']);
  });
  test('segue redirecionamento', () async {
    expect(await baixarPdf(em('/redireciona'), 'SESSAO=1'), isNotNull);
  });
  test('sessao caida vira null, nunca um PDF invalido', () async {
    expect(await baixarPdf(em('/login'), 'SESSAO=1'), isNull);
  });
  test('erro do servidor vira null', () async {
    expect(await baixarPdf(em('/erro'), 'SESSAO=1'), isNull);
  });
  test('laco de redirecionamento nao trava', () async {
    expect(await baixarPdf(em('/laco'), 'SESSAO=1'), isNull);
  });
  test('link de Mais Relatorios vem da fixture', () {
    final e = lerEnderecoMaisRelatoriosDe(File('fixtures/portal_relatorios.html').readAsStringSync());
    expect(e, startsWith('https://portal.ufac.br/relatorios/relatorios.action?'));
    expect(lerEnderecoMaisRelatoriosDe('<html></html>'), isNull);
  });
}
