import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufac_no_bolso/main.dart';
import 'package:ufac_no_bolso/session/regras_sessao.dart';
import 'package:ufac_no_bolso/session/sessao.dart';

void main() {
  group('classificar', () {
    EstadoPagina portal(String u) => classificar(Sistema.portal, Uri.parse(u));
    EstadoPagina eticket(String u) => classificar(Sistema.eticket, Uri.parse(u));

    test('portal', () {
      expect(portal('https://portal.ufac.br/aluno/index.action'), EstadoPagina.logado);
      expect(portal('https://portal.ufac.br/aluno/login.action;jsessionid=ABC?error='), EstadoPagina.naLogin);
      expect(portal('https://portal.ufac.br/aluno/logout.action'), EstadoPagina.naLogin);
      expect(portal('https://portal.ufac.br/aluno/j_security_check'), EstadoPagina.outra);
      expect(portal('https://portal.ufac.br/usuario/publico/usuario/recuperacaosenha.action'), EstadoPagina.outra);
    });

    test('eticket', () {
      expect(eticket('https://sistemas.ufac.br/eticket/'), EstadoPagina.logado);
      expect(eticket('https://sistemas.ufac.br/eticket/login/?next=/eticket/'), EstadoPagina.naLogin);
      expect(eticket('https://sistemas.ufac.br/eticket/menuExterno/'), EstadoPagina.outra);
      expect(eticket('https://sistemas.ufac.br/home/servicos/idufac/'), EstadoPagina.outra);
    });
  });

  group('navegacao', () {
    test('http da Ufac vira https; de fora nao', () {
      expect(versaoHttps(Uri.parse('http://portal.ufac.br/aluno/index.action;jsessionid=A'))?.scheme, 'https');
      expect(versaoHttps(Uri.parse('http://exemplo.com/')), isNull);
      expect(versaoHttps(Uri.parse('https://portal.ufac.br/')), isNull);
    });
    test('so sites da Ufac', () {
      expect(ehSiteDaUfac(Uri.parse('https://sistemas.ufac.br/x')), isTrue);
      expect(ehSiteDaUfac(Uri.parse('https://ufac.br.exemplo.com/')), isFalse);
      expect(ehSiteDaUfac(Uri.parse('https://naoufac.br/')), isFalse);
    });
  });

  test('sem resposta nao conta como sessao expirada', () async {
    final s = Sessao.instancia;
    s.leitor = (sistema, _) async => PaginaLida(
        sistema == Sistema.eticket ? ResultadoVerificacao.expirada : ResultadoVerificacao.semResposta);
    await s.verificar();
    expect(s.expirados, {Sistema.eticket});
  });

  testWidgets('boas-vindas mostra o aviso de app independente', (tester) async {
    await tester.pumpWidget(const UfacNoBolso(loginConcluido: false));
    expect(find.text('Sou aluno'), findsOneWidget);
    expect(find.text('Sou professor'), findsOneWidget);
    expect(find.textContaining('Não é um aplicativo oficial da Ufac'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
